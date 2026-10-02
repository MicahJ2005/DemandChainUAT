@IsTest
private class EstimateExportControllerTest {
    @TestSetup
    static void setup() {
        insert new Opportunity(
            Name = 'Estimate Export Test Opportunity',
            StageName = '1. Qualification',
            CloseDate = Date.today().addMonths(1)
        );
    }

    // renderPage() itself calls PageReference.getContentAsPDF()/.getContent(), which
    // Salesforce does not support in test context at all - see the class-level comment
    // on EstimateExportController. Everything else in the class is covered here using
    // a synthetic Blob instead of a real rendered page.

    @IsTest
    static void testBuildFileNameUsesPdfAndDocExtensions() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Estimate__c header = new Estimate__c(Opportunity__c = opp.Id, Project_Name__c = 'Export Test Project');
        insert header;

        System.assert(EstimateExportController.buildFileName(header.Id, false).endsWith('.pdf'));
        System.assert(EstimateExportController.buildFileName(header.Id, true).endsWith('.doc'));
    }

    @IsTest
    static void testSaveAsContentVersionAttachesFileToTheEstimate() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Estimate__c header = new Estimate__c(Opportunity__c = opp.Id, Project_Name__c = 'Export Test Project');
        insert header;

        Test.startTest();
        Id contentVersionId = EstimateExportController.saveAsContentVersion(
            header.Id,
            'Estimate_Test.pdf',
            Blob.valueOf('fake pdf bytes')
        );
        Test.stopTest();

        ContentVersion cv = [SELECT Title FROM ContentVersion WHERE Id = :contentVersionId];
        System.assertEquals('Estimate_Test.pdf', cv.Title);

        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :header.Id
        ];
        System.assertEquals(1, links.size());
    }

    // generatePdf()/generateWord() themselves can't reach a real Blob in test context -
    // renderPage() always throws there - but calling them still exercises the public
    // entry points and the try/catch error handling, converting the platform limitation
    // into coverage of the failure path instead of leaving it untested.

    @IsTest
    static void testGeneratePdfSurfacesFriendlyErrorInTestContext() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Estimate__c header = new Estimate__c(Opportunity__c = opp.Id, Project_Name__c = 'Render Test PDF');
        insert header;

        Test.startTest();
        try {
            EstimateExportController.generatePdf(header.Id);
            System.assert(false, 'expected an exception - PDF rendering is unsupported in test context');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Unable to generate export'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testGenerateWordSurfacesFriendlyErrorInTestContext() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Estimate__c header = new Estimate__c(Opportunity__c = opp.Id, Project_Name__c = 'Render Test Word');
        insert header;

        Test.startTest();
        try {
            EstimateExportController.generateWord(header.Id);
            System.assert(false, 'expected an exception - rendering is unsupported in test context');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Unable to generate export'));
        }
        Test.stopTest();
    }
}
