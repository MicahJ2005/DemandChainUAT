@IsTest
private class EstimateControllerTest {
    @TestSetup
    static void setup() {
        insert new Opportunity(
            Name = 'Estimate Test Opportunity',
            StageName = '1. Qualification',
            CloseDate = Date.today().addMonths(1)
        );
    }

    @IsTest
    static void testSavingADraftDoesNotTouchTheOpportunity() {
        // Only activateVersion() should push totals to the Opportunity - saving (or
        // re-saving) a Draft must never overwrite it with in-progress numbers.
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Estimate__c header = new Estimate__c(
            Opportunity__c = opp.Id,
            Project_Name__c = 'Draft Sync Test',
            Discovery_Fee__c = 1000,
            Discovery_Hours__c = 5,
            Discovery_Rate_Class__c = 'Consultant'
        );
        List<Estimate_Rate__c> rates = new List<Estimate_Rate__c>{
            new Estimate_Rate__c(Rate_Class__c = 'Consultant', Cost_Per_Hour__c = 75, Price_Per_Hour__c = 145)
        };
        List<Estimate_Line_Item__c> lines = new List<Estimate_Line_Item__c>{
            new Estimate_Line_Item__c(
                Name = 'Included Line',
                Line_Type__c = 'Team Resource',
                Cost_Per_Hour__c = 75,
                Price_Per_Hour__c = 145,
                Planning_Hours__c = 10,
                Include_In_Rollup__c = true
            )
        };

        Test.startTest();
        Id estimateId = EstimateController.saveEstimate(header, rates, lines, null, null);
        Test.stopTest();

        System.assertEquals('Draft', [SELECT Status__c FROM Estimate__c WHERE Id = :estimateId].Status__c);
        Opportunity untouchedOpp = [SELECT Amount, Margin__c, Total_Hours__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(null, untouchedOpp.Amount, 'saving a Draft must not set Amount');
        System.assertEquals(null, untouchedOpp.Margin__c, 'saving a Draft must not set Margin');
        System.assertEquals(null, untouchedOpp.Total_Hours__c, 'saving a Draft must not set Total Hours');
    }

    @IsTest
    static void testActivateVersionSyncsAmountMarginAndHoursToOpportunity() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Estimate__c header = new Estimate__c(
            Opportunity__c = opp.Id,
            Project_Name__c = 'Activate Sync Test',
            Discovery_Fee__c = 1000,
            Discovery_Hours__c = 5,
            Discovery_Rate_Class__c = 'Consultant'
        );
        List<Estimate_Rate__c> rates = new List<Estimate_Rate__c>{
            new Estimate_Rate__c(Rate_Class__c = 'Consultant', Cost_Per_Hour__c = 75, Price_Per_Hour__c = 145)
        };
        List<Estimate_Line_Item__c> lines = new List<Estimate_Line_Item__c>{
            new Estimate_Line_Item__c(
                Name = 'Included Line',
                Line_Type__c = 'Team Resource',
                Cost_Per_Hour__c = 75,
                Price_Per_Hour__c = 145,
                Planning_Hours__c = 10,
                Include_In_Rollup__c = true
            ),
            new Estimate_Line_Item__c(
                Name = 'Excluded Line',
                Line_Type__c = 'Team Resource',
                Cost_Per_Hour__c = 75,
                Price_Per_Hour__c = 145,
                Planning_Hours__c = 100,
                Include_In_Rollup__c = false
            )
        };
        Id estimateId = EstimateController.saveEstimate(header, rates, lines, null, null);

        // Sanity check the fixture: saving alone should NOT have touched the Opportunity yet.
        Opportunity beforeActivate = [SELECT Amount FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(null, beforeActivate.Amount, 'Amount should still be unset before activation');

        Test.startTest();
        EstimateController.activateVersion(estimateId);
        Test.stopTest();

        // included line: 10 hrs -> price 1450, cost 750. discovery: fee 1000, hours 5, cost 5*75=375.
        // excluded line (100 hrs) must NOT count. totalPrice = 1450+1000 = 2450, totalCost = 750+375 = 1125,
        // totalHours = 10+5 = 15, margin = (2450-1125)/2450*100 = 54.08.
        Opportunity updatedOpp = [SELECT Amount, Margin__c, Total_Hours__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(2450, updatedOpp.Amount, 'Amount should be included-line price + discovery fee');
        System.assertEquals(15, updatedOpp.Total_Hours__c, 'Hours should be included-line hours + discovery hours');
        System.assertEquals(54.08, updatedOpp.Margin__c, 'Margin should reflect included lines + discovery only');
    }

    @IsTest
    static void testSaveEstimateRecalculatesLinesAndDiscovery() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Estimate__c header = new Estimate__c(
            Opportunity__c = opp.Id,
            Project_Name__c = 'Test Project',
            Discovery_Fee__c = 5000,
            Discovery_Hours__c = 10,
            Discovery_Rate_Class__c = 'Consultant'
        );

        List<Estimate_Rate__c> rates = new List<Estimate_Rate__c>{
            new Estimate_Rate__c(Rate_Class__c = 'Consultant', Cost_Per_Hour__c = 75, Price_Per_Hour__c = 145, Sequence__c = 1)
        };

        List<Estimate_Line_Item__c> lines = new List<Estimate_Line_Item__c>{
            new Estimate_Line_Item__c(
                Name = 'Consultant A',
                Line_Type__c = 'Team Resource',
                Rate_Class__c = 'Consultant',
                Cost_Per_Hour__c = 75,
                Price_Per_Hour__c = 145,
                Planning_Hours__c = 10,
                PB_Hours__c = 40
            )
        };

        Test.startTest();
        Id estimateId = EstimateController.saveEstimate(header, rates, lines, null, null);
        Test.stopTest();

        Estimate__c saved = EstimateController.getEstimate(estimateId);
        System.assertEquals(1, saved.Estimate_Rates__r.size(), 'rate row should be saved');
        System.assertEquals(1, saved.Estimate_Line_Items__r.size(), 'line item should be saved');

        Estimate_Line_Item__c savedLine = saved.Estimate_Line_Items__r[0];
        System.assertEquals(50, savedLine.Total_Hours__c, 'hours should sum across phases');
        System.assertEquals(3750, savedLine.Line_Cost__c, 'cost = hours * cost/hr');
        System.assertEquals(7250, savedLine.Line_Price__c, 'price = hours * price/hr');
        System.assertEquals(750, saved.Discovery_Cost__c, 'discovery cost = hours * matching rate class cost/hr');
    }

    @IsTest
    static void testResavingExistingRatesAndLineItemsDoesNotThrow() {
        // Regression test: master-detail fields (Estimate_Rate__c.Estimate__c,
        // Estimate_Line_Item__c.Estimate__c) are only settable at insert. Re-saving an
        // estimate that already has persisted rate/line-item rows - without deleting or
        // replacing them - must not try to reassign those fields on the existing rows.
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Estimate__c header = new Estimate__c(Opportunity__c = opp.Id, Project_Name__c = 'Resave Test');
        List<Estimate_Rate__c> rates = new List<Estimate_Rate__c>{
            new Estimate_Rate__c(Rate_Class__c = 'Consultant', Cost_Per_Hour__c = 75, Price_Per_Hour__c = 145)
        };
        List<Estimate_Line_Item__c> lines = new List<Estimate_Line_Item__c>{
            new Estimate_Line_Item__c(
                Name = 'Line A',
                Line_Type__c = 'Team Resource',
                Rate_Class__c = 'Consultant',
                Cost_Per_Hour__c = 75,
                Price_Per_Hour__c = 145,
                Planning_Hours__c = 5
            )
        };
        Id estimateId = EstimateController.saveEstimate(header, rates, lines, null, null);

        Estimate__c reloaded = EstimateController.getEstimate(estimateId);
        Estimate_Rate__c existingRate = reloaded.Estimate_Rates__r[0];
        Estimate_Line_Item__c existingLine = reloaded.Estimate_Line_Items__r[0];
        existingRate.Price_Per_Hour__c = 150;
        existingLine.Planning_Hours__c = 8;

        Test.startTest();
        EstimateController.saveEstimate(
            reloaded,
            new List<Estimate_Rate__c>{ existingRate },
            new List<Estimate_Line_Item__c>{ existingLine },
            null,
            null
        );
        Test.stopTest();

        Estimate_Rate__c afterResave = [
            SELECT Price_Per_Hour__c
            FROM Estimate_Rate__c
            WHERE Id = :existingRate.Id
        ];
        Estimate_Line_Item__c afterResaveLine = [
            SELECT Planning_Hours__c
            FROM Estimate_Line_Item__c
            WHERE Id = :existingLine.Id
        ];
        System.assertEquals(150, afterResave.Price_Per_Hour__c, 'edited rate should persist');
        System.assertEquals(8, afterResaveLine.Planning_Hours__c, 'edited line item should persist');
    }

    @IsTest
    static void testFixedDeliverableUsesFixedPriceNotHoursTimesRate() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Estimate__c header = new Estimate__c(Opportunity__c = opp.Id, Project_Name__c = 'Fixed Bid Test');

        List<Estimate_Line_Item__c> lines = new List<Estimate_Line_Item__c>{
            new Estimate_Line_Item__c(
                Name = 'Login Screen',
                Line_Type__c = 'Fixed Deliverable',
                Rate_Class__c = 'Consultant',
                Cost_Per_Hour__c = 75,
                Price_Per_Hour__c = 145,
                Total_Hours__c = 20,
                Fixed_Price__c = 5000
            )
        };

        Test.startTest();
        Id estimateId = EstimateController.saveEstimate(
            header,
            new List<Estimate_Rate__c>(),
            lines,
            null,
            null
        );
        Test.stopTest();

        Estimate_Line_Item__c savedLine = [
            SELECT Line_Cost__c, Line_Price__c
            FROM Estimate_Line_Item__c
            WHERE Estimate__c = :estimateId
        ];
        System.assertEquals(1500, savedLine.Line_Cost__c, 'cost still derives from hours * cost/hr');
        System.assertEquals(5000, savedLine.Line_Price__c, 'price uses the fixed price, not hours * price/hr');
    }

