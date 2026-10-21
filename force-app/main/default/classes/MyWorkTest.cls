@IsTest
private class MyWorkTest {
    // PSA automation can call out while fixtures are created; absorb it (see FinancialHealthControllerTest).
    private class NoOpCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }

    private class StubLlm implements BusinessHealthAdvisor.Llm {
        String lastPrompt;
        public String generate(String model, String prompt) {
            lastPrompt = prompt;
            return '{"headline":"Book next month.","assessment":"Light schedule.","recommendations":[{"title":"Ask for staffing","action":"Talk to RM","why":"0 scheduled","impact":"+40h","owner":"You","timeframe":"This week","metric":"Scheduled"}],"watch":[],"dataFixes":[]}';
        }
    }

    private static void grant(List<String> permissions) {
        BusinessHealthAccess.testGrants = new Set<String>(permissions);
    }

    private static Map<String, BusinessHealthModel.Kpi> kpis(BusinessHealthModel.HealthPage page) {
        Map<String, BusinessHealthModel.Kpi> byKey = new Map<String, BusinessHealthModel.Kpi>();
        for (BusinessHealthModel.Kpi k : page.kpis) {
            byKey.put(k.key, k);
        }
        return byKey;
    }

    /**
     * A PSA resource linked to the running user, in a region the user can staff. Also sets
     * User.FFResourceContactId__c, as the org does: the FF_PROJECT_SYNC_PO_AND_PM flow sets
     * every project's Project Manager from its owner's FF Resource Contact Id.
     */
    private static Contact linkResource() {
        PsaTestHarness harness = new PsaTestHarness();
        pse__Region__c region = harness.getRegionMaster();
        harness.newPermissionControl(true, UserInfo.getUserId(), region.Id);
        Contact c = harness.newResource(true, null, UserInfo.getUserId(), region.Id, null);
        System.runAs(new User(Id = UserInfo.getUserId())) {
            update new User(Id = UserInfo.getUserId(), FFResourceContactId__c = c.Id);
        }
        return c;
    }

    @IsTest
    static void accessIsEnforcedPerPage() {
        grant(new List<String>());
        for (String key : new List<String>{ 'leadership', 'my-ae', 'my-unknown' }) {
            try {
                BusinessHealthController.getPage(key, Date.today(), null, null);
                System.assert(false, key + ' should be denied');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('permission set'), e.getMessage());
            }
        }
        grant(new List<String>{ 'My_Work_Consultant' });
        try {
            BusinessHealthController.getPage('leadership', Date.today(), null, null);
            System.assert(false, 'a My Work permission must not open the firm pages');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Business Health Viewer'), e.getMessage());
        }
    }

    @IsTest
    static void myWorkOptionsListOnlyGrantedViewsInOrder() {
        grant(new List<String>{ 'My_Work_Consultant', 'My_Work_Account_Executive' });
        BusinessHealthController.FilterOptions o = BusinessHealthController.getFilterOptions(BusinessHealthController.MODE_MY_WORK);
        System.assertEquals('mywork', o.mode);
        System.assertEquals(2, o.pages.size());
        System.assertEquals('my-ae', o.pages[0].key, 'display order follows MY_WORK_VIEWS');
        System.assertEquals('my-consultant', o.pages[1].key);
        System.assert(o.practices.isEmpty(), 'no practice filter in My Work');
        System.assertEquals(UserInfo.getFirstName(), o.firstName);
    }

    @IsTest
    static void personalGoalsLayerOverFirmGoalsAndStayOffFirmPages() {
        Date d = Date.today();
        insert new List<Business_Health_Goal_Set__c>{
            new Business_Health_Goal_Set__c(Name = 'Firm', Status__c = 'Active', Effective_Start__c = d.addMonths(-1), Win_Rate_Target__c = 35, Gross_Margin_Target__c = 41),
            new Business_Health_Goal_Set__c(Name = 'Mine', Status__c = 'Active', Effective_Start__c = d.addMonths(-1), Effective_End__c = d.addMonths(11),
                User__c = UserInfo.getUserId(), Win_Rate_Target__c = 45, Bookings_Quota__c = 1000000)
        };
        BusinessHealthContext mine = BusinessHealthContext.buildForUser(d, UserInfo.getUserId());
        System.assertEquals(45, mine.goals.Win_Rate_Target__c, 'personal target wins');
        System.assertEquals(41, mine.goals.Gross_Margin_Target__c, 'blank personal targets fall back to firm-wide');
        System.assertEquals(1000000, mine.goals.Bookings_Quota__c);
        System.assertEquals('Mine over Firm', mine.goalSetLabel());
        System.assertEquals(null, mine.goalSetId(), 'personal goal sets are not linked from the page');
        System.assertEquals(d.addMonths(-1), mine.goalPeriodStart());
        System.assertEquals(d.addMonths(11), mine.goalPeriodEnd());

        BusinessHealthContext firm = BusinessHealthContext.build(d, null);
        System.assertEquals('Firm', firm.goalSetLabel(), 'a personal set must never be read as the firm-wide set');
        System.assertEquals(35, firm.goals.Win_Rate_Target__c);
    }

    @IsTest
    static void personalGoalSetsHaveTheirOwnScope() {
        Id me = UserInfo.getUserId();
        pse__Practice__c practice = new pse__Practice__c(Name = 'Test Practice');
        insert practice;
        Id practiceId = practice.Id;
        insert new Business_Health_Goal_Set__c(Name = 'Firm', Status__c = 'Active', Effective_Start__c = Date.newInstance(2026, 1, 1));
        insert new Business_Health_Goal_Set__c(Name = 'Mine 2026', Status__c = 'Active', User__c = me, Effective_Start__c = Date.newInstance(2026, 1, 1),
            Effective_End__c = Date.newInstance(2026, 12, 31));
        Database.SaveResult overlap = Database.insert(new Business_Health_Goal_Set__c(Name = 'Mine Q4', Status__c = 'Active', User__c = me,
            Effective_Start__c = Date.newInstance(2026, 10, 1)), false);
        System.assert(!overlap.isSuccess(), 'two Active personal sets for one person may not overlap');
        Database.SaveResult both = Database.insert(new Business_Health_Goal_Set__c(Name = 'Both', Status__c = 'Draft', User__c = me,
            Practice__c = practiceId, Effective_Start__c = Date.newInstance(2027, 1, 1)), false);
        System.assert(!both.isSuccess(), 'a goal set targets a practice or a person, not both');
    }

    @IsTest
    static void accountExecutiveViewUsesQuotaAndOwnedPipeline() {
        grant(new List<String>{ 'My_Work_Account_Executive' });
        Account acc = new Account(Name = 'AE Test Account');
        insert acc;
        insert new Opportunity(Name = 'My Deal', AccountId = acc.Id, StageName = '1. Qualification', CloseDate = Date.today().addMonths(2), Amount = 50000);
        insert new Business_Health_Goal_Set__c(Name = 'My quota', Status__c = 'Active', User__c = UserInfo.getUserId(),
            Effective_Start__c = Date.newInstance(Date.today().year(), 1, 1), Effective_End__c = Date.newInstance(Date.today().year(), 12, 31),
            Bookings_Quota__c = 500000);
        Test.startTest();
        BusinessHealthModel.HealthPage page = BusinessHealthController.getPage('my-ae', Date.today(), null, null);
        BusinessHealthModel.HealthPage brief = BusinessHealthController.getPage('my-ae', Date.today(), null, BusinessHealthModel.VIEW_BRIEF);
        Test.stopTest();
        Map<String, BusinessHealthModel.Kpi> k = kpis(page);
        System.assertEquals(0, k.get('quotaAttainment').value);
        System.assert(!k.get('quotaAttainment').unavailable);
        System.assertEquals(1, k.get('openOpps').value);
        System.assertEquals(UserInfo.getName(), page.scopeLabel);
        System.assertEquals('My quota', page.goalSetLabel);
        System.assertEquals(4, brief.kpis.size(), 'abbreviated view keeps the four headline metrics');
    }

    @IsTest
    static void accountExecutiveWithoutQuotaShowsGap() {
        grant(new List<String>{ 'My_Work_Account_Executive' });
        BusinessHealthModel.HealthPage page = BusinessHealthController.getPage('my-ae', Date.today(), null, null);
        System.assert(kpis(page).get('quotaAttainment').unavailable);
        System.assert(kpis(page).get('pipelineCoverage').unavailable);
    }

    @IsTest
    static void deliveryViewsExplainAMissingResourceLink() {
        grant(new List<String>{ 'My_Work_Project_Manager', 'My_Work_Consultant' });
        // The running user's real FF Resource Contact Id points at a record tests can't see.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            update new User(Id = UserInfo.getUserId(), FFResourceContactId__c = null);
        }
        for (String key : new List<String>{ 'my-pm', 'my-consultant' }) {
            BusinessHealthModel.HealthPage page = BusinessHealthController.getPage(key, Date.today(), null, null);
            System.assert(kpis(page).get('noResource').unavailable, key);
        }
    }

    @IsTest
    static void projectManagerAndConsultantViewsUseMyResource() {
        Test.setMock(HttpCalloutMock.class, new NoOpCalloutMock());
        grant(new List<String>{ 'My_Work_Project_Manager', 'My_Work_Consultant', 'My_Work_Solution_Architect' });
        Contact me = linkResource();
        Account acc = new Account(Name = 'PM Test Account');
        insert acc;
        pse__Proj__c proj = new pse__Proj__c(Name = 'My Project', pse__Account__c = acc.Id, pse__Region__c = me.pse__Region__c, pse__Is_Active__c = true,
            pse__Stage__c = 'Planning', pse__Project_Manager__c = me.Id, pse__Start_Date__c = Date.today().addMonths(-1),
            pse__End_Date__c = Date.today().addDays(20), pse__Project_Status__c = 'Red');
        insert proj;
        insert new pse__Milestone__c(Name = 'Overdue sign-off', pse__Project__c = proj.Id, pse__Milestone_Amount__c = 1000,
            pse__Target_Date__c = Date.today().addDays(-5), pse__Status__c = 'Open');
        PsaTestHarness harness = new PsaTestHarness();
        pse__Schedule__c schedule = harness.newSchedule(true, Date.today().addDays(-14), Date.today().addDays(15), harness.SCHEDULE_PATTERN_8x5);
        pse__Assignment__c assignment = harness.newAssignment(false, proj.Id, me.Id, schedule.Id);
        assignment.pse__Is_Billable__c = false; // the project is non-billable
        assignment.pse__Bill_Rate__c = 0;
        insert assignment;
        insert new Opportunity(Name = 'Supported Deal', AccountId = acc.Id, StageName = '1. Qualification', CloseDate = Date.today().addMonths(1),
            Amount = 80000, Sales_Engineer__c = UserInfo.getUserId());
        Test.startTest();
        BusinessHealthModel.HealthPage pm = BusinessHealthController.getPage('my-pm', Date.today(), null, null);
        BusinessHealthModel.HealthPage consultant = BusinessHealthController.getPage('my-consultant', Date.today(), null, null);
        BusinessHealthModel.HealthPage architect = BusinessHealthController.getPage('my-architect', Date.today(), null, null);
        Test.stopTest();
        System.assertEquals(1, kpis(pm).get('activeProjects').value);
        System.assertEquals(0, kpis(pm).get('toApprove').value);
        System.assertEquals(1, kpis(pm).get('offTrack').value, 'red status');
        System.assertEquals(1, kpis(pm).get('overdueMilestones').value);
        Map<String, BusinessHealthModel.Kpi> c = kpis(consultant);
        System.assertEquals(0, c.get('util4').value);
        System.assertEquals(4, c.get('missingTimecards').value, 'no time logged in the last 4 weeks');
        System.assert(c.get('certifications').unavailable);
        System.assertEquals(1, c.get('assignments').value);
        System.assertEquals(80000, kpis(architect).get('supportedPipeline').value);
        System.assert(kpis(architect).containsKey('util4'), 'architects with a resource record also see their utilization');
    }

    @IsTest
    static void myTimecardsFeedUtilizationAndTheTeamView() {
        Test.setMock(HttpCalloutMock.class, new NoOpCalloutMock());
        grant(new List<String>{ 'My_Work_Project_Manager', 'My_Work_Consultant' });
        Contact me = linkResource();
        Account acc = new Account(Name = 'Timecard Test Account');
        insert acc;
        Date weekStart = MyWorkSupport.lastCompleteWeekStart(Date.today());
        pse__Proj__c proj = new pse__Proj__c(Name = 'Billable Project', pse__Account__c = acc.Id, pse__Region__c = me.pse__Region__c,
            pse__Is_Active__c = true, pse__Is_Billable__c = true, pse__Stage__c = 'Planning', pse__Project_Manager__c = me.Id,
            pse__Start_Date__c = weekStart.addDays(-7), pse__End_Date__c = weekStart.addDays(60));
        insert proj;
        PsaTestHarness harness = new PsaTestHarness();
        pse__Schedule__c schedule = harness.newSchedule(true, weekStart, weekStart.addDays(27), harness.SCHEDULE_PATTERN_8x5);
        pse__Assignment__c assignment = harness.newAssignment(true, proj.Id, me.Id, schedule.Id);
        harness.newTimecardHeader(true, me.Id, proj.Id, assignment.Id, null, weekStart, weekStart.addDays(6), 0, 8, 8, 8, 8, 8, 0);
        Test.startTest();
        BusinessHealthModel.HealthPage consultant = BusinessHealthController.getPage('my-consultant', Date.today(), null, null);
        BusinessHealthModel.HealthPage pm = BusinessHealthController.getPage('my-pm', Date.today(), null, null);
        Test.stopTest();
        // Org automation decides the new timecard's status and billability; the page must agree with it.
        pse__Timecard_Header__c tc = [SELECT pse__Status__c, pse__Billable__c, pse__Total_Hours__c FROM pse__Timecard_Header__c];
        Map<String, BusinessHealthModel.Kpi> c = kpis(consultant);
        System.assertEquals(40, tc.pse__Total_Hours__c);
        System.assertEquals(tc.pse__Billable__c ? 40 : 0, c.get('lastWeekBillable').value);
        System.assertEquals(tc.pse__Status__c == 'Saved' ? 1 : 0, c.get('savedTimecards').value);
        System.assertEquals(1, kpis(pm).get('activeProjects').value);
    }

    @IsTest
    static void financeViewHandlesAnOrgWithoutBillingEvents() {
        grant(new List<String>{ 'My_Work_Finance' });
        BusinessHealthModel.HealthPage page = BusinessHealthController.getPage('my-finance', Date.today(), null, null);
        Map<String, BusinessHealthModel.Kpi> k = kpis(page);
        System.assert(k.get('billedNotInvoiced').unavailable);
        System.assert(k.get('dso').unavailable);
        System.assertEquals(0, k.get('awaitingApproval').value);
    }

    @IsTest
    static void personalAdviceCoachesAndIsCachedPerPerson() {
        Test.setMock(HttpCalloutMock.class, new NoOpCalloutMock());
        grant(new List<String>{ 'My_Work_Consultant' });
        linkResource();
        StubLlm stub = new StubLlm();
        BusinessHealthAdvisor.llm = stub;
        BusinessHealthContext.settingsOverride = new Business_Health_Setting__mdt(AI_Enabled__c = true, AI_Cache_Hours__c = 12);
        Test.startTest();
        BusinessHealthAdvisor.Advice a = BusinessHealthAdvisor.getAdvice('my-consultant', Date.today(), null, false, null);
        Test.stopTest();
        System.assert(a.aiGenerated);
        System.assert(stub.lastPrompt.contains('speak to them directly as "you"'), 'personal pages use the coaching voice');
        Business_Health_Insight__c row = [SELECT Scope__c, Page__c FROM Business_Health_Insight__c LIMIT 1];
        System.assertEquals('USER:' + UserInfo.getUserId(), row.Scope__c);
        System.assertEquals('my-consultant', row.Page__c);
    }
}
