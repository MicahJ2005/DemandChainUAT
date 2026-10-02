@IsTest
private class BusinessHealthTest {
    // PSA's managed-package automation can make an outbound callout while fixtures are
    // created; test methods can't call out, so absorb it (see FinancialHealthControllerTest).
    private class NoOpCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }

    private class StubLlm implements BusinessHealthAdvisor.Llm {
        Integer calls = 0;
        String response;
        Boolean fail = false;

        StubLlm(String response) {
            this.response = response;
        }

        public String generate(String model, String prompt) {
            calls++;
            if (fail) {
                throw new CalloutException('Model offline');
            }
            System.assert(prompt.contains('<dashboard>'), 'prompt wraps the page data');
            return response;
        }
    }

    private static final String GOOD_JSON =
        '```json\n{"headline":"Pipeline is thin.","assessment":"Coverage is low.",' +
        '"recommendations":[{"title":"Build pipeline","action":"Plan accounts","why":"0.7x","impact":"+$1M","owner":"Sales","timeframe":"This month","metric":"Coverage"}],' +
        '"watch":["Bookings"],"dataFixes":["Add FSC"]}\n```';

    @TestSetup
    static void setup() {
        Test.setMock(HttpCalloutMock.class, new NoOpCalloutMock());
        Account acc = new Account(Name = 'Business Health Test Account');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Business Health Test Opportunity',
            AccountId = acc.Id,
            StageName = '1. Qualification',
            CloseDate = Date.today().addMonths(1),
            Amount = 100000
        );
        insert opp;
        insert new pse__Practice__c(Name = 'Test Practice');
        insert new pse__Proj__c(
            Name = 'Business Health Test Project',
            pse__Account__c = acc.Id,
            pse__Opportunity__c = opp.Id,
            pse__Stage__c = 'In Progress',
            pse__Is_Active__c = true,
            pse__Billing_Type__c = 'Fixed Price'
        );
    }

    // One page build is ~10 queries, so firm-wide and practice-scoped runs are split
    // across two tests to stay under the per-transaction SOQL limit.
    @IsTest
    static void everyPageBuildsForTheWholeFirm() {
        Test.setMock(HttpCalloutMock.class, new NoOpCalloutMock());
        Test.startTest();
        for (String key : BusinessHealthController.PAGE_ORDER) {
            BusinessHealthModel.HealthPage firm = BusinessHealthController.getPage(key, Date.today(), null);
            System.assertEquals(key, firm.key);
            System.assert(!firm.kpis.isEmpty(), key + ' has KPIs');
            System.assertEquals('All practices', firm.scopeLabel);
        }
        Test.stopTest();
    }

    @IsTest
    static void everyPageBuildsForAPractice() {
        Test.setMock(HttpCalloutMock.class, new NoOpCalloutMock());
        Id practiceId = [SELECT Id FROM pse__Practice__c LIMIT 1].Id;
        Test.startTest();
        for (String key : BusinessHealthController.PAGE_ORDER) {
            BusinessHealthModel.HealthPage scoped = BusinessHealthController.getPage(key, Date.today(), practiceId);
            System.assertEquals('Test Practice practice', scoped.scopeLabel);
        }
        Test.stopTest();
    }

    @IsTest
    static void unknownPageIsRejected() {
        try {
            BusinessHealthController.getPage('nope', null, null);
            System.assert(false, 'expected an error');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Unknown Business Health page'), e.getMessage());
        }
    }

    @IsTest
    static void filterOptionsListPagesInOrderAndPractices() {
        BusinessHealthController.FilterOptions o = BusinessHealthController.getFilterOptions();
        System.assertEquals(BusinessHealthController.PAGE_ORDER.size(), o.pages.size());
        System.assertEquals('leadership', o.pages[0].key);
        System.assertEquals(1, o.practices.size());
        // No timecards in a test context, so the default as-of date is today.
        System.assertEquals(Date.today(), o.defaultAsOfDate);
    }

    @IsTest
    static void contextWindowsUseCompleteMonths() {
        BusinessHealthContext ctx = BusinessHealthContext.build(Date.newInstance(2025, 2, 15), null);
        System.assertEquals(Date.newInstance(2025, 1, 1), ctx.referenceMonthStart(), 'mid-month as-of uses the prior month');
        System.assertEquals(Date.newInstance(2024, 2, 1), ctx.windowStart(12));
        System.assertEquals(Date.newInstance(2025, 1, 31), ctx.windowEnd());
        System.assertEquals('2025-01', ctx.completeMonthKeys(3)[2]);
        BusinessHealthContext monthEnd = BusinessHealthContext.build(Date.newInstance(2025, 1, 31), null);
        System.assertEquals(Date.newInstance(2025, 1, 1), monthEnd.referenceMonthStart(), 'month-end as-of includes that month');
        System.assertEquals('', ctx.practiceClause('pse__Practice__c'));
    }

    @IsTest
    static void roleTargetsComeFromTheActiveGoalSet() {
        insert new Business_Health_Goal_Set__c(
            Name = 'FY goals',
            Status__c = 'Active',
            Effective_Start__c = Date.today().addMonths(-1),
            Role_Utilization_Targets__c = 'Developer=82; Architect = 60;Bad=x',
            Delivery_Utilization_Target__c = 70,
            Strategic_Skills__c = 'Agentforce; Data Cloud'
        );
        BusinessHealthContext ctx = BusinessHealthContext.build(Date.today(), null);
        System.assertEquals(82, ctx.roleTarget('developer'));
        System.assertEquals(60, ctx.roleTarget('Architect'));
        System.assertEquals(70, ctx.roleTarget('Bad'), 'unparseable target falls back');
        System.assertEquals(70, ctx.roleTarget(null));
        System.assertEquals(new List<String>{ 'Agentforce', 'Data Cloud' }, ctx.strategicSkills());
        System.assertEquals('FY goals', ctx.goalSetLabel());
    }

    @IsTest
    static void goalsResolvePracticeThenFirmThenDefaults() {
        Id practiceId = [SELECT Id FROM pse__Practice__c LIMIT 1].Id;
        BusinessHealthContext.settingsOverride = new Business_Health_Setting__mdt(Win_Rate_Target__c = 33, Attrition_Target__c = 11);
        Date d = Date.newInstance(2026, 5, 15);
        insert new List<Business_Health_Goal_Set__c>{
            // In force on d, firm-wide.
            new Business_Health_Goal_Set__c(Name = 'FY2026', Status__c = 'Active', Effective_Start__c = Date.newInstance(2026, 1, 1),
                Effective_End__c = Date.newInstance(2026, 12, 31), Gross_Margin_Target__c = 42, Win_Rate_Target__c = 36),
            // Previous year: not in force on d.
            new Business_Health_Goal_Set__c(Name = 'FY2025', Status__c = 'Active', Effective_Start__c = Date.newInstance(2025, 1, 1),
                Effective_End__c = Date.newInstance(2025, 12, 31), Gross_Margin_Target__c = 38),
            // Draft covering d: ignored.
            new Business_Health_Goal_Set__c(Name = 'FY2026 draft', Status__c = 'Draft', Effective_Start__c = Date.newInstance(2026, 1, 1), Gross_Margin_Target__c = 99),
            // Practice override for Q2 only.
            new Business_Health_Goal_Set__c(Name = 'Q2 practice', Status__c = 'Active', Practice__c = practiceId,
                Effective_Start__c = Date.newInstance(2026, 4, 1), Effective_End__c = Date.newInstance(2026, 6, 30), Gross_Margin_Target__c = 50)
        };

        BusinessHealthContext firm = BusinessHealthContext.build(d, null);
        System.assertEquals(42, firm.goals.Gross_Margin_Target__c, 'firm-wide set in force on the date');
        System.assertEquals(36, firm.goals.Win_Rate_Target__c);
        System.assertEquals(11, firm.goals.Attrition_Target__c, 'blank fields fall back to system defaults');
        System.assertEquals('FY2026', firm.goalSetLabel());

        BusinessHealthContext scoped = BusinessHealthContext.build(d, practiceId);
        System.assertEquals(50, scoped.goals.Gross_Margin_Target__c, 'practice set overrides firm-wide');
        System.assertEquals(36, scoped.goals.Win_Rate_Target__c, 'blank practice fields fall back to firm-wide');
        System.assertEquals('Q2 practice over FY2026', scoped.goalSetLabel());

        BusinessHealthContext lastYear = BusinessHealthContext.build(Date.newInstance(2025, 6, 1), practiceId);
        System.assertEquals(38, lastYear.goals.Gross_Margin_Target__c, 'history uses the goals in force at the time');

        BusinessHealthContext none = BusinessHealthContext.build(Date.newInstance(2020, 1, 1), null);
        System.assertEquals(33, none.goals.Win_Rate_Target__c);
        System.assert(none.goalSetLabel().startsWith('System defaults'));
        System.assertEquals(null, none.goalSetId());
    }

    @IsTest
    static void overlappingActiveGoalSetsAreRejected() {
        Id practiceId = [SELECT Id FROM pse__Practice__c LIMIT 1].Id;
        insert new Business_Health_Goal_Set__c(Name = 'FY2026', Status__c = 'Active', Effective_Start__c = Date.newInstance(2026, 1, 1),
            Effective_End__c = Date.newInstance(2026, 12, 31));
        // Different scope and non-overlapping versions are fine.
        insert new List<Business_Health_Goal_Set__c>{
            new Business_Health_Goal_Set__c(Name = 'Practice FY2026', Status__c = 'Active', Practice__c = practiceId, Effective_Start__c = Date.newInstance(2026, 1, 1)),
            new Business_Health_Goal_Set__c(Name = 'FY2027', Status__c = 'Active', Effective_Start__c = Date.newInstance(2027, 1, 1)),
            new Business_Health_Goal_Set__c(Name = 'Q3 draft', Status__c = 'Draft', Effective_Start__c = Date.newInstance(2026, 7, 1))
        };
        try {
            insert new Business_Health_Goal_Set__c(Name = 'Q3 revision', Status__c = 'Active', Effective_Start__c = Date.newInstance(2026, 7, 1),
                Effective_End__c = Date.newInstance(2026, 9, 30));
            System.assert(false, 'expected an overlap error');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('FY2026'), e.getMessage());
        }
        // Activating the overlapping draft is blocked too.
        Business_Health_Goal_Set__c draft = [SELECT Id FROM Business_Health_Goal_Set__c WHERE Name = 'Q3 draft'];
        draft.Status__c = 'Active';
        Database.SaveResult sr = Database.update(draft, false);
        System.assert(!sr.isSuccess(), 'activating an overlapping draft must fail');
        // Two overlapping Active sets in the same save are caught.
        List<Database.SaveResult> batch = Database.insert(new List<Business_Health_Goal_Set__c>{
            new Business_Health_Goal_Set__c(Name = 'A', Status__c = 'Active', Practice__c = practiceId, Effective_Start__c = Date.newInstance(2030, 1, 1)),
            new Business_Health_Goal_Set__c(Name = 'B', Status__c = 'Active', Practice__c = practiceId, Effective_Start__c = Date.newInstance(2030, 6, 1))
        }, false);
        System.assert(!batch[1].isSuccess(), 'second overlapping record in the batch is rejected');
    }

    @IsTest
    static void kpiStatusAndFormatting() {
        System.assertEquals('good', BusinessHealthModel.evaluate(80, 75, 'higher', 0.1));
        System.assertEquals('warn', BusinessHealthModel.evaluate(70, 75, 'higher', 0.1));
        System.assertEquals('bad', BusinessHealthModel.evaluate(50, 75, 'higher', 0.1));
        System.assertEquals('good', BusinessHealthModel.evaluate(30, 35, 'lower', 0.1));
        System.assertEquals('warn', BusinessHealthModel.evaluate(37, 35, 'lower', 0.1));
        System.assertEquals('bad', BusinessHealthModel.evaluate(50, 35, 'lower', 0.1));
        System.assertEquals('neutral', BusinessHealthModel.evaluate(null, 35, 'lower', 0.1));
        System.assertEquals('$1.5M', BusinessHealthModel.formatValue(1500000, 'currency'));
        System.assertEquals('$25K', BusinessHealthModel.formatValue(25000, 'currency'));
        System.assertEquals('1.25x', BusinessHealthModel.formatValue(1.25, 'ratio'));
        System.assertEquals('n/a', BusinessHealthModel.formatValue(null, 'percent'));
        System.assertEquals(null, BusinessHealthModel.pct(1, 0));
        System.assertEquals(50.0, BusinessHealthModel.pct(1, 2));

        BusinessHealthModel.HealthPage page = new BusinessHealthModel.HealthPage('k', 'T', 'S', 'A');
        page.addKpi(new BusinessHealthModel.Kpi('a', 'A', 10, 'percent')).target(75, 'higher', 0.1);
        page.addKpi(new BusinessHealthModel.Kpi('b', 'B', null, 'days')).markUnavailable('gap');
        page.signalMissedKpis();
        System.assertEquals(1, page.signals.size());
        System.assertEquals('not available', page.kpis[1].displayValue());

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{ 'v' => 2 },
            new Map<String, Object>{ 'v' => null },
            new Map<String, Object>{ 'v' => 5 }
        };
        BusinessHealthModel.sortRows(rows, 'v');
        System.assertEquals(5, rows[0].get('v'));
        System.assertEquals(null, rows[2].get('v'), 'nulls sort last');
        BusinessHealthModel.sortRowsAscending(rows, 'v');
        System.assertEquals(2, rows[0].get('v'));
        System.assertEquals(2, BusinessHealthModel.first(rows, 2).size());
    }

    private static BusinessHealthData.TimecardFact fact(String monthKey, Date endDate, Decimal hours, Decimal billable, Decimal revenue, Decimal cost, Id resourceId) {
        BusinessHealthData.TimecardFact f = new BusinessHealthData.TimecardFact();
        f.monthKey = monthKey;
        f.endDate = endDate;
        f.hours = hours;
        f.billableHours = billable;
        f.revenue = revenue;
        f.cost = cost;
        f.resourceId = resourceId;
        f.clientProject = true;
        f.recurring = revenue > 100;
        f.unbilled = revenue > 0;
        return f;
    }

    @IsTest
    static void derivedMetricsFromFacts() {
        Id r1 = [SELECT Id FROM Account LIMIT 1].Id; // any Id works as a resource key here
        List<BusinessHealthData.TimecardFact> tcs = new List<BusinessHealthData.TimecardFact>{
            fact('2025-01', Date.newInstance(2025, 1, 25), 40, 30, 3000, 1500, r1),
            fact('2024-09', Date.newInstance(2024, 9, 7), 40, 40, 100, 50, r1)
        };
        BusinessHealthData.MilestoneFact m = new BusinessHealthData.MilestoneFact();
        m.monthKey = '2025-01';
        m.amount = 1000;
        m.recurring = false;
        m.accountId = r1;
        m.actualDate = Date.newInstance(2025, 1, 10);
        List<BusinessHealthData.MilestoneFact> ms = new List<BusinessHealthData.MilestoneFact>{ m };

        Map<String, Decimal> delivered = BusinessHealthData.deliveredByMonth(tcs, ms);
        System.assertEquals(4000, delivered.get('2025-01'));
        Map<String, Decimal> cost = BusinessHealthData.clientCostByMonth(tcs);
        System.assertEquals(62.5, BusinessHealthData.marginPct(delivered, cost, new List<String>{ '2025-01' }));
        System.assertEquals(3000, BusinessHealthData.recurringByMonth(tcs, ms).get('2025-01'));

        List<Decimal> util = BusinessHealthData.utilizationSeries(tcs, new Set<Id>{ r1 }, new List<String>{ '2025-01' }, 40);
        System.assertEquals(BusinessHealthModel.pct(30, 40 * 31 / 7.0), util[0]);

        List<Decimal> wip = BusinessHealthData.unbilledWip(tcs, Date.newInstance(2025, 2, 15));
        System.assertEquals(3000, wip[0], 'recent unbilled time is WIP');
        System.assertEquals(100, wip[1], 'older unbilled time is stale');

        Map<Id, String> names = new Map<Id, String>();
        Map<Id, Decimal> byAccount = BusinessHealthData.deliveredByAccount(tcs, ms, Date.newInstance(2025, 1, 1), Date.newInstance(2025, 1, 31), names);
        System.assertEquals(1000, byAccount.get(r1), 'timecard facts without an account are skipped');
        System.assertEquals(100, BusinessHealthData.topShare(byAccount, 5));

        Map<String, Decimal> num = new Map<String, Decimal>{ 'a' => 1, 'b' => 3 };
        Map<String, Decimal> den = new Map<String, Decimal>{ 'a' => 2, 'b' => 2 };
        System.assertEquals(new List<Decimal>{ 0.50, 1.00 }, BusinessHealthData.rollingRatio(num, den, new List<String>{ 'a', 'b' }, 2));
        System.assertEquals(new List<Decimal>{ 1, 3 }, BusinessHealthData.series(num, new List<String>{ 'a', 'b' }));
        System.assertEquals(3, BusinessHealthData.sumLast(num, new List<String>{ 'a', 'b' }, 1));
        System.assertEquals(20.0, BusinessHealthData.attritionPct(2, 9));
    }

    @IsTest
    static void opportunityClassification() {
        Opportunity sourced = new Opportunity(LeadSource = 'Referral - Salesforce');
        Opportunity influenced = new Opportunity(LeadSource = 'Sales', Salesforce_ACV__c = 5000);
        Opportunity own = new Opportunity(LeadSource = 'Website', Type = 'Existing Cust - New Project', Cloud_s_Included__c = 'Sales;Service');
        System.assertEquals('Sourced by Salesforce', BusinessHealthData.sourcing(sourced));
        System.assertEquals('Salesforce AE involved', BusinessHealthData.sourcing(influenced));
        System.assertEquals('Own team', BusinessHealthData.sourcing(own));
        System.assert(BusinessHealthData.isExistingCustomer(own));
        System.assertEquals(new List<String>{ 'Sales', 'Service' }, BusinessHealthData.serviceLines(own));
        System.assertEquals(new List<String>{ 'Unspecified' }, BusinessHealthData.serviceLines(sourced));
        System.assertEquals(40, BusinessHealthData.weeklyGoal(new Contact(DCS_Billable_Goal__c = 2080)), 'annual goals are converted to weekly');
        System.assertEquals(38, BusinessHealthData.weeklyGoal(new Contact(DCS_Billable_Goal__c = 38)));
    }

    @IsTest
    static void marketingChannelsAndSourcing() {
        System.assertEquals('Inbound marketing', BusinessHealthMarketingPage.channel('Website'));
        System.assertEquals('Outbound & lists', BusinessHealthMarketingPage.channel('Zoominfo'));
        System.assertEquals('Sales team', BusinessHealthMarketingPage.channel('Sales'));
        System.assertEquals('Salesforce referral', BusinessHealthMarketingPage.channel('Referral - Salesforce'));
        System.assertEquals('Other referrals', BusinessHealthMarketingPage.channel('Referral - Client'));
        System.assertEquals('Existing clients', BusinessHealthMarketingPage.channel('Repeat Purchase'));
        System.assertEquals('Not recorded', BusinessHealthMarketingPage.channel(null));
        System.assert(BusinessHealthMarketingPage.isMarketingSourced(new Opportunity(LeadSource = 'Event')));
        System.assert(!BusinessHealthMarketingPage.isMarketingSourced(new Opportunity(LeadSource = 'Sales')));
    }

    @IsTest
    static void marketingPageCountsLeadsAndCampaigns() {
        Test.setMock(HttpCalloutMock.class, new NoOpCalloutMock());
        insert new List<Lead>{
            new Lead(LastName = 'One', Company = 'Acme', LeadSource = 'Website', Status = 'Open'),
            new Lead(LastName = 'Two', Company = 'Beta', Status = 'Open')
        };
        insert new Campaign(Name = 'Test Webinar', Type = 'Webinar', StartDate = Date.today().addDays(-10), IsActive = true);
        BusinessHealthModel.HealthPage page = BusinessHealthController.getPage('marketing', Date.today(), null);
        Map<String, BusinessHealthModel.Kpi> byKey = new Map<String, BusinessHealthModel.Kpi>();
        for (BusinessHealthModel.Kpi k : page.kpis) {
            byKey.put(k.key, k);
        }
        System.assertEquals(2, byKey.get('newLeads').value);
        System.assertEquals(50.0, byKey.get('leadsNoSource').value);
        System.assertEquals(100.0, byKey.get('untouchedLeads').value);
        System.assert(byKey.get('costPerOpp').unavailable, 'no campaign costs recorded');
    }

    @IsTest
    static void advisorReturnsAiAdviceAndCachesIt() {
        Test.setMock(HttpCalloutMock.class, new NoOpCalloutMock());
        StubLlm stub = new StubLlm(GOOD_JSON);
        BusinessHealthAdvisor.llm = stub;
        BusinessHealthContext.settingsOverride = new Business_Health_Setting__mdt(AI_Enabled__c = true, AI_Cache_Hours__c = 12);

        Test.startTest();
        BusinessHealthAdvisor.Advice first = BusinessHealthAdvisor.getAdvice('sales', Date.today(), null, false);
        BusinessHealthAdvisor.Advice second = BusinessHealthAdvisor.getAdvice('sales', Date.today(), null, false);
        BusinessHealthAdvisor.Advice forced = BusinessHealthAdvisor.getAdvice('sales', Date.today(), null, true);
        Test.stopTest();

        System.assert(first.aiGenerated);
        System.assertEquals('Pipeline is thin.', first.headline);
        System.assertEquals(1, first.recommendations.size());
        System.assertEquals('Plan accounts', first.recommendations[0].action);
        System.assertNotEquals(null, first.insightId, 'advice is stored');
        System.assert(second.fromCache, 'same view reuses the stored insight');
        System.assertEquals('Pipeline is thin.', second.headline);
        System.assert(!forced.fromCache);
        System.assertEquals(2, stub.calls, 'cached call skipped the model; forced refresh called it');
        Business_Health_Insight__c row = [SELECT Page__c, Scope__c, Metrics_Snapshot__c FROM Business_Health_Insight__c LIMIT 1];
        System.assertEquals('sales', row.Page__c);
        System.assertEquals('ALL', row.Scope__c);
        System.assert(row.Metrics_Snapshot__c.contains('KPIS:'));
    }

    @IsTest
    static void advisorFallsBackToRulesWhenTheModelFails() {
        StubLlm stub = new StubLlm(GOOD_JSON);
        stub.fail = true;
        BusinessHealthAdvisor.llm = stub;
        BusinessHealthContext.settingsOverride = new Business_Health_Setting__mdt(AI_Enabled__c = true);
        BusinessHealthAdvisor.Advice a = BusinessHealthAdvisor.getAdvice('leadership', Date.today(), null, true);
        System.assert(!a.aiGenerated);
        System.assert(a.notice.contains('Model offline'), a.notice);
        System.assertNotEquals(null, a.headline);
        System.assertEquals(0, [SELECT COUNT() FROM Business_Health_Insight__c], 'fallback advice is not cached');
    }

    @IsTest
    static void advisorUsesRulesWhenAiIsDisabled() {
        StubLlm stub = new StubLlm(GOOD_JSON);
        BusinessHealthAdvisor.llm = stub;
        BusinessHealthContext.settingsOverride = new Business_Health_Setting__mdt(AI_Enabled__c = false);
        BusinessHealthAdvisor.Advice a = BusinessHealthAdvisor.getAdvice('delivery', Date.today(), null, false);
        System.assert(!a.aiGenerated);
        System.assert(a.notice.contains('turned off'));
        System.assertEquals(0, stub.calls);
    }

    @IsTest
    static void parserRejectsNonJsonAndRulesUsePlaybook() {
        try {
            BusinessHealthAdvisor.parse('Sorry, I cannot help.');
            System.assert(false, 'expected an error');
        } catch (BusinessHealthAdvisor.AdvisorException e) {
            System.assert(e.getMessage().contains('JSON'));
        }
        BusinessHealthModel.HealthPage page = new BusinessHealthModel.HealthPage('leadership', 'T', 'S', 'A');
        page.addKpi(new BusinessHealthModel.Kpi('bookToBill', 'Book-to-bill', 0.5, 'ratio')).target(1.1, 'higher', 0.1);
        page.addKpi(new BusinessHealthModel.Kpi('custom', 'Custom', 5, 'number')).target(10, 'higher', 0.6);
        page.dataGaps.add('Gap');
        page.asOfDate = Date.today();
        page.scopeLabel = 'All practices';
        BusinessHealthAdvisor.Advice a = BusinessHealthAdvisor.ruleBased(page);
        System.assertEquals(2, a.recommendations.size());
        System.assertEquals('Rebuild bookings momentum', a.recommendations[0].title, 'bad KPIs come first and use the playbook');
        System.assertEquals('Address Custom', a.recommendations[1].title);
        System.assertEquals(new List<String>{ 'Gap' }, a.dataFixes);
        String prompt = BusinessHealthAdvisor.buildPrompt(page, BusinessHealthAdvisor.snapshot(page));
        System.assert(prompt.contains('Book-to-bill: 0.5x'), prompt);
        System.assert(prompt.contains('Never recommend'));
    }
}