    @IsTest
    static void testVersioningLifecycle() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Estimate__c header = new Estimate__c(Opportunity__c = opp.Id, Project_Name__c = 'Versioned');
        Id v1Id = EstimateController.saveEstimate(
            header,
            new List<Estimate_Rate__c>(),
            new List<Estimate_Line_Item__c>(),
            null,
            null
        );

        Test.startTest();
        EstimateController.activateVersion(v1Id);
        Id v2Id = EstimateController.createNewVersion(v1Id);
        EstimateController.activateVersion(v2Id);
        Test.stopTest();

        Map<Id, Estimate__c> versions = new Map<Id, Estimate__c>(
            [SELECT Id, Status__c, Version_Number__c FROM Estimate__c WHERE Opportunity__c = :opp.Id]
        );
        System.assertEquals('Superseded', versions.get(v1Id).Status__c, 'prior active version is superseded');
        System.assertEquals('Active', versions.get(v2Id).Status__c, 'new version becomes active');
        System.assertEquals(2, versions.get(v2Id).Version_Number__c, 'version number increments');
    }

    @IsTest
    static void testDeleteOnlyRemovesDraft() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Estimate__c header = new Estimate__c(Opportunity__c = opp.Id, Project_Name__c = 'To Delete');
        Id draftId = EstimateController.saveEstimate(
            header,
            new List<Estimate_Rate__c>(),
            new List<Estimate_Line_Item__c>(),
            null,
            null
        );

        Test.startTest();
        EstimateController.deleteEstimate(draftId);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Estimate__c WHERE Id = :draftId]);
    }

    @IsTest
    static void testGetEstimateVersionsAndDefaultRateCard() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Estimate__c header = new Estimate__c(Opportunity__c = opp.Id, Project_Name__c = 'List Test');
        EstimateController.saveEstimate(
            header,
            new List<Estimate_Rate__c>(),
            new List<Estimate_Line_Item__c>(),
            null,
            null
        );

        Test.startTest();
        List<Estimate__c> versions = EstimateController.getEstimateVersions(opp.Id);
        List<Default_Rate_Card__mdt> defaults = EstimateController.getDefaultRateCard();
        Test.stopTest();

        System.assert(!versions.isEmpty(), 'should return the saved version');
        System.assert(!defaults.isEmpty(), 'default rate card should be seeded');
    }

    @IsTest
    static void testSaveEstimateHandlesNullChildLists() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Estimate__c header = new Estimate__c(Opportunity__c = opp.Id, Project_Name__c = 'Null Lists');

        Test.startTest();
        Id estimateId = EstimateController.saveEstimate(header, null, null, null, null);
        Test.stopTest();

        System.assertNotEquals(null, estimateId);
    }

    @IsTest
    static void testSaveEstimateDeletesRemovedRatesAndLineItems() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Estimate__c header = new Estimate__c(Opportunity__c = opp.Id, Project_Name__c = 'Delete Children Test');
        List<Estimate_Rate__c> rates = new List<Estimate_Rate__c>{
            new Estimate_Rate__c(Rate_Class__c = 'Consultant', Cost_Per_Hour__c = 75, Price_Per_Hour__c = 145)
        };
        List<Estimate_Line_Item__c> lines = new List<Estimate_Line_Item__c>{
            new Estimate_Line_Item__c(
                Name = 'Line A',
                Line_Type__c = 'Team Resource',
                Planning_Hours__c = 5,
                Cost_Per_Hour__c = 75,
                Price_Per_Hour__c = 145
            )
        };
        Id estimateId = EstimateController.saveEstimate(header, rates, lines, null, null);
        Estimate__c saved = EstimateController.getEstimate(estimateId);
        Id rateId = saved.Estimate_Rates__r[0].Id;
        Id lineId = saved.Estimate_Line_Items__r[0].Id;

        Test.startTest();
        EstimateController.saveEstimate(
            new Estimate__c(Id = estimateId, Opportunity__c = opp.Id),
            new List<Estimate_Rate__c>(),
            new List<Estimate_Line_Item__c>(),
            new List<Id>{ rateId },
            new List<Id>{ lineId }
        );
        Test.stopTest();

        Estimate__c afterDelete = EstimateController.getEstimate(estimateId);
        System.assert(afterDelete.Estimate_Rates__r.isEmpty(), 'rate row should have been deleted');
        System.assert(afterDelete.Estimate_Line_Items__r.isEmpty(), 'line item should have been deleted');
    }

    @IsTest
    static void testRecalculateLineItemsForMsTierAndTmLine() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Estimate__c header = new Estimate__c(Opportunity__c = opp.Id, Project_Name__c = 'MS and TM Test');
        List<Estimate_Line_Item__c> lines = new List<Estimate_Line_Item__c>{
            new Estimate_Line_Item__c(
                Name = 'Standard Support',
                Line_Type__c = 'MS Tier',
                Rate_Class__c = 'Consultant',
                Hours_Per_Week__c = 10,
                Cost_Per_Hour__c = 75,
                Price_Per_Hour__c = 135
            ),
            new Estimate_Line_Item__c(
                Name = 'Ad-Hoc Block',
                Line_Type__c = 'T&M Line',
                Rate_Class__c = 'Consultant',
                Total_Hours__c = 8,
                Cost_Per_Hour__c = 75,
                Price_Per_Hour__c = 167
            )
        };

        Test.startTest();
        Id estimateId = EstimateController.saveEstimate(header, new List<Estimate_Rate__c>(), lines, null, null);
        Test.stopTest();

        Map<String, Estimate_Line_Item__c> savedByType = new Map<String, Estimate_Line_Item__c>();
        for (Estimate_Line_Item__c li : [
            SELECT Line_Type__c, Total_Hours__c
            FROM Estimate_Line_Item__c
            WHERE Estimate__c = :estimateId
        ]) {
            savedByType.put(li.Line_Type__c, li);
        }
        System.assertEquals(10, savedByType.get('MS Tier').Total_Hours__c);
        System.assertEquals(8, savedByType.get('T&M Line').Total_Hours__c);
    }

    @IsTest
    static void testCreateNewVersionClonesRatesAndLineItems() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Estimate__c header = new Estimate__c(Opportunity__c = opp.Id, Project_Name__c = 'Clone Source');
        List<Estimate_Rate__c> rates = new List<Estimate_Rate__c>{
            new Estimate_Rate__c(Rate_Class__c = 'Consultant', Cost_Per_Hour__c = 75, Price_Per_Hour__c = 145)
        };
        List<Estimate_Line_Item__c> lines = new List<Estimate_Line_Item__c>{
            new Estimate_Line_Item__c(
                Name = 'Line A',
                Line_Type__c = 'Team Resource',
                Planning_Hours__c = 5,
                Cost_Per_Hour__c = 75,
                Price_Per_Hour__c = 145
            )
        };
        Id v1Id = EstimateController.saveEstimate(header, rates, lines, null, null);

        Test.startTest();
        Id v2Id = EstimateController.createNewVersion(v1Id);
        Test.stopTest();

        Estimate__c v2 = EstimateController.getEstimate(v2Id);
        System.assertEquals(1, v2.Estimate_Rates__r.size(), 'rate row should have been cloned');
        System.assertEquals(1, v2.Estimate_Line_Items__r.size(), 'line item should have been cloned');
    }

    @IsTest
    static void testDiscoveryMarginIsZeroWhenFeeIsZero() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Estimate__c header = new Estimate__c(
            Opportunity__c = opp.Id,
            Project_Name__c = 'Zero Fee Test',
            Discovery_Fee__c = 0,
            Discovery_Hours__c = 10,
            Discovery_Rate_Class__c = 'Consultant'
        );
        List<Estimate_Rate__c> rates = new List<Estimate_Rate__c>{
            new Estimate_Rate__c(Rate_Class__c = 'Consultant', Cost_Per_Hour__c = 75, Price_Per_Hour__c = 145)
        };

        Test.startTest();
        Id estimateId = EstimateController.saveEstimate(
            header,
            rates,
            new List<Estimate_Line_Item__c>(),
            null,
            null
        );
        Test.stopTest();

        Estimate__c saved = [SELECT Discovery_Margin__c FROM Estimate__c WHERE Id = :estimateId];
        System.assertEquals(0, saved.Discovery_Margin__c);
    }
}
