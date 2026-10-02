@IsTest
private class FinancialHealthControllerTest {
    // Creating PSA test fixtures (Region/Permission Control/Project/Assignment, via
    // PsaTestHarness) triggers some of PSA's own managed-package automation that
    // performs an outbound HTTP callout - harmless in real use, but test methods
    // can't make synchronous callouts at all, so a generic always-200 mock is
    // registered before that fixture setup to absorb whichever call it is.
    private class NoOpCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Financial Health Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Financial Health Test Opportunity',
            AccountId = acc.Id,
            StageName = '1. Qualification',
            CloseDate = Date.today().addMonths(1)
        );
        insert opp;

        // Remaining_Budget__c is a calculated (formula/workflow) field on this managed
        // package object - not directly writeable, so these rows can't seed a specific
        // value for it. That's fine: these tests only assert on which projects are
        // returned (by name/stage/Opportunity link), not on the budget figure itself.
        insert new List<pse__Proj__c>{
            // (a) real client project, included stage - should be returned
            new pse__Proj__c(
                Name = 'Included Client Project',
                pse__Account__c = acc.Id,
                pse__Opportunity__c = opp.Id,
                pse__Stage__c = 'In Progress'
            ),
            // (b) real client project, excluded stage (Closed) - must NOT be returned
            new pse__Proj__c(
                Name = 'Closed Client Project',
                pse__Account__c = acc.Id,
                pse__Opportunity__c = opp.Id,
                pse__Stage__c = 'Closed'
            ),
            // (c) internal, non-client project (no Opportunity link) - must NOT be returned
            new pse__Proj__c(
                Name = 'Internal Bench Bucket',
                pse__Account__c = acc.Id,
                pse__Stage__c = 'In Progress'
            )
        };
    }

    @IsTest
    static void testGetCurrentProjectsDefaultsToActiveStagesWhenNoneRequested() {
        Test.startTest();
        List<pse__Proj__c> results = FinancialHealthController.getCurrentProjects(null);
        Test.stopTest();

        Set<String> names = new Set<String>();
        for (pse__Proj__c p : results) {
            names.add(p.Name);
        }
        System.assert(names.contains('Included Client Project'), 'in-scope client project should be returned');
        System.assert(!names.contains('Closed Client Project'), 'Closed-stage project must be excluded by default');
        System.assert(!names.contains('Internal Bench Bucket'), 'internal (no Opportunity) project must be excluded');
    }

    @IsTest
    static void testGetCurrentProjectsHonorsExplicitStageFilter() {
        Test.startTest();
        // Request only 'Closed' - a stage NOT in the default set - to prove the filter
        // is fully overridable rather than just a subset of the hardcoded defaults.
        List<pse__Proj__c> closedOnly = FinancialHealthController.getCurrentProjects(new List<String>{ 'Closed' });
        // Both the client project AND the internal bucket are 'In Progress' - request
        // it explicitly to prove the internal (no Opportunity) project is excluded
        // even when its stage IS in the requested filter.
        List<pse__Proj__c> inProgressOnly = FinancialHealthController.getCurrentProjects(
            new List<String>{ 'In Progress' }
        );
        Test.stopTest();

        Set<String> closedNames = new Set<String>();
        for (pse__Proj__c p : closedOnly) {
            closedNames.add(p.Name);
        }
        System.assert(closedNames.contains('Closed Client Project'), 'explicitly requested stage should be returned');
        System.assert(!closedNames.contains('Included Client Project'), 'stage not requested must be excluded');

        Set<String> inProgressNames = new Set<String>();
        for (pse__Proj__c p : inProgressOnly) {
            inProgressNames.add(p.Name);
        }
        System.assert(inProgressNames.contains('Included Client Project'), 'requested stage, real client project');
        System.assert(
            !inProgressNames.contains('Internal Bench Bucket'),
            'internal (no Opportunity) project must be excluded even when its stage is requested'
        );
    }

    @IsTest
    static void testGetNearCloseOpportunitiesFiltersByProbabilityAndWindow() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        // The "Project_Opportunity" record type gates moving past Qualification behind a
        // Key Fields validation rule; CL_Customer isn't gated by that rule, so use it here
        // to reach '3. Proposing' (80% default probability) without populating those fields.
        Id nonGatedRecordTypeId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Opportunity' AND DeveloperName = 'CL_Customer'
            LIMIT 1
        ].Id;

        // A validation rule requires every new Opportunity to start at '1. Qualification'
        // (0% default probability, auto-synced by this org's Stage automation - an
        // explicit Probability set at insert doesn't stick). Insert there, then move the
        // ones that need >=80% probability to '3. Proposing' (80% default) afterward.

        // in window, at threshold - should be returned
        Opportunity inWindow = new Opportunity(
            Name = 'In Window High Probability',
            AccountId = acc.Id,
            RecordTypeId = nonGatedRecordTypeId,
            StageName = '1. Qualification',
            CloseDate = Date.today().addDays(10)
        );
        // beyond the requested window - must NOT be returned
        Opportunity beyondWindow = new Opportunity(
            Name = 'Beyond Window',
            AccountId = acc.Id,
            RecordTypeId = nonGatedRecordTypeId,
            StageName = '1. Qualification',
            CloseDate = Date.today().addMonths(6)
        );
        // in window but below threshold - must NOT be returned
        Opportunity belowThreshold = new Opportunity(
            Name = 'Below Threshold',
            AccountId = acc.Id,
            RecordTypeId = nonGatedRecordTypeId,
            StageName = '1. Qualification',
            CloseDate = Date.today().addDays(10)
        );
        insert new List<Opportunity>{ inWindow, beyondWindow, belowThreshold };

        // Explicitly set Probability alongside the stage change rather than relying on
        // this org's Stage-to-Probability auto-sync, which - unlike outside test context -
        // doesn't reliably apply within an @IsTest method.
        inWindow.StageName = '3. Proposing';
        inWindow.Probability = 80;
        inWindow.Total_Hours__c = 120;
        beyondWindow.StageName = '3. Proposing';
        beyondWindow.Probability = 90;
        belowThreshold.StageName = '3. Proposing';
        belowThreshold.Probability = 50;
        update new List<Opportunity>{ inWindow, beyondWindow, belowThreshold };

        Test.startTest();
        List<Opportunity> results = FinancialHealthController.getNearCloseOpportunities(2, 80);
        Test.stopTest();

        // This org auto-rewrites Opportunity Name to a templated value on save
        // (e.g. "{Account} | {Type} - {Month/Year}"), so assert by Id, not Name.
        Map<Id, Opportunity> byId = new Map<Id, Opportunity>(results);
        System.assert(byId.containsKey(inWindow.Id), 'in-window, at-threshold opp should be returned');
        System.assert(!byId.containsKey(beyondWindow.Id), 'opp closing outside the window must be excluded');
        System.assert(!byId.containsKey(belowThreshold.Id), 'opp below the probability threshold must be excluded');
        System.assertEquals(120, byId.get(inWindow.Id).Total_Hours__c, 'estimated hours should be selected through');
    }

    @IsTest
    static void testGetNearCloseOpportunitiesDefaultsWhenParamsNull() {
        Test.startTest();
        List<Opportunity> results = FinancialHealthController.getNearCloseOpportunities(null, null);
        Test.stopTest();

        // defaults (2 months, 80%) should apply without throwing
        System.assertNotEquals(null, results);
    }

    @IsTest
    static void testGetResourceCapacityComputesTargetFromGoalAndScheduledFromEstVsActuals() {
        Test.setMock(HttpCalloutMock.class, new NoOpCalloutMock());
        Date currentMonthStart = Date.today().toStartOfMonth();
        Date currentMonthEnd = currentMonthStart.addMonths(1).addDays(-1);
        Date otherMonthEnd = currentMonthEnd.addMonths(1).toStartOfMonth().addMonths(1).addDays(-1);

        // PsaTestHarness (this org's existing PSA test-data utility, proven by
        // PsaTestHarnessTest) handles PSA's own Region/Permission Control setup - a
        // pse__Resource_Request__c otherwise fails with "You must have the Resource
        // Request Entry permission..." without a Permission Control granting it.
        PsaTestHarness harness = new PsaTestHarness();
        pse__Region__c region = harness.getRegionMaster();
        harness.newPermissionControl(true, UserInfo.getUserId(), region.Id);

        // Built manually rather than via harness.newProject - that helper defaults
        // Stage to 'In Progress' + Is_Billable__c to true, which this org's own
        // "missing essential data" validation rule additionally requires Project
        // Manager/Planned Hours/Primary Practice for. 'Planning' isn't gated by that
        // rule and is still a valid, billable, in-region project for Assignment
        // purposes.
        pse__Proj__c projectA = new pse__Proj__c(
            Name = 'Project A',
            pse__Region__c = region.Id,
            pse__Is_Billable__c = true,
            pse__Stage__c = 'Planning'
        );
        pse__Proj__c projectB = new pse__Proj__c(
            Name = 'Project B',
            pse__Region__c = region.Id,
            pse__Is_Billable__c = true,
            pse__Stage__c = 'Planning'
        );
        insert new List<pse__Proj__c>{ projectA, projectB };

        Contact activeResource = new Contact(
            LastName = 'Active Resource',
            pse__Region__c = region.Id,
            pse__Is_Resource_Active__c = true,
            pse__Is_Resource__c = true,
            pse__Default_Cost_Rate__c = 95,
            DCS_Billable_Goal__c = 40
        );
        // No Est_Vs_Actuals rows at all for this one - should still appear (Contact-
        // driven list, not Est_Vs_Actuals-driven) with scheduledHours = 0.
        Contact unassignedResource = new Contact(
            LastName = 'Unassigned Resource',
            pse__Region__c = region.Id,
            pse__Is_Resource_Active__c = true,
            pse__Is_Resource__c = true,
            pse__Default_Cost_Rate__c = 80,
            DCS_Billable_Goal__c = 40
        );
        // Inserted active (PSA won't let an assignment reference an inactive resource),
        // then deactivated below AFTER its assignment/Est_Vs_Actuals row exist - the
        // realistic shape of this scenario anyway (e.g. a since-departed employee whose
        // historical assignment data remains).
        Contact inactiveResource = new Contact(
            LastName = 'Inactive Resource',
            pse__Region__c = region.Id,
            pse__Is_Resource_Active__c = true,
            pse__Is_Resource__c = true,
            DCS_Billable_Goal__c = 40
        );
        insert new List<Contact>{ activeResource, unassignedResource, inactiveResource };

        // A Permission Control accepts exactly one scope (Resource, OR Region/
        // Practice/Group, OR Project/Opportunity/Team) - the Region-scoped grant
        // above covers Resource Request creation, but the internal rollup that
        // pse__Est_Vs_Actuals__c triggers on its parent Resource Request re-checks
        // permission scoped to the RESOURCE specifically, so each resource used below
        // needs its own grant too.
        harness.newPermissionControl(true, UserInfo.getUserId(), null, null, null, null, activeResource.Id, true);
        harness.newPermissionControl(true, UserInfo.getUserId(), null, null, null, null, inactiveResource.Id, true);

        // (a) + (b): two DIFFERENT projects, same resource, same month - Scheduled
        // Hours should be the SUM across both (the user's "each project that
        // individual is assigned to" requirement). pse__Est_Vs_Actuals__c requires
        // either an Assignment or a Resource Request - a Resource Request is used
        // here rather than a real pse__Assignment__c, since this org has a custom
        // AssignmentTriggerHandler on Assignment insert that calls into an unrelated
        // Password Vault integration (PasswordVaultService.addUsersToVault), which
        // errors in test context for synthetic resources with no linked Salesforce
        // User - a pre-existing issue in that integration, out of scope to fix here.
        // The Permission Control above already grants Resource Request Entry too.
        List<pse__Resource_Request__c> requests = new List<pse__Resource_Request__c>{
            new pse__Resource_Request__c(
                pse__Region__c = region.Id,
                pse__Resource__c = activeResource.Id,
                pse__Project__c = projectA.Id,
                pse__Start_Date__c = currentMonthStart,
                pse__End_Date__c = currentMonthEnd,
                pse__SOW_Hours__c = 25
            ),
            new pse__Resource_Request__c(
                pse__Region__c = region.Id,
                pse__Resource__c = activeResource.Id,
                pse__Project__c = projectB.Id,
                pse__Start_Date__c = currentMonthStart,
                pse__End_Date__c = currentMonthEnd,
                pse__SOW_Hours__c = 15
            ),
            new pse__Resource_Request__c(
                pse__Region__c = region.Id,
                pse__Resource__c = inactiveResource.Id,
                pse__Project__c = projectA.Id,
                pse__Start_Date__c = currentMonthStart,
                pse__End_Date__c = currentMonthEnd,
                pse__SOW_Hours__c = 500
            )
        };
        insert requests;

        pse__Est_Vs_Actuals__c projectARow = new pse__Est_Vs_Actuals__c(
            pse__Resource_Request__c = requests[0].Id,
            pse__Resource__c = activeResource.Id,
            pse__Project__c = projectA.Id,
            pse__Time_Period_Type__c = 'Month',
            pse__Start_Date__c = currentMonthStart,
            pse__End_Date__c = currentMonthEnd,
            pse__Estimated_Hours__c = 25,
            pse__Actual_Hours__c = 0
        );
        pse__Est_Vs_Actuals__c projectBRow = new pse__Est_Vs_Actuals__c(
            pse__Resource_Request__c = requests[1].Id,
            pse__Resource__c = activeResource.Id,
            pse__Project__c = projectB.Id,
            pse__Time_Period_Type__c = 'Month',
            pse__Start_Date__c = currentMonthStart,
            pse__End_Date__c = currentMonthEnd,
            pse__Estimated_Hours__c = 15,
            pse__Actual_Hours__c = 0
        );
        // (c) same resource, a different month - must NOT be included in the sum
        pse__Est_Vs_Actuals__c otherMonthRow = new pse__Est_Vs_Actuals__c(
            pse__Resource_Request__c = requests[0].Id,
            pse__Resource__c = activeResource.Id,
            pse__Project__c = projectA.Id,
            pse__Time_Period_Type__c = 'Month',
            pse__Start_Date__c = otherMonthEnd.toStartOfMonth(),
            pse__End_Date__c = otherMonthEnd,
            pse__Estimated_Hours__c = 999,
            pse__Actual_Hours__c = 0
        );
        // (d) inactive resource, current month - must NOT be included at all
        pse__Est_Vs_Actuals__c inactiveResourceRow = new pse__Est_Vs_Actuals__c(
            pse__Resource_Request__c = requests[2].Id,
            pse__Resource__c = inactiveResource.Id,
            pse__Project__c = projectA.Id,
            pse__Time_Period_Type__c = 'Month',
            pse__Start_Date__c = currentMonthStart,
            pse__End_Date__c = currentMonthEnd,
            pse__Estimated_Hours__c = 500,
            pse__Actual_Hours__c = 0
        );
        insert new List<pse__Est_Vs_Actuals__c>{ projectARow, projectBRow, otherMonthRow, inactiveResourceRow };

        // Deactivate AFTER the assignment/Est_Vs_Actuals rows are created (see comment
        // on inactiveResource above) - now simulates the real "excluded despite
        // historical data" scenario the query needs to filter out.
        inactiveResource.pse__Is_Resource_Active__c = false;
        update inactiveResource;

        Test.startTest();
        // Null params should default to the current-month window.
        List<FinancialHealthController.ResourceCapacityRow> results = FinancialHealthController.getResourceCapacity(
            null,
            null,
            null
        );
        Test.stopTest();

        Map<Id, FinancialHealthController.ResourceCapacityRow> byResourceId = new Map<Id, FinancialHealthController.ResourceCapacityRow>();
        for (FinancialHealthController.ResourceCapacityRow row : results) {
            byResourceId.put(row.resourceId, row);
        }

        System.assert(byResourceId.containsKey(activeResource.Id), 'active, assigned resource should be returned');
        System.assert(
            byResourceId.containsKey(unassignedResource.Id),
            'active resource with no Est_Vs_Actuals rows should still be returned, with 0 scheduled hours'
        );
        System.assert(!byResourceId.containsKey(inactiveResource.Id), 'inactive resource must be excluded entirely');

        System.assertEquals(
            40,
            byResourceId.get(activeResource.Id).scheduledHours,
            'scheduled hours should be the SUM of Estimated Hours across both current-month projects (25 + 15), excluding the other-month and inactive-resource rows'
        );
        System.assertEquals(0, byResourceId.get(unassignedResource.Id).scheduledHours);
        System.assertEquals(95, byResourceId.get(activeResource.Id).costRate);

        // Target hours = DCS_Billable_Goal__c (40, weekly) x (days in the current
        // month / 7) - same prorating math as the controller, computed independently
        // here so this test would catch a regression in either implementation.
        Decimal expectedWeeks = (Decimal) (currentMonthStart.daysBetween(currentMonthEnd) + 1) / 7;
        System.assertEquals(
            (40 * expectedWeeks).setScale(4),
            byResourceId.get(activeResource.Id).targetHours.setScale(4),
            'target hours should be the weekly goal prorated to the number of days in the current-month range'
        );
    }

    @IsTest
    static void testGetResourceCapacityHonorsPeriodTypeAndExplicitDateRange() {
        Test.setMock(HttpCalloutMock.class, new NoOpCalloutMock());
        Date currentMonthStart = Date.today().toStartOfMonth();
        Date currentMonthEnd = currentMonthStart.addMonths(1).addDays(-1);
        Date nextMonthEnd = currentMonthEnd.addMonths(1).toStartOfMonth().addMonths(1).addDays(-1);
        Date weekEnd = Date.today();
        Date weekStart = weekEnd.addDays(-6);

        PsaTestHarness harness = new PsaTestHarness();
        pse__Region__c region = harness.getRegionMaster();
        harness.newPermissionControl(true, UserInfo.getUserId(), region.Id);

        Contact resource = new Contact(
            LastName = 'Range Test Resource',
            pse__Region__c = region.Id,
            pse__Is_Resource_Active__c = true,
            pse__Is_Resource__c = true,
            pse__Default_Cost_Rate__c = 100,
            DCS_Billable_Goal__c = 40
        );
        insert resource;

        // See the equivalent comment in the test above - a resource-scoped grant is
        // also needed alongside the Region-scoped one.
        harness.newPermissionControl(true, UserInfo.getUserId(), null, null, null, null, resource.Id, true);

        // See comment above on the equivalent projectA/projectB setup: built manually
        // to avoid harness.newProject's 'In Progress' + billable default, which
        // triggers this org's "missing essential data" validation rule.
        pse__Proj__c project = new pse__Proj__c(
            Name = 'Range Test Project',
            pse__Region__c = region.Id,
            pse__Is_Billable__c = true,
            pse__Stage__c = 'Planning'
        );
        insert project;

        // pse__Est_Vs_Actuals__c requires either an Assignment or a Resource Request -
        // a Resource Request is used rather than a real pse__Assignment__c to avoid
        // this org's custom AssignmentTriggerHandler, which calls into an unrelated
        // Password Vault integration that errors for synthetic test resources (see
        // the equivalent comment in the test above).
        pse__Resource_Request__c request = new pse__Resource_Request__c(
                pse__Region__c = region.Id,
            pse__Resource__c = resource.Id,
            pse__Project__c = project.Id,
            pse__Start_Date__c = currentMonthStart,
            pse__End_Date__c = nextMonthEnd,
            pse__SOW_Hours__c = 80
        );
        insert request;

        pse__Est_Vs_Actuals__c monthRow1 = new pse__Est_Vs_Actuals__c(
            pse__Resource_Request__c = request.Id,
            pse__Resource__c = resource.Id,
            pse__Project__c = project.Id,
            pse__Time_Period_Type__c = 'Month',
            pse__Start_Date__c = currentMonthStart,
            pse__End_Date__c = currentMonthEnd,
            pse__Estimated_Hours__c = 50,
            pse__Actual_Hours__c = 0
        );
        pse__Est_Vs_Actuals__c monthRow2 = new pse__Est_Vs_Actuals__c(
            pse__Resource_Request__c = request.Id,
            pse__Resource__c = resource.Id,
            pse__Project__c = project.Id,
            pse__Time_Period_Type__c = 'Month',
            pse__Start_Date__c = nextMonthEnd.toStartOfMonth(),
            pse__End_Date__c = nextMonthEnd,
            pse__Estimated_Hours__c = 30,
            pse__Actual_Hours__c = 0
        );
        // Same underlying assignment, represented at Week granularity - if periodType
        // filtering didn't work, this would get double-counted alongside the Month rows.
        pse__Est_Vs_Actuals__c weekRow = new pse__Est_Vs_Actuals__c(
            pse__Resource_Request__c = request.Id,
            pse__Resource__c = resource.Id,
            pse__Project__c = project.Id,
            pse__Time_Period_Type__c = 'Week',
            pse__Start_Date__c = weekStart,
            pse__End_Date__c = weekEnd,
            pse__Estimated_Hours__c = 10,
            pse__Actual_Hours__c = 0
        );
        insert new List<pse__Est_Vs_Actuals__c>{ monthRow1, monthRow2, weekRow };

        Test.startTest();
        // A 2-month range should sum BOTH month rows for this resource.
        List<FinancialHealthController.ResourceCapacityRow> twoMonthRange = FinancialHealthController.getResourceCapacity(
            'Month',
            currentMonthStart,
            nextMonthEnd
        );
        // Switching periodType to 'Week' with a range covering only the week row
        // should pick up just that row's hours, proving periodType and date range are
        // independent filters and Month rows aren't mixed in.
        List<FinancialHealthController.ResourceCapacityRow> weekOnly = FinancialHealthController.getResourceCapacity(
            'Week',
            weekStart,
            weekEnd
        );
        // An unrecognized periodType should silently fall back to 'Month' rather than
        // throwing or returning everything.
        List<FinancialHealthController.ResourceCapacityRow> invalidPeriodType = FinancialHealthController.getResourceCapacity(
            'Quarter',
            currentMonthStart,
            currentMonthEnd
        );
        Test.stopTest();

        System.assertEquals(
            80,
            scheduledHoursFor(twoMonthRange, resource.Id),
            'both months in the requested range should be summed (50 + 30)'
        );
        System.assertEquals(
            10,
            scheduledHoursFor(weekOnly, resource.Id),
            'only the week-type row should be summed for a week-scoped range'
        );
        System.assertEquals(
            50,
            scheduledHoursFor(invalidPeriodType, resource.Id),
            'an unrecognized periodType should fall back to Month rather than erroring'
        );
    }

    private static Decimal scheduledHoursFor(List<FinancialHealthController.ResourceCapacityRow> rows, Id resourceId) {
        for (FinancialHealthController.ResourceCapacityRow row : rows) {
            if (row.resourceId == resourceId) {
                return row.scheduledHours;
            }
        }
        return null;
    }
}
