/**
 * Page-level tests with a realistic book of work: two years of weekly timecard facts for
 * a tenured consultant and a recent hire, a lapsed client, a red T&M project and a
 * fixed-fee project with an overdue milestone. Timecard and milestone facts are supplied
 * through BusinessHealthData's test seam; everything else is real records.
 */
@IsTest
private class BusinessHealthPagesTest {
    static {
        BusinessHealthAccess.testGrants = new Set<String>{ BusinessHealthAccess.VIEWER };
    }

    // PSA automation can call out while fixtures are created; absorb it (see FinancialHealthControllerTest).
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
        Test.setMock(HttpCalloutMock.class, new NoOpCalloutMock());
        Date today = Date.today();
        insert new pse__Practice__c(Name = 'Test Practice');
        List<Account> accounts = new List<Account>{ new Account(Name = 'Portfolio Client'), new Account(Name = 'Lapsed Client') };
        insert accounts;
        List<Opportunity> opps = new List<Opportunity>{
            new Opportunity(Name = 'Change Order', AccountId = accounts[0].Id, StageName = '1. Qualification', CloseDate = today.addDays(-20),
                Amount = 120000, Type = 'Existing Cust - Change Order'),
            new Opportunity(Name = 'Next Phase', AccountId = accounts[0].Id, StageName = '1. Qualification', CloseDate = today.addMonths(2),
                Amount = 60000)
        };
        insert opps;
        // New opportunities must start in Qualification; close the change order afterward.
        // Not fatal: closing runs org automation that tests shouldn't depend on.
        opps[0].StageName = 'Closed Won';
        Database.update(opps[0], false);

        List<pse__Proj__c> projects = new List<pse__Proj__c>{
            new pse__Proj__c(Name = 'Portfolio Client | Phase 2 - Build', pse__Account__c = accounts[0].Id, pse__Opportunity__c = opps[0].Id,
                pse__Stage__c = 'Planning', pse__Is_Active__c = true, pse__Is_Billable__c = true, pse__Billing_Type__c = 'Time and Materials',
                pse__Bookings__c = 100000, pse__Planned_Hours__c = 2000, pse__Project_Status__c = 'Red', pse__Financial_Status__c = 'Yellow',
                pse__Schedule_Status__c = 'Green', pse__Start_Date__c = today.addYears(-2), pse__End_Date__c = today.addMonths(2)),
            new pse__Proj__c(Name = 'Portfolio Client | Fixed Fee', pse__Account__c = accounts[0].Id, pse__Opportunity__c = opps[1].Id,
                pse__Stage__c = 'Planning', pse__Is_Active__c = true, pse__Is_Billable__c = true, pse__Billing_Type__c = 'Fixed Price',
                pse__Bookings__c = 50000, pse__Planned_Hours__c = 300, pse__Start_Date__c = today.addMonths(-3), pse__End_Date__c = today.addMonths(3))
        };
        insert projects;
        Database.insert(new pse__Milestone__c(Name = 'Design sign-off', pse__Project__c = projects[1].Id, pse__Milestone_Amount__c = 10000,
            pse__Target_Date__c = today.addDays(-10), pse__Status__c = 'Open'), false);

