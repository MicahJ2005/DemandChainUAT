@IsTest
private class EstimatePdfControllerTest {
    @TestSetup
    static void setup() {
        Opportunity opp = new Opportunity(
            Name = 'Estimate PDF Test Opportunity',
            StageName = '1. Qualification',
            CloseDate = Date.today().addMonths(1)
        );
        insert opp;

        Estimate__c header = new Estimate__c(
            Opportunity__c = opp.Id,
            Project_Name__c = 'PDF Test Project',
            Planning_Weeks__c = 1,
            Discovery_Weeks__c = 1,
            PB_Sprints__c = 2,
            Sprint_Length_Weeks__c = 1,
            Deploy_Weeks__c = 1,
            Wrapup_Weeks__c = 1
        );
        insert header;

        insert new List<Estimate_Line_Item__c>{
            new Estimate_Line_Item__c(
                Estimate__c = header.Id,
                Name = 'Consultant A',
                Line_Type__c = 'Team Resource',
                Rate_Class__c = 'Consultant',
                Cost_Per_Hour__c = 75,
                Price_Per_Hour__c = 145,
                Planning_Hours__c = 10
            ),
            new Estimate_Line_Item__c(
                Estimate__c = header.Id,
                Name = 'Login Screen',
                Line_Type__c = 'Fixed Deliverable',
                Deliverable__c = 'Login Screen',
                Phase__c = 'Planning',
                Total_Hours__c = 20,
                Cost_Per_Hour__c = 75,
                Fixed_Price__c = 5000
            ),
            new Estimate_Line_Item__c(
                Estimate__c = header.Id,
                Name = 'Standard Support',
                Line_Type__c = 'MS Tier',
                Delivery_Tier__c = 'Standard Support',
                Rate_Class__c = 'Consultant',
                Hours_Per_Week__c = 10,
                Cost_Per_Hour__c = 75,
                Price_Per_Hour__c = 135
            ),
            new Estimate_Line_Item__c(
                Estimate__c = header.Id,
                Name = 'Ad-Hoc Block',
                Line_Type__c = 'T&M Line',
                Rate_Class__c = 'Consultant',
                SLA_Tier__c = 'Priority',
                Total_Hours__c = 8,
                Cost_Per_Hour__c = 75,
                Price_Per_Hour__c = 167
            )
        };
    }

    @IsTest
    static void testConstructorLoadsEstimateAndBucketsLinesByType() {
        Estimate__c header = [SELECT Id FROM Estimate__c LIMIT 1];
        Test.setCurrentPageReference(new PageReference('/apex/EstimatePdf'));
        ApexPages.currentPage().getParameters().put('id', header.Id);

        Test.startTest();
        EstimatePdfController controller = new EstimatePdfController();
        Test.stopTest();

        System.assertEquals('PDF Test Project', controller.estimate.Project_Name__c);
        System.assertEquals(1, controller.teamLines.size());
        System.assertEquals(1, controller.fixedLines.size());
        System.assertEquals(1, controller.msLines.size());
        System.assertEquals(1, controller.tmLines.size());
    }

    @IsTest
    static void testPhaseSegmentsWidthsSumToOneHundredPercent() {
        Estimate__c header = [SELECT Id FROM Estimate__c LIMIT 1];
        Test.setCurrentPageReference(new PageReference('/apex/EstimatePdf'));
        ApexPages.currentPage().getParameters().put('id', header.Id);

        Test.startTest();
        EstimatePdfController controller = new EstimatePdfController();
        Test.stopTest();

        Decimal totalWidth = 0;
        System.assertEquals(5, controller.phaseSegments.size());
        for (EstimatePdfController.PhaseSegment seg : controller.phaseSegments) {
            totalWidth += seg.widthPercent;
        }
        // each segment's width is independently rounded to 1 decimal place for display,
        // so the sum can drift slightly from 100 - assert it's within that rounding tolerance.
        System.assert(
            Math.abs(totalWidth - 100) < 0.5,
            'segment widths should sum to ~100%, got ' + totalWidth
        );
    }

    @IsTest
    static void testRollupNullsAreCoalescedToZeroNotBlank() {
        // Total_Price__c/Total_Cost__c/Total_Hours__c are roll-up SUM fields, which
        // Salesforce leaves null (not 0) when there are no child line items yet. A null
        // value passed into a Visualforce {0,number,currency} pattern renders blank
        // rather than "$0.00" - the controller must coalesce these before display.
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Estimate__c emptyHeader = new Estimate__c(Opportunity__c = opp.Id, Project_Name__c = 'No Lines Yet');
        insert emptyHeader;

        Test.setCurrentPageReference(new PageReference('/apex/EstimatePdf'));
        ApexPages.currentPage().getParameters().put('id', emptyHeader.Id);

        Test.startTest();
        EstimatePdfController controller = new EstimatePdfController();
        Test.stopTest();

        System.assertEquals(0, controller.totalPrice, 'null roll-up should coalesce to 0');
        System.assertEquals(0, controller.totalCost, 'null roll-up should coalesce to 0');
        System.assertEquals(0, controller.totalHours, 'null roll-up should coalesce to 0');
        System.assertEquals(0, controller.totalMargin, 'formula field should coalesce to 0');
        System.assertEquals(0, controller.estimate.Discovery_Fee__c, 'unset discovery fee should coalesce to 0');
    }

    @IsTest
    static void testHandlesMissingIdGracefully() {
        Test.setCurrentPageReference(new PageReference('/apex/EstimatePdf'));

        Test.startTest();
        EstimatePdfController controller = new EstimatePdfController();
        Test.stopTest();

        System.assertEquals(null, controller.estimate);
        System.assert(controller.teamLines.isEmpty());
    }
}
