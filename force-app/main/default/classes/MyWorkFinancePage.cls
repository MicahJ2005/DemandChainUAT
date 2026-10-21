/**
 * @group BusinessHealth
 *
 * @description My Work - Finance: the firm-wide operational view for the finance team,
 * focused on turning delivered work into cash - unbilled WIP and how old it is, timecards
 * and expenses waiting on approval, late timecards, billed-not-invoiced, invoicing this
 * month, collections, and projects close to their budget cap. Firm-wide, so only granted
 * to finance (My_Work_Finance); data still follows the user's own record access.
 */
public with sharing class MyWorkFinancePage implements BusinessHealthPageBuilder {
    private static final Decimal BUDGET_CAP_SHARE = 0.9;
    private static final Integer LATE_DAYS = 7;

    public BusinessHealthModel.HealthPage build(BusinessHealthContext ctx) {
        BusinessHealthModel.HealthPage page = new BusinessHealthModel.HealthPage(
            'my-finance',
            'Billing & cash operations',
            'What is delivered but not yet billed, what is stuck waiting on someone, and what is due in?',
            'Finance'
        );
        Business_Health_Goal_Set__c s = ctx.goals;
        Date asOf = ctx.asOfDate;
        List<String> keys12 = ctx.completeMonthKeys(12);
        List<String> labels12 = ctx.completeMonthLabels(12);
        List<BusinessHealthData.TimecardFact> tcs = BusinessHealthData.timecards(ctx, ctx.windowStart(12));
        List<BusinessHealthData.MilestoneFact> ms = BusinessHealthData.milestoneRevenue(ctx, ctx.windowStart(12));
        Map<String, Decimal> delivered = BusinessHealthData.deliveredByMonth(tcs, ms);
        Map<String, Decimal> billed = BusinessHealthData.billedByMonth(ctx, ctx.windowStart(12));

        // ---- unbilled WIP and its age -------------------------------------------------------
        List<String> buckets = new List<String>{ '0-30 days', '31-60 days', '61-90 days', 'Over 90 days' };
        Map<String, Decimal> byAge = new Map<String, Decimal>();
        Map<Id, Decimal> wipByProject = new Map<Id, Decimal>();
        Map<Id, Date> oldestByProject = new Map<Id, Date>();
        Map<Id, String> projectNames = new Map<Id, String>();
        Decimal wipTotal = 0;
        Decimal wipOver30 = 0;
        for (BusinessHealthData.TimecardFact f : tcs) {
            if (!f.unbilled) {
                continue;
            }
            Integer age = f.endDate.daysBetween(asOf);
            String bucket = age <= 30 ? buckets[0] : age <= 60 ? buckets[1] : age <= 90 ? buckets[2] : buckets[3];
            BusinessHealthData.add(byAge, bucket, f.revenue);
            wipTotal += f.revenue;
            if (age > 30) {
                wipOver30 += f.revenue;
            }
            BusinessHealthData.add(wipByProject, f.projectId, f.revenue);
            projectNames.put(f.projectId, f.projectName);
            if (!oldestByProject.containsKey(f.projectId) || f.endDate < oldestByProject.get(f.projectId)) {
                oldestByProject.put(f.projectId, f.endDate);
            }
        }
        Map<Id, pse__Proj__c> wipProjects = new Map<Id, pse__Proj__c>([
            SELECT Id, pse__Account__r.Name, pse__Project_Manager__r.Name
            FROM pse__Proj__c
            WHERE Id IN :wipByProject.keySet()
            WITH USER_MODE
        ]);
        BusinessHealthModel.Table wipTable = new BusinessHealthModel.Table('wipByProject', 'Unbilled WIP by project',
            'Approved billable time not yet billed, largest first. Over 90 days usually means billed outside PSA or never billed.')
            .link('name', 'Project', 'id')
            .col('account', 'Account', 'text')
            .col('pm', 'PM', 'text')
            .col('unbilled', 'Unbilled', 'currency')
            .col('oldest', 'Oldest week ending', 'date')
            .col('age', 'Oldest (days)', 'number');
        for (Id pid : wipByProject.keySet()) {
            pse__Proj__c p = wipProjects.get(pid);
            wipTable.rows.add(new Map<String, Object>{ 'id' => pid, 'name' => projectNames.get(pid),
                'account' => p == null || p.pse__Account__r == null ? null : p.pse__Account__r.Name,
                'pm' => p == null || p.pse__Project_Manager__r == null ? null : p.pse__Project_Manager__r.Name,
                'unbilled' => wipByProject.get(pid).setScale(0), 'oldest' => oldestByProject.get(pid),
                'age' => oldestByProject.get(pid).daysBetween(asOf) });
        }
        BusinessHealthModel.sortRows(wipTable.rows, 'unbilled');
        wipTable.rows = BusinessHealthModel.first(wipTable.rows, 30);
        wipTable.metric = 'unbilledWip';

        // ---- approvals and late timecards -------------------------------------------------------
        BusinessHealthModel.Table approvals = new BusinessHealthModel.Table('approvalsByPm', 'Timecards waiting on approval, by project manager',
            'Submitted but not approved. Unapproved time cannot be billed.')
            .col('pm', 'Project manager', 'text')
            .col('cards', 'Timecards', 'number')
            .col('hours', 'Hours', 'hours')
            .col('amount', 'Billable value', 'currency')
            .col('oldest', 'Oldest week ending', 'date');
        Integer submittedCards = 0;
        Decimal submittedValue = 0;
        for (AggregateResult ar : [
            SELECT pse__Project__r.pse__Project_Manager__r.Name pm, COUNT(Id) cards, SUM(pse__Total_Hours__c) hrs,
                SUM(pse__Total_Billable_Amount__c) amt, MIN(pse__End_Date__c) oldest
            FROM pse__Timecard_Header__c
            WHERE pse__Status__c = 'Submitted' AND pse__End_Date__c <= :asOf
            WITH USER_MODE
            GROUP BY pse__Project__r.pse__Project_Manager__r.Name
        ]) {
            submittedCards += (Integer) ar.get('cards');
            submittedValue += BusinessHealthData.nz((Decimal) ar.get('amt'));
            approvals.rows.add(new Map<String, Object>{ 'pm' => ar.get('pm') == null ? '(no PM)' : ar.get('pm'), 'cards' => ar.get('cards'),
                'hours' => ar.get('hrs'), 'amount' => ar.get('amt'), 'oldest' => ar.get('oldest') });
        }
        BusinessHealthModel.sortRows(approvals.rows, 'amount');
        approvals.metric = 'awaitingApproval';

        Date lateCutoff = asOf.addDays(-LATE_DAYS);
        Date lateFloor = ctx.windowStart(3);
        BusinessHealthModel.Table late = new BusinessHealthModel.Table('lateTimecards', 'Late timecards, by person',
            'Timecards still in Saved status more than ' + LATE_DAYS + ' days after the week ended.')
            .col('resource', 'Resource', 'text')
            .col('cards', 'Timecards', 'number')
            .col('hours', 'Hours', 'hours')
            .col('oldest', 'Oldest week ending', 'date');
        Integer lateCards = 0;
        for (AggregateResult ar : [
            SELECT pse__Resource__r.Name res, COUNT(Id) cards, SUM(pse__Total_Hours__c) hrs, MIN(pse__End_Date__c) oldest
            FROM pse__Timecard_Header__c
            WHERE pse__Status__c = 'Saved' AND pse__End_Date__c <= :lateCutoff AND pse__End_Date__c > :lateFloor
            WITH USER_MODE
            GROUP BY pse__Resource__r.Name
        ]) {
            lateCards += (Integer) ar.get('cards');
            late.rows.add(new Map<String, Object>{ 'resource' => ar.get('res'), 'cards' => ar.get('cards'), 'hours' => ar.get('hrs'), 'oldest' => ar.get('oldest') });
        }
        BusinessHealthModel.sortRows(late.rows, 'cards');
        late.metric = 'lateTimecards';

        // ---- billing, invoicing, collections, expenses ----------------------------------------------
        Date monthStart = asOf.toStartOfMonth();
        Decimal billedNotInvoiced = 0;
        Decimal invoicedThisMonth = 0;
        Integer billingEvents = 0;
        for (AggregateResult ar : [
            SELECT pse__Invoiced__c inv, COUNT(Id) c, SUM(pse__Summary_Amount__c) amt
            FROM pse__Billing_Event__c
            WHERE pse__Is_Released__c = true AND pse__Date__c <= :asOf
            WITH USER_MODE
            GROUP BY pse__Invoiced__c
        ]) {
            billingEvents += (Integer) ar.get('c');
            if (!(Boolean) ar.get('inv')) {
                billedNotInvoiced += BusinessHealthData.nz((Decimal) ar.get('amt'));
            }
        }
        for (AggregateResult ar : [
            SELECT SUM(pse__Summary_Amount__c) amt
            FROM pse__Billing_Event__c
            WHERE pse__Invoiced__c = true AND pse__Invoice_Date__c >= :monthStart AND pse__Invoice_Date__c <= :asOf
            WITH USER_MODE
        ]) {
            invoicedThisMonth += BusinessHealthData.nz((Decimal) ar.get('amt'));
        }
        List<AggregateResult> collections = [
            SELECT SUM(CollectionAmount__c) amt, COUNT(Id) c
            FROM Account_Collection__c
            WHERE Status__c = 'In Collections'
            WITH USER_MODE
        ];
        Decimal inCollections = collections.isEmpty() ? 0 : BusinessHealthData.nz((Decimal) collections[0].get('amt'));
        List<AggregateResult> expenses = [
            SELECT SUM(pse__Amount__c) amt, COUNT(Id) c
            FROM pse__Expense__c
            WHERE pse__Status__c = 'Submitted'
            WITH USER_MODE
        ];
        Decimal expensesPending = expenses.isEmpty() ? 0 : BusinessHealthData.nz((Decimal) expenses[0].get('amt'));
        Integer expenseCount = expenses.isEmpty() ? 0 : (Integer) expenses[0].get('c');

        // ---- projects near their budget cap -----------------------------------------------------------
        BusinessHealthModel.Table nearCap = new BusinessHealthModel.Table('nearBudgetCap', 'Projects near their budget cap',
            'Active client projects that have billed ' + (BUDGET_CAP_SHARE * 100).setScale(0) + '% or more of their bookings. Needs a change order or a close-out plan.')
            .link('name', 'Project', 'id')
            .col('account', 'Account', 'text')
            .col('pm', 'PM', 'text')
            .col('budget', 'Bookings', 'currency')
            .col('billed', 'Billed', 'currency')
            .col('usedPct', 'Billed %', 'percent')
            .col('eac', 'EAC', 'currency');
        for (pse__Proj__c p : BusinessHealthData.activeClientProjects(ctx)) {
            Decimal budget = BusinessHealthData.nz(p.pse__Bookings__c);
            Decimal billedAmt = BusinessHealthData.nz(p.pse__Billings__c);
            if (budget > 0 && billedAmt >= budget * BUDGET_CAP_SHARE) {
                nearCap.rows.add(new Map<String, Object>{ 'id' => p.Id, 'name' => p.Name,
                    'account' => p.pse__Account__r == null ? null : p.pse__Account__r.Name,
                    'pm' => p.pse__Project_Manager__r == null ? null : p.pse__Project_Manager__r.Name,
                    'budget' => budget, 'billed' => billedAmt, 'usedPct' => BusinessHealthModel.pct(billedAmt, budget), 'eac' => p.Estimate_at_Complete__c });
            }
        }
        BusinessHealthModel.sortRows(nearCap.rows, 'usedPct');
        nearCap.metric = 'nearBudgetCap';

        // ---- revenue this month vs target pace -----------------------------------------------------------
        Decimal deliveredMtd = 0;
        for (BusinessHealthData.TimecardFact f : tcs) {
            if (f.endDate >= monthStart && f.endDate <= asOf) {
                deliveredMtd += f.revenue;
            }
        }
        for (BusinessHealthData.MilestoneFact m : ms) {
            if (m.actualDate >= monthStart && m.actualDate <= asOf) {
                deliveredMtd += m.amount;
            }
        }
        Decimal delivered12 = BusinessHealthData.sumLast(delivered, keys12, 12);
        Decimal annualTarget = s.Annual_Revenue_Target__c != null && s.Annual_Revenue_Target__c > 0
            ? s.Annual_Revenue_Target__c
            : delivered12 * (1 + ctx.num(s.Revenue_Growth_Target__c, 15) / 100);
        Decimal monthPace = annualTarget / 12 * asOf.day() / Date.daysInMonth(asOf.year(), asOf.month());

        // ---- KPIs ------------------------------------------------------------------------------------------
        Decimal delivered3 = BusinessHealthData.sumLast(delivered, keys12, 3);
        Decimal wipDays = BusinessHealthModel.ratio(wipTotal, delivered3 / 91);
        page.addKpi(new BusinessHealthModel.Kpi('revenueMtd', 'Delivered revenue, month to date', deliveredMtd, 'currency'))
            .target(monthPace.setScale(0), 'higher', 0.15)
            .note('Target is the annual revenue target pro-rated to today (' + BusinessHealthModel.formatValue(annualTarget, 'currency') + ' a year). Timecards for this week may not be in yet.');
        page.addKpi(new BusinessHealthModel.Kpi('unbilledWip', 'Unbilled WIP', wipTotal, 'currency'))
            .target(ctx.num(s.Unbilled_WIP_Days_Target__c, 10) * delivered3 / 91, 'lower', 0.5)
            .note((wipDays == null ? '' : wipDays.setScale(0) + ' days of revenue. ') + 'All approved billable time not yet billed, last 12 months.');
        page.addKpi(new BusinessHealthModel.Kpi('wipOver30', 'Unbilled WIP over 30 days', wipOver30, 'currency'))
            .target(0, 'lower', 0)
            .note('Approved time more than 30 days old that still has not been billed.');
        page.addKpi(new BusinessHealthModel.Kpi('awaitingApproval', 'Timecards awaiting approval', submittedCards, 'number'))
            .target(0, 'lower', 0)
            .note(BusinessHealthModel.formatValue(submittedValue, 'currency') + ' of billable time waiting on project managers.');
        page.addKpi(new BusinessHealthModel.Kpi('lateTimecards', 'Late timecards', lateCards, 'number'))
            .target(0, 'lower', 0)
            .note('Saved, not submitted, more than ' + LATE_DAYS + ' days after the week ended (last 3 months).');
        BusinessHealthModel.Kpi bni = page.addKpi(new BusinessHealthModel.Kpi('billedNotInvoiced', 'Billed, not invoiced', billedNotInvoiced, 'currency'));
        BusinessHealthModel.Kpi invoiced = page.addKpi(new BusinessHealthModel.Kpi('invoicedMtd', 'Invoiced this month', invoicedThisMonth, 'currency'));
        if (billingEvents == 0) {
            bni.markUnavailable('No billing events exist in this org copy.');
            invoiced.markUnavailable('No billing events exist in this org copy.');
            page.dataGaps.add('There are no PSA billing events in this org copy, so billed-not-invoiced and invoicing are not measured. Production has them.');
        } else {
            bni.target(0, 'lower', 0).note('Released billing events with no invoice yet.');
            invoiced.note('Billing events invoiced since ' + monthStart.format() + '.');
        }
        page.addKpi(new BusinessHealthModel.Kpi('expensesPending', 'Expenses awaiting approval', expensesPending, 'currency'))
            .note(expenseCount + ' submitted expense lines.');
        page.addKpi(new BusinessHealthModel.Kpi('inCollections', 'AR in collections', inCollections, 'currency'))
            .note('Account Collection records with status In Collections.');
        page.addKpi(new BusinessHealthModel.Kpi('nearBudgetCap', 'Projects near budget cap', nearCap.rows.size(), 'number'))
            .note('Active client projects that have billed ' + (BUDGET_CAP_SHARE * 100).setScale(0) + '%+ of bookings.');
        page.addKpi(new BusinessHealthModel.Kpi('dso', 'DSO', null, 'days'))
            .markUnavailable('Needs invoice payment dates from the accounting system (for example QuickBooks).');

        // ---- charts --------------------------------------------------------------------------------------
        page.charts.add(
            new BusinessHealthModel.Chart('deliveredVsBilled', 'Delivered vs billed revenue', 'bar', 'currency')
                .labels(labels12)
                .addSeries('Delivered', BusinessHealthData.series(delivered, keys12))
                .addSeries('Billed', BusinessHealthData.series(billed, keys12))
                .metric('unbilledWip')
        );
        List<Decimal> ages = new List<Decimal>();
        for (String b : buckets) {
            ages.add(BusinessHealthData.nz(byAge.get(b)).setScale(0));
        }
        page.charts.add(
            new BusinessHealthModel.Chart('wipAging', 'Unbilled WIP by age', 'bar', 'currency')
                .labels(buckets)
                .addSeries('Unbilled', ages)
                .metric('wipOver30')
        );

        page.tables.add(wipTable);
        page.tables.add(approvals);
        page.tables.add(late);
        page.tables.add(nearCap);

        page.signalMissedKpis();
        page.dataGaps.add('DSO and AR aging need payment dates from the accounting system.');
        page.briefMetrics = new List<String>{ 'unbilledWip', 'wipOver30', 'awaitingApproval', 'lateTimecards' };
        return page;
    }
}