        insert new List<Contact>{
            new Contact(LastName = 'Veteran', pse__Is_Resource__c = true, pse__Is_Resource_Active__c = true, pse__Resource_Role__c = 'Consultant',
                DCS_Billable_Goal__c = 40, pse__Default_Cost_Rate__c = 60, pse__Start_Date__c = today.addYears(-3), pse__Utilization_Target__c = 90),
            new Contact(LastName = 'New Hire', pse__Is_Resource__c = true, pse__Is_Resource_Active__c = true, pse__Resource_Role__c = 'Senior Consultant',
                DCS_Billable_Goal__c = 40, pse__Default_Cost_Rate__c = 70, pse__Start_Date__c = today.addDays(-70)),
            new Contact(LastName = 'Benched', pse__Is_Resource__c = true, pse__Is_Resource_Active__c = true, DCS_Billable_Goal__c = 40,
                pse__Start_Date__c = today.addYears(-1)),
            new Contact(LastName = 'Leaver', pse__Is_Resource__c = true, pse__Is_Resource_Active__c = false, pse__Resource_Role__c = 'Consultant',
                pse__Start_Date__c = today.addYears(-2), pse__Last_Date__c = today.addMonths(-2)),
            new Contact(LastName = 'Undated Leaver', pse__Is_Resource__c = true, pse__Is_Resource_Active__c = false),
            new Contact(LastName = 'Subcontractor', pse__Is_Resource__c = true, pse__Is_Resource_Active__c = true, pse__External_Resource__c = true)
        };
    }

    private static BusinessHealthData.TimecardFact fact(Contact c, pse__Proj__c p, Date endDate, Decimal hours, Boolean billable) {
        BusinessHealthData.TimecardFact f = new BusinessHealthData.TimecardFact();
        f.projectId = p.Id;
        f.projectName = p.Name;
        f.accountId = p.pse__Account__c;
        f.accountName = p.pse__Account__r.Name;
        f.practiceName = 'Test Practice';
        f.billingType = p.pse__Billing_Type__c;
        f.clientProject = true;
        f.recurring = false;
        f.resourceId = c.Id;
        f.resourceName = c.Name;
        f.resourceRole = c.pse__Resource_Role__c;
        f.assignmentRole = 'Consultant';
        f.external = false;
        f.endDate = endDate;
        f.monthKey = BusinessHealthContext.monthKey(endDate);
        f.hours = hours;
        f.billableHours = billable ? hours : 0;
        f.revenue = billable && f.billingType != 'Fixed Price' ? hours * 200 : 0;
        f.cost = hours * 60;
        f.unbilled = f.revenue > 0 && endDate > Date.today().addDays(-60);
        return f;
    }

    /** Loads the fixture's timecard and milestone facts into BusinessHealthData. */
    private static void loadFacts() {
        Map<String, Contact> people = new Map<String, Contact>();
        for (Contact c : [SELECT Id, Name, LastName, pse__Resource_Role__c, pse__Start_Date__c FROM Contact]) {
            people.put(c.LastName, c);
        }
        Map<String, pse__Proj__c> projects = new Map<String, pse__Proj__c>();
        for (pse__Proj__c p : [SELECT Id, Name, pse__Account__c, pse__Account__r.Name, pse__Billing_Type__c FROM pse__Proj__c]) {
            projects.put(p.Name, p);
        }
        pse__Proj__c build = projects.get('Portfolio Client | Phase 2 - Build');
        pse__Proj__c fixed = projects.get('Portfolio Client | Fixed Fee');
        Account lapsed = [SELECT Id, Name FROM Account WHERE Name = 'Lapsed Client'];
        pse__Proj__c lapsedWork = new pse__Proj__c(Name = 'Lapsed Client | Support', pse__Account__c = lapsed.Id,
            pse__Account__r = lapsed, pse__Billing_Type__c = 'Time and Materials');

        List<BusinessHealthData.TimecardFact> facts = new List<BusinessHealthData.TimecardFact>();
        Date lastSaturday = Date.today().toStartOfWeek().addDays(-1);
        for (Integer w = 0; w < 104; w++) {
            Date weekEnd = lastSaturday.addDays(-7 * w);
            BusinessHealthData.TimecardFact f = fact(people.get('Veteran'), build, weekEnd, 40, true);
            f.recurring = w < 8;
            facts.add(f);
            if (Math.mod(w, 4) == 0) {
                facts.add(fact(people.get('Veteran'), build, weekEnd, 8, false)); // written off
                facts.add(fact(people.get('Veteran'), fixed, weekEnd, 6, false));
            }
            if (w >= 60 && w < 80) {
                facts.add(fact(people.get('Veteran'), lapsedWork, weekEnd, 10, true));
            }
            if (weekEnd > people.get('New Hire').pse__Start_Date__c) {
                facts.add(fact(people.get('New Hire'), build, weekEnd, 30, true));
            }
        }
        BusinessHealthData.TimecardFact sub = fact(people.get('Subcontractor'), build, lastSaturday, 20, true);
        sub.external = true;
        facts.add(sub);
        // Time logged after the last complete week is left out of weekly utilization.
        facts.add(fact(people.get('Veteran'), build, Date.today(), 4, true));
        BusinessHealthData.testTimecards = facts;

        List<BusinessHealthData.MilestoneFact> milestones = new List<BusinessHealthData.MilestoneFact>();
        for (Integer i = 0; i < 3; i++) {
            BusinessHealthData.MilestoneFact m = new BusinessHealthData.MilestoneFact();
            m.projectId = fixed.Id;
            m.projectName = fixed.Name;
            m.accountId = fixed.pse__Account__c;
            m.accountName = fixed.pse__Account__r.Name;
            m.practiceName = 'Test Practice';
            m.recurring = i == 0;
            m.actualDate = i == 2 ? Date.today() : Date.today().addMonths(-1 - i);
            m.monthKey = BusinessHealthContext.monthKey(m.actualDate);
            m.amount = 20000;
            milestones.add(m);
        }
        BusinessHealthData.testMilestones = milestones;
    }

    private static Map<String, BusinessHealthModel.Kpi> kpis(BusinessHealthModel.HealthPage page) {
        Map<String, BusinessHealthModel.Kpi> byKey = new Map<String, BusinessHealthModel.Kpi>();
        for (BusinessHealthModel.Kpi k : page.kpis) {
            byKey.put(k.key, k);
        }
        return byKey;
    }

    private static BusinessHealthModel.Table table(BusinessHealthModel.HealthPage page, String key) {
        for (BusinessHealthModel.Table t : page.tables) {
            if (t.key == key) {
                return t;
            }
        }
        System.assert(false, 'no table ' + key);
        return null;
    }

    private static BusinessHealthModel.HealthPage build(String key) {
        loadFacts();
        Test.startTest();
        BusinessHealthModel.HealthPage page = BusinessHealthController.getPage(key, Date.today(), null, null);
        Test.stopTest();
        return page;
    }

    @IsTest
    static void capacityRanksPeopleAndRolesFromTimecards() {
        BusinessHealthModel.HealthPage page = build('capacity');
        // Veteran, New Hire and Benched have billable goals; the subcontractor is external.
        System.assertEquals(3, table(page, 'byPerson').rows.size());
        System.assertEquals(3, table(page, 'byRole').rows.size(), 'Consultant, Senior Consultant and No role set');

        // Targets come from each person's Utilization Target, else their role's default.
        Decimal seniorDefault = BusinessHealthContext.build(Date.today(), null).roleTarget('Senior Consultant');
        Map<Object, Object> personTarget = new Map<Object, Object>();
        for (Map<String, Object> row : table(page, 'byPerson').rows) {
            personTarget.put(row.get('name'), row.get('target'));
        }
        System.assertEquals(90, personTarget.get('Veteran'));
        System.assertEquals(seniorDefault, personTarget.get('New Hire'));
        for (Map<String, Object> row : table(page, 'byRole').rows) {
            if (row.get('role') == 'Consultant') {
                System.assertEquals(90, row.get('target'), 'a role\'s target is its people\'s average');
            }
        }
        Boolean flagged = false;
        for (String gap : page.dataGaps) {
            flagged |= gap.startsWith('2 delivery resources have no Utilization Target');
        }
        System.assert(flagged, page.dataGaps);
    }

    @IsTest
    static void financeBreaksMarginDownByProjectClientPracticeAndRole() {
        BusinessHealthModel.HealthPage page = build('finance');
        Set<Object> projects = new Set<Object>();
        for (Map<String, Object> row : table(page, 'projectMargin').rows) {
            projects.add(row.get('name'));
        }
        System.assert(projects.contains('Portfolio Client | Phase 2 - Build'), projects);
        System.assert(!table(page, 'clientMargin').rows.isEmpty());
        System.assert(!table(page, 'practiceMargin').rows.isEmpty());
        System.assert(!table(page, 'unbilledWip').rows.isEmpty(), 'recent approved billable time is unbilled WIP');
    }

    @IsTest
    static void portfolioFlagsALapsedClient() {
        BusinessHealthModel.HealthPage page = build('portfolio');
        List<Map<String, Object>> declining = table(page, 'decliningClients').rows;
        System.assertEquals(1, declining.size());
        System.assertEquals('Lapsed Client', declining[0].get('name'));
        System.assertEquals(1, table(page, 'clients').rows.size(), 'only clients with revenue in the last 12 months');
    }

    @IsTest
    static void peopleCountsHiresDeparturesAndRamp() {
        BusinessHealthModel.HealthPage page = build('people');
        Map<String, BusinessHealthModel.Kpi> k = kpis(page);
        System.assertEquals(3, k.get('headcount').value, 'active employees; the subcontractor is counted separately');
        System.assertEquals(1, k.get('hires').value);
        System.assert(!k.get('ramp').unavailable, 'the new hire logs time in their first weeks');
        System.assertEquals(1, table(page, 'departures').rows.size());
    }

    @IsTest
    static void myFinanceAgesUnbilledWipByProject() {
        BusinessHealthAccess.testGrants.add('My_Work_Finance');
        BusinessHealthModel.HealthPage page = build('my-finance');
        Map<String, BusinessHealthModel.Kpi> k = kpis(page);
        System.assert(k.get('unbilledWip').value > 0);
        System.assert(k.get('revenueMtd').value > 0, 'this month\'s timecards and milestones');
        System.assertEquals(1, table(page, 'wipByProject').rows.size());
    }

    @IsTest
    static void deliveryFlagsRedAndOverBudgetProjects() {
        BusinessHealthModel.HealthPage page = build('delivery');
        List<Map<String, Object>> atRisk = table(page, 'atRisk').rows;
        System.assertEquals(1, atRisk.size(), 'the red project');
        System.assertEquals('Portfolio Client | Phase 2 - Build', atRisk[0].get('name'));
        System.assertEquals(1, table(page, 'fixedFeeBurn').rows.size());
    }
}
