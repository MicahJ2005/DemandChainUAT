/**
 * @group BusinessHealth
 *
 * @description My Work - Project Manager: the active projects where the running user's
 * PSA resource is Project Manager - budget vs estimate at completion, status, timecards
 * waiting on their approval, unbilled time, stale status reports, projects ending soon,
 * open staffing requests, overdue milestones and labor margin.
 */
public with sharing class MyWorkProjectManagerPage implements BusinessHealthPageBuilder {
    private static final Set<String> ACTIVE_STAGES = new Set<String>{ 'Planning', 'In Progress', 'On Hold', 'Wrapping_Up' };
    private static final Set<String> NO_REPORT_FREQUENCIES = new Set<String>{ 'Do Not Send', 'On Hold', 'As Needed' };
    private static final Set<String> OPEN_REQUEST_STATUSES = new Set<String>{ 'Draft', 'Ready to Staff', 'Hold', 'Tentative' };
    private static final Integer STATUS_REPORT_DAYS = 14;
    private static final Integer ENDING_DAYS = 30;
    private static final Integer HOURS_WEEKS = 12;

    public BusinessHealthModel.HealthPage build(BusinessHealthContext ctx) {
        BusinessHealthModel.HealthPage page = new BusinessHealthModel.HealthPage(
            'my-pm',
            'My projects',
            'Which of my projects need me this week: budget, approvals, status and staffing?',
            'Project Manager'
        );
        Contact me = MyWorkSupport.resourceFor(ctx.userId);
        if (me == null) {
            MyWorkSupport.noResource(page);
            return page;
        }
        Date asOf = ctx.asOfDate;
        Business_Health_Goal_Set__c s = ctx.goals;

        Map<Id, pse__Proj__c> projects = new Map<Id, pse__Proj__c>([
            SELECT Id, Name, pse__Account__r.Name, pse__Stage__c, pse__Billing_Type__c, pse__Project_Status__c, pse__Financial_Status__c,
                pse__Schedule_Status__c, pse__Bookings__c, pse__Billings__c, Estimate_at_Complete__c, pse__Planned_Hours__c,
                Billable_Hours_Total__c, pse__Non_Billable_Internal_Hours__c, pse__Non_Billable_External_Hours__c, pse__End_Date__c,
                Status_Report_Week_Ending__c, Status_Report_Frequency__c, CSAT_Status__c, pse__Opportunity__c
            FROM pse__Proj__c
            WHERE pse__Project_Manager__c = :me.Id AND pse__Is_Active__c = true AND pse__Stage__c IN :ACTIVE_STAGES
            WITH USER_MODE
        ]);
        if (projects.isEmpty()) {
            page.addKpi(new BusinessHealthModel.Kpi('activeProjects', 'Active projects', 0, 'number'))
                .note('You are not Project Manager on any active project.');
            return page;
        }
        Set<Id> projectIds = projects.keySet();

        // ---- budget, EAC, status ------------------------------------------------------
        Decimal totalBudget = 0;
        Decimal overrun = 0;
        Integer offTrack = 0;
        Integer staleReports = 0;
        Integer endingSoon = 0;
        Decimal logged = 0;
        Decimal planned = 0;
        Date reportCutoff = asOf.addDays(-STATUS_REPORT_DAYS);
        BusinessHealthModel.Table projectTable = new BusinessHealthModel.Table('myProjects', 'My active projects',
            'Largest forecast overrun first. Variance = budget (bookings) - estimate at completion (billed + scheduled).')
            .link('name', 'Project', 'id')
            .col('account', 'Account', 'text')
            .col('stage', 'Stage', 'text')
            .col('status', 'Status', 'status')
            .col('budget', 'Budget', 'currency')
            .col('eac', 'EAC', 'currency')
            .col('variance', 'Variance', 'currency')
            .col('burned', 'Hours burned', 'percent')
            .col('endDate', 'End', 'date')
            .col('lastReport', 'Last status report', 'date')
            .col('flag', 'Flag', 'text');
        List<String> chartNames = new List<String>();
        List<Decimal> chartBudget = new List<Decimal>();
        List<Decimal> chartEac = new List<Decimal>();
        for (pse__Proj__c p : projects.values()) {
            Decimal budget = BusinessHealthData.nz(p.pse__Bookings__c);
            Decimal eac = BusinessHealthData.nz(p.Estimate_at_Complete__c);
            Decimal variance = budget - eac;
            totalBudget += budget;
            if (budget > 0 && variance < 0) {
                overrun -= variance;
            }
            List<String> flags = new List<String>();
            if (p.pse__Project_Status__c == 'Red' || p.pse__Project_Status__c == 'Yellow') {
                offTrack++;
                flags.add(p.pse__Project_Status__c + ' status');
            }
            Boolean needsReport = p.pse__Stage__c == 'In Progress' && !NO_REPORT_FREQUENCIES.contains(p.Status_Report_Frequency__c);
            if (needsReport && (p.Status_Report_Week_Ending__c == null || p.Status_Report_Week_Ending__c < reportCutoff)) {
                staleReports++;
                flags.add('Status report overdue');
            }
            if (p.pse__End_Date__c != null && p.pse__End_Date__c >= asOf && p.pse__End_Date__c <= asOf.addDays(ENDING_DAYS)) {
                endingSoon++;
                flags.add('Ends in ' + asOf.daysBetween(p.pse__End_Date__c) + 'd' + (p.pse__Opportunity__c != null && p.CSAT_Status__c == null ? ', CSAT not started' : ''));
            }
            if (budget > 0 && variance < 0) {
                flags.add('Over budget');
            }
            logged += BusinessHealthData.nz(p.Billable_Hours_Total__c) + BusinessHealthData.nz(p.pse__Non_Billable_Internal_Hours__c) +
                BusinessHealthData.nz(p.pse__Non_Billable_External_Hours__c);
            planned += BusinessHealthData.nz(p.pse__Planned_Hours__c);
            projectTable.rows.add(
                new Map<String, Object>{
                    'id' => p.Id,
                    'name' => p.Name,
                    'account' => p.pse__Account__r == null ? null : p.pse__Account__r.Name,
                    'stage' => p.pse__Stage__c == null ? null : p.pse__Stage__c.replace('_', ' '),
                    'status' => ragStatus(p.pse__Project_Status__c),
                    'budget' => budget,
                    'eac' => eac,
                    'variance' => variance,
                    'burned' => BusinessHealthData.hoursBurnedPct(p),
                    'endDate' => p.pse__End_Date__c,
                    'lastReport' => p.Status_Report_Week_Ending__c,
                    'flag' => String.join(flags, ' · ')
                }
            );
        }
        BusinessHealthModel.sortRowsAscending(projectTable.rows, 'variance');
        for (Integer i = 0; i < Math.min(10, projectTable.rows.size()); i++) {
            Map<String, Object> r = projectTable.rows[i];
            if (((Decimal) r.get('budget')) > 0) {
                chartNames.add(((String) r.get('name')).abbreviate(34));
                chartBudget.add(((Decimal) r.get('budget')).setScale(0));
                chartEac.add(((Decimal) r.get('eac')).setScale(0));
            }
        }
        projectTable.metric = 'eacOverrun';

        // ---- timecards on my projects -------------------------------------------------
        Date hoursFrom = MyWorkSupport.lastCompleteWeekStart(asOf).addDays(-7 * (HOURS_WEEKS - 1));
        Date wipCutoff = asOf.addDays(-BusinessHealthData.WIP_WINDOW_DAYS);
        Map<Date, Decimal> billableByWeek = new Map<Date, Decimal>();
        Map<Date, Decimal> nonBillableByWeek = new Map<Date, Decimal>();
        Decimal unbilled = 0;
        Decimal revenue = 0;
        Decimal cost = 0;
        for (pse__Timecard_Header__c tc : [
            SELECT pse__End_Date__c, pse__Total_Hours__c, pse__Billable__c, pse__Billed__c, pse__Status__c, pse__Total_Billable_Amount__c,
                pse__Cost_Rate_Amount__c, pse__Resource__r.pse__Default_Cost_Rate__c, pse__Project__r.pse__Billing_Type__c,
                pse__Project__r.pse__Opportunity__c, pse__Project__r.pse__Is_Billable__c
            FROM pse__Timecard_Header__c
            WHERE pse__Project__c IN :projectIds AND pse__End_Date__c >= :hoursFrom AND pse__End_Date__c <= :asOf
                AND pse__Status__c IN ('Approved', 'Submitted')
            WITH USER_MODE
        ]) {
            Decimal h = BusinessHealthData.nz(tc.pse__Total_Hours__c);
            Date wk = tc.pse__End_Date__c.toStartOfWeek();
            Map<Date, Decimal> bucket = tc.pse__Billable__c ? billableByWeek : nonBillableByWeek;
            bucket.put(wk, BusinessHealthData.nz(bucket.get(wk)) + h);
            // Margin covers client T&M projects only; internal projects earn no revenue by design.
            Boolean client = tc.pse__Project__r.pse__Opportunity__c != null && tc.pse__Project__r.pse__Is_Billable__c;
            Boolean tm = client && tc.pse__Project__r.pse__Billing_Type__c != 'Fixed Price';
            Decimal amount = tc.pse__Billable__c && tm ? BusinessHealthData.nz(tc.pse__Total_Billable_Amount__c) : 0;
            Decimal rate = tc.pse__Cost_Rate_Amount__c != null && tc.pse__Cost_Rate_Amount__c > 0
                ? tc.pse__Cost_Rate_Amount__c
                : (tc.pse__Resource__r == null ? 0 : BusinessHealthData.nz(tc.pse__Resource__r.pse__Default_Cost_Rate__c));
            if (tm) {
                revenue += amount;
                cost += h * rate;
            }
            if (tc.pse__Billable__c && !tc.pse__Billed__c && tc.pse__Status__c == 'Approved' && amount > 0 && tc.pse__End_Date__c > wipCutoff) {
                unbilled += amount;
            }
        }

        BusinessHealthModel.Table approvals = new BusinessHealthModel.Table('toApprove', 'Timecards waiting on approval',
            'Submitted timecards on your projects. Approved time is what gets billed.')
            .col('resource', 'Resource', 'text')
            .link('project', 'Project', 'projectId')
            .col('weekEnding', 'Week ending', 'date')
            .col('hours', 'Hours', 'hours')
            .col('billable', 'Billable', 'text');
        Decimal approvalHours = 0;
        for (pse__Timecard_Header__c tc : [
            SELECT pse__Resource__r.Name, pse__Project__c, pse__Project__r.Name, pse__End_Date__c, pse__Total_Hours__c, pse__Billable__c
            FROM pse__Timecard_Header__c
            WHERE pse__Project__c IN :projectIds AND pse__Status__c = 'Submitted'
            WITH USER_MODE
            ORDER BY pse__End_Date__c
            LIMIT 200
        ]) {
            approvalHours += BusinessHealthData.nz(tc.pse__Total_Hours__c);
            approvals.rows.add(new Map<String, Object>{ 'resource' => tc.pse__Resource__r.Name, 'projectId' => tc.pse__Project__c,
                'project' => tc.pse__Project__r.Name, 'weekEnding' => tc.pse__End_Date__c, 'hours' => tc.pse__Total_Hours__c,
                'billable' => tc.pse__Billable__c ? 'Yes' : 'No' });
        }
        approvals.metric = 'toApprove';

        // ---- staffing requests and milestones -----------------------------------------------
        BusinessHealthModel.Table requests = new BusinessHealthModel.Table('openRequests', 'Open staffing requests on my projects', null)
            .link('name', 'Request', 'id')
            .col('project', 'Project', 'text')
            .col('role', 'Role', 'text')
            .col('start', 'Start', 'date')
            .col('hours', 'Hours', 'hours')
            .col('status', 'Status', 'text');
        for (pse__Resource_Request__c r : [
            SELECT Id, Name, pse__Resource_Request_Name__c, pse__Project__r.Name, pse__Resource_Role__c, pse__Start_Date__c, pse__SOW_Hours__c, pse__Status__c
            FROM pse__Resource_Request__c
            WHERE pse__Project__c IN :projectIds AND pse__Status__c IN :OPEN_REQUEST_STATUSES
            WITH USER_MODE
            ORDER BY pse__Start_Date__c
            LIMIT 50
        ]) {
            requests.rows.add(new Map<String, Object>{ 'id' => r.Id, 'name' => String.isBlank(r.pse__Resource_Request_Name__c) ? r.Name : r.pse__Resource_Request_Name__c,
                'project' => r.pse__Project__r.Name, 'role' => r.pse__Resource_Role__c, 'start' => r.pse__Start_Date__c, 'hours' => r.pse__SOW_Hours__c,
                'status' => r.pse__Status__c });
        }
        List<pse__Milestone__c> overdueMilestones = [
            SELECT Id, Name, pse__Project__r.Name, pse__Target_Date__c, pse__Milestone_Amount__c
            FROM pse__Milestone__c
            WHERE pse__Project__c IN :projectIds AND pse__Status__c IN ('Open', 'Planned') AND pse__Target_Date__c < :asOf
            WITH USER_MODE
            ORDER BY pse__Target_Date__c
            LIMIT 50
        ];

        // ---- KPIs -------------------------------------------------------------------------
        page.addKpi(new BusinessHealthModel.Kpi('activeProjects', 'Active projects', projects.size(), 'number'))
            .note(BusinessHealthModel.formatValue(totalBudget, 'currency') + ' total budget; ' + endingSoon + ' ending in the next ' + ENDING_DAYS + ' days.');
        page.addKpi(new BusinessHealthModel.Kpi('eacOverrun', 'Forecast overrun', overrun, 'currency'))
            .target((totalBudget * ctx.num(s.EAC_Overrun_Threshold__c, 2) / 100).setScale(0), 'lower', 0.5)
            .note('Sum of estimate at completion above budget across your projects.');
        page.addKpi(new BusinessHealthModel.Kpi('offTrack', 'Projects red or yellow', offTrack, 'number'))
            .target(0, 'lower', 0)
            .note('Overall project status set by you.');
        page.addKpi(new BusinessHealthModel.Kpi('toApprove', 'Timecards to approve', approvals.rows.size(), 'number'))
            .target(0, 'lower', 0)
            .note(approvalHours.setScale(0) + ' hours submitted and waiting on approval.');
        page.addKpi(new BusinessHealthModel.Kpi('staleReports', 'Status reports overdue', staleReports, 'number'))
            .target(0, 'lower', 0)
            .note('In-progress projects with no status report week-ending in the last ' + STATUS_REPORT_DAYS + ' days.');
        page.addKpi(new BusinessHealthModel.Kpi('unbilled', 'Unbilled approved time', unbilled, 'currency'))
            .note('Approved billable T&M time from the last ' + BusinessHealthData.WIP_WINDOW_DAYS + ' days not yet billed.');
        page.addKpi(new BusinessHealthModel.Kpi('margin', 'Labor margin, last ' + HOURS_WEEKS + ' weeks', BusinessHealthModel.pct(revenue - cost, revenue), 'percent'))
            .target(ctx.num(s.Gross_Margin_Target__c, 40), 'higher', 0.15)
            .note('Client T&M projects: billable revenue less labor cost of all hours logged on them. Fixed-fee and internal projects are excluded.');
        page.addKpi(new BusinessHealthModel.Kpi('hoursBurned', 'Hours burned, all projects', BusinessHealthModel.pct(logged, planned), 'percent'))
            .note(logged.setScale(0) + ' of ' + planned.setScale(0) + ' planned hours logged.');
        page.addKpi(new BusinessHealthModel.Kpi('openRequests', 'Open staffing requests', requests.rows.size(), 'number'))
            .note('Unfilled resource requests on your projects.');
        if (!overdueMilestones.isEmpty()) {
            page.addKpi(new BusinessHealthModel.Kpi('overdueMilestones', 'Overdue milestones', overdueMilestones.size(), 'number'))
                .target(0, 'lower', 0)
                .note('Open or planned milestones past their target date.');
        }

        // ---- charts --------------------------------------------------------------------------
        page.charts.add(
            new BusinessHealthModel.Chart('budgetVsEac', 'Budget vs estimate at completion', 'hbar', 'currency')
                .labels(chartNames)
                .addSeries('Budget', chartBudget)
                .addSeries('EAC', chartEac)
                .metric('eacOverrun')
        );
        List<String> wkLabels = new List<String>();
        List<Decimal> bill = new List<Decimal>();
        List<Decimal> nonBill = new List<Decimal>();
        for (Integer w = 0; w < HOURS_WEEKS; w++) {
            Date wk = hoursFrom.addDays(7 * w);
            wkLabels.add(MyWorkSupport.weekLabel(wk));
            bill.add(BusinessHealthData.nz(billableByWeek.get(wk)).setScale(0));
            nonBill.add(BusinessHealthData.nz(nonBillableByWeek.get(wk)).setScale(0));
        }
        page.charts.add(
            new BusinessHealthModel.Chart('teamHours', 'Team hours on my projects by week', 'bar', 'hours')
                .labels(wkLabels)
                .addSeries('Billable', bill)
                .addSeries('Non-billable', nonBill)
                .metric('margin')
        );

        // ---- tables ----------------------------------------------------------------------------
        page.tables.add(projectTable);
        page.tables.add(approvals);
        if (!requests.rows.isEmpty()) {
            page.tables.add(requests);
        }
        if (!overdueMilestones.isEmpty()) {
            BusinessHealthModel.Table ms = new BusinessHealthModel.Table('overdueMilestones', 'Overdue milestones', null)
                .link('name', 'Milestone', 'id')
                .col('project', 'Project', 'text')
                .col('target', 'Target date', 'date')
                .col('daysLate', 'Days late', 'number')
                .col('amount', 'Amount', 'currency');
            for (pse__Milestone__c m : overdueMilestones) {
                ms.rows.add(new Map<String, Object>{ 'id' => m.Id, 'name' => m.Name, 'project' => m.pse__Project__r.Name,
                    'target' => m.pse__Target_Date__c, 'daysLate' => m.pse__Target_Date__c.daysBetween(asOf), 'amount' => m.pse__Milestone_Amount__c });
            }
            page.tables.add(ms);
        }

        page.signalMissedKpis();
        page.briefMetrics = new List<String>{ 'eacOverrun', 'offTrack', 'toApprove', 'staleReports' };
        return page;
    }

    private static String ragStatus(String rag) {
        return rag == 'Green' ? BusinessHealthModel.STATUS_GOOD
            : rag == 'Yellow' ? BusinessHealthModel.STATUS_WARN
            : rag == 'Red' ? BusinessHealthModel.STATUS_BAD : BusinessHealthModel.STATUS_NEUTRAL;
    }
}
