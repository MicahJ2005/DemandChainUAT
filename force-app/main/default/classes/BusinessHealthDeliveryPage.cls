/**
 * @group BusinessHealth
 *
 * @description Delivery Health: estimate at completion vs budget (catches margin
 * erosion while there is still time to act), RAG status mix, milestone on-time rate,
 * change order volume (a scoping signal), write-offs, client satisfaction at close,
 * and hours burned vs percent complete on fixed-fee work.
 *
 * EAC = Estimate_at_Complete__c (Billings + Scheduled Time); budget = Bookings.
 */
public with sharing class BusinessHealthDeliveryPage implements BusinessHealthPageBuilder {
    private static final Decimal FIXED_FEE_BURN_GAP = 10;

    public BusinessHealthModel.HealthPage build(BusinessHealthContext ctx) {
        BusinessHealthModel.HealthPage page = new BusinessHealthModel.HealthPage(
            'delivery',
            'Delivery Health',
            'Which projects are eroding margin or slipping while there is still time to fix them?',
            'Directors'
        );
        Business_Health_Goal_Set__c s = ctx.goals;
        Date asOf = ctx.asOfDate;
        Date from12 = asOf.addMonths(-12);

        List<pse__Proj__c> projects = BusinessHealthData.activeClientProjects(ctx);

        // ---- EAC vs budget + RAG -------------------------------------------------
        Decimal totalBudget = 0;
        Decimal overrun = 0;
        Integer overBudget = 0;
        Integer withBudget = 0;
        Map<String, Map<String, Integer>> rag = new Map<String, Map<String, Integer>>{
            'Overall' => new Map<String, Integer>(),
            'Financial' => new Map<String, Integer>(),
            'Schedule' => new Map<String, Integer>()
        };
        BusinessHealthModel.Table riskTable = new BusinessHealthModel.Table('atRisk', 'At-risk projects',
            'Active client projects forecast over budget or flagged red/yellow, largest overrun first.')
            .link('name', 'Project', 'id')
            .col('account', 'Account', 'text')
            .col('pm', 'PM', 'text')
            .col('overall', 'Overall', 'status')
            .col('financial', 'Financial', 'status')
            .col('schedule', 'Schedule', 'status')
            .col('budget', 'Budget', 'currency')
            .col('eac', 'EAC', 'currency')
            .col('variance', 'Variance', 'currency')
            .col('hoursBurned', 'Hours burned', 'percent')
            .col('endDate', 'End', 'date');
        List<String> bigNames = new List<String>();
        List<Decimal> bigBudget = new List<Decimal>();
        List<Decimal> bigEac = new List<Decimal>();
        List<pse__Proj__c> bySize = new List<pse__Proj__c>();
        Set<Id> fixedFeeIds = new Set<Id>();
        for (pse__Proj__c p : projects) {
            tally(rag.get('Overall'), p.pse__Project_Status__c);
            tally(rag.get('Financial'), p.pse__Financial_Status__c);
            tally(rag.get('Schedule'), p.pse__Schedule_Status__c);
            if (p.pse__Billing_Type__c == 'Fixed Price') {
                fixedFeeIds.add(p.Id);
            }
            Decimal budget = BusinessHealthData.nz(p.pse__Bookings__c);
            Decimal eac = BusinessHealthData.nz(p.Estimate_at_Complete__c);
            if (budget <= 0) {
                continue;
            }
            withBudget++;
            totalBudget += budget;
            Decimal variance = budget - eac;
            if (variance < 0) {
                overBudget++;
                overrun -= variance;
            }
            Boolean flagged = p.pse__Project_Status__c == 'Red' || p.pse__Project_Status__c == 'Yellow' ||
                p.pse__Financial_Status__c == 'Red' || p.pse__Schedule_Status__c == 'Red';
            if (variance < 0 || flagged) {
                riskTable.rows.add(
                    new Map<String, Object>{
                        'id' => p.Id,
                        'name' => p.Name,
                        'account' => p.pse__Account__r == null ? null : p.pse__Account__r.Name,
                        'pm' => p.pse__Project_Manager__r == null ? null : p.pse__Project_Manager__r.Name,
                        'overall' => ragStatus(p.pse__Project_Status__c),
                        'financial' => ragStatus(p.pse__Financial_Status__c),
                        'schedule' => ragStatus(p.pse__Schedule_Status__c),
                        'budget' => budget,
                        'eac' => eac,
                        'variance' => variance,
                        'hoursBurned' => BusinessHealthData.hoursBurnedPct(p),
                        'endDate' => p.pse__End_Date__c
                    }
                );
            }
            bySize.add(p);
        }
        BusinessHealthModel.sortRowsAscending(riskTable.rows, 'variance');
        riskTable.rows = BusinessHealthModel.first(riskTable.rows, 25);

        // Largest 10 projects by budget for the EAC vs budget chart.
        List<BusinessHealthModel.RowSorter> sizeSort = new List<BusinessHealthModel.RowSorter>();
        for (pse__Proj__c p : bySize) {
            sizeSort.add(new BusinessHealthModel.RowSorter(new Map<String, Object>{ 'p' => p, 'b' => p.pse__Bookings__c }, 'b', true));
        }
        sizeSort.sort();
        for (Integer i = 0; i < Math.min(10, sizeSort.size()); i++) {
            pse__Proj__c p = (pse__Proj__c) sizeSort[i].row.get('p');
            bigNames.add(shortName(p.Name));
            bigBudget.add(BusinessHealthData.nz(p.pse__Bookings__c).setScale(0));
            bigEac.add(BusinessHealthData.nz(p.Estimate_at_Complete__c).setScale(0));
        }

        Integer statused = projects.size() - count(rag.get('Overall'), 'Not set');
        page.addKpi(new BusinessHealthModel.Kpi('activeProjects', 'Active client projects', projects.size(), 'number'))
            .note(BusinessHealthModel.formatValue(totalBudget, 'currency') + ' total budget (Bookings).');
        page.addKpi(new BusinessHealthModel.Kpi('eacOverrun', 'Forecast overrun (EAC over budget)', overrun, 'currency'))
            .target((totalBudget * ctx.num(s.EAC_Overrun_Threshold__c, 2) / 100).setScale(0), 'lower', 0.5)
            .note(overBudget + ' of ' + withBudget + ' budgeted projects have EAC (billed + scheduled) above budget. Target: under ' + ctx.num(s.EAC_Overrun_Threshold__c, 2).setScale(1).format() + '% of active budget.');
        page.addKpi(new BusinessHealthModel.Kpi('overBudgetShare', 'Projects forecast over budget', BusinessHealthModel.pct(overBudget, withBudget), 'percent'))
            .target(ctx.num(s.Over_Budget_Threshold__c, 10), 'lower', 0.5);
        page.addKpi(new BusinessHealthModel.Kpi('redShare', 'Projects in red', BusinessHealthModel.pct(count(rag.get('Overall'), 'Red'), statused), 'percent'))
            .target(ctx.num(s.Red_Project_Threshold__c, 10), 'lower', 0.5)
            .note(count(rag.get('Overall'), 'Red') + ' red, ' + count(rag.get('Overall'), 'Yellow') + ' yellow, ' +
                count(rag.get('Overall'), 'Green') + ' green; ' + count(rag.get('Overall'), 'Not set') + ' with no status.');

        // ---- milestones ---------------------------------------------------------------
        ctx.bind('msFrom12', from12);
        Integer onTime = 0;
        Integer completed = 0;
        Map<String, Integer> completedByMonth = new Map<String, Integer>();
        Map<String, Integer> onTimeByMonth = new Map<String, Integer>();
        for (pse__Milestone__c m : (List<pse__Milestone__c>) ctx.query(
            'SELECT pse__Actual_Date__c, pse__Target_Date__c FROM pse__Milestone__c' +
                ' WHERE pse__Status__c = \'Approved\' AND pse__Actual_Date__c > :msFrom12 AND pse__Actual_Date__c <= :asOf' +
                ' AND pse__Target_Date__c != null' +
                ctx.practiceClause('pse__Project__r.pse__Practice__c')
        )) {
            String mk = BusinessHealthContext.monthKey(m.pse__Actual_Date__c);
            completed++;
            completedByMonth.put(mk, (completedByMonth.containsKey(mk) ? completedByMonth.get(mk) : 0) + 1);
            if (m.pse__Actual_Date__c <= m.pse__Target_Date__c) {
                onTime++;
                onTimeByMonth.put(mk, (onTimeByMonth.containsKey(mk) ? onTimeByMonth.get(mk) : 0) + 1);
            }
        }
        page.addKpi(new BusinessHealthModel.Kpi('milestoneOnTime', 'Milestones on time (T12M)', BusinessHealthModel.pct(onTime, completed), 'percent'))
            .target(ctx.num(s.Milestone_On_Time_Target__c, 85), 'higher', 0.1)
            .note(onTime + ' of ' + completed + ' approved milestones approved on or before target date.');

        ctx.bind('overdueFloor', from12);
        ctx.bind('activeIds', new Map<Id, pse__Proj__c>(projects).keySet());
        List<pse__Milestone__c> overdue = (List<pse__Milestone__c>) ctx.query(
            'SELECT Id, Name, pse__Project__c, pse__Project__r.Name, pse__Target_Date__c, pse__Milestone_Amount__c FROM pse__Milestone__c' +
                ' WHERE pse__Status__c IN (\'Open\', \'Planned\') AND pse__Target_Date__c < :asOf AND pse__Target_Date__c > :overdueFloor' +
                ' AND pse__Project__c IN :activeIds ORDER BY pse__Target_Date__c LIMIT 200'
        );
        BusinessHealthModel.Table overdueTable = new BusinessHealthModel.Table('overdueMilestones', 'Overdue milestones',
            'Open or planned milestones on active projects past their target date.')
            .link('name', 'Milestone', 'id')
            .col('project', 'Project', 'text')
            .col('target', 'Target date', 'date')
            .col('daysLate', 'Days late', 'number')
            .col('amount', 'Amount', 'currency');
        Decimal overdueAmount = 0;
        for (pse__Milestone__c m : overdue) {
            overdueAmount += BusinessHealthData.nz(m.pse__Milestone_Amount__c);
            if (overdueTable.rows.size() < 20) {
                overdueTable.rows.add(
                    new Map<String, Object>{
                        'id' => m.Id,
                        'name' => m.Name,
                        'project' => m.pse__Project__r.Name,
                        'target' => m.pse__Target_Date__c,
                        'daysLate' => m.pse__Target_Date__c.daysBetween(asOf),
                        'amount' => m.pse__Milestone_Amount__c
                    }
                );
            }
        }
        page.addKpi(new BusinessHealthModel.Kpi('overdueMilestones', 'Overdue milestones', overdue.size(), 'number'))
            .target(0, 'lower', 0)
            .note(BusinessHealthModel.formatValue(overdueAmount, 'currency') + ' of milestone value is past target date and not yet approved, which delays fixed-fee billing.');

        // ---- change orders ------------------------------------------------------------
        Decimal changeOrderAmount = 0;
        Integer changeOrders = 0;
        Decimal bookings12 = 0;
        for (Opportunity o : BusinessHealthData.wonOpportunities(ctx, from12)) {
            bookings12 += BusinessHealthData.nz(o.Amount);
            if (o.Type == 'Existing Cust - Change Order') {
                changeOrders++;
                changeOrderAmount += BusinessHealthData.nz(o.Amount);
            }
        }
        page.addKpi(new BusinessHealthModel.Kpi('changeOrders', 'Change orders (share of bookings, T12M)', BusinessHealthModel.pct(changeOrderAmount, bookings12), 'percent'))
            .target(ctx.num(s.Change_Order_Threshold__c, 15), 'lower', 0.5)
            .note(changeOrders + ' change orders worth ' + BusinessHealthModel.formatValue(changeOrderAmount, 'currency') +
                '. A high share means initial scoping is missing work.');

        // ---- write-offs ---------------------------------------------------------------
        Map<String, Decimal> rates = BusinessHealthData.standardRates();
        Decimal avgRate = BusinessHealthData.averageStandardRate();
        Decimal writeOffHours = 0;
        Decimal writeOffValue = 0;
        for (BusinessHealthData.TimecardFact f : BusinessHealthData.timecards(ctx, from12)) {
            if (f.clientProject && f.billingType != 'Fixed Price' && f.billableHours == 0 && f.hours > 0) {
                Decimal rate = f.assignmentRole == null ? null : rates.get(BusinessHealthData.normalizeRole(f.assignmentRole));
                writeOffHours += f.hours;
                writeOffValue += f.hours * (rate == null ? avgRate : rate);
            }
        }
        List<AggregateResult> writtenOff = [
            SELECT SUM(CollectionAmount__c) amt
            FROM Account_Collection__c
            WHERE Status__c = 'Written Off' AND LastModifiedDate >= :Datetime.newInstance(from12, Time.newInstance(0, 0, 0, 0))
            WITH USER_MODE
        ];
        Decimal arWrittenOff = writtenOff.isEmpty() ? 0 : BusinessHealthData.nz((Decimal) writtenOff[0].get('amt'));
        page.addKpi(new BusinessHealthModel.Kpi('writeOffs', 'Write-offs (T12M)', writeOffValue + arWrittenOff, 'currency'))
            .target((bookings12 * ctx.num(s.Write_Off_Threshold__c, 2) / 100).setScale(0), 'lower', 0.5)
            .note(writeOffHours.setScale(0) + ' non-billable hours on client T&M projects at standard rates, plus ' +
                BusinessHealthModel.formatValue(arWrittenOff, 'currency') + ' of AR written off.');

        // ---- CSAT ---------------------------------------------------------------------
        List<AggregateResult> csat = [
            SELECT AVG(CSATRPTSCORE__c) score, COUNT(Id) cnt
            FROM Project_CSAT__c
            WHERE CSAT_Status__c = 'Completed' AND Survey_Returned_Date__c > :from12 AND Survey_Returned_Date__c <= :asOf
            WITH USER_MODE
        ];
        Integer csatCount = csat.isEmpty() ? 0 : (Integer) csat[0].get('cnt');
        BusinessHealthModel.Kpi csatKpi = page.addKpi(new BusinessHealthModel.Kpi('csat', 'Client satisfaction at close (T12M)',
            csatCount == 0 ? null : ((Decimal) csat[0].get('score')).setScale(2), 'score'));
        if (csatCount == 0) {
            csatKpi.markUnavailable('No completed CSAT surveys returned in the last 12 months. Survey every project at close.');
            page.signal(BusinessHealthModel.STATUS_WARN, 'No client satisfaction surveys were returned in the last 12 months, so delivery quality is not being measured.');
        } else {
            csatKpi.target(ctx.num(s.CSAT_Target__c, 4.5), 'higher', 0.1).note(csatCount + ' surveys, 5-point scale (10-point scores halved).');
        }

        // ---- fixed-fee burn -------------------------------------------------------------
        BusinessHealthModel.Table burnTable = new BusinessHealthModel.Table('fixedFeeBurn', 'Fixed-fee: hours burned vs percent complete',
            'Percent complete = approved milestone value / total milestone value. Burning more than ' +
                FIXED_FEE_BURN_GAP.setScale(0) + ' points ahead of completion means the fee will run out first.')
            .link('name', 'Project', 'id')
            .col('budget', 'Fee', 'currency')
            .col('hoursBurned', 'Hours burned', 'percent')
            .col('complete', '% complete', 'percent')
            .col('gap', 'Gap (pts)', 'number')
            .col('status', 'Status', 'status');
        Integer burningAhead = 0;
        if (!fixedFeeIds.isEmpty()) {
            ctx.bind('fixedFeeIds', fixedFeeIds);
            Map<Id, Decimal> totalMs = new Map<Id, Decimal>();
            Map<Id, Decimal> approvedMs = new Map<Id, Decimal>();
            for (AggregateResult ar : ctx.aggregate(
                'SELECT pse__Project__c proj, pse__Approved__c appr, SUM(pse__Milestone_Amount__c) amt FROM pse__Milestone__c' +
                    ' WHERE pse__Project__c IN :fixedFeeIds AND pse__Status__c != \'Canceled\' GROUP BY pse__Project__c, pse__Approved__c'
            )) {
                Id proj = (Id) ar.get('proj');
                Decimal amt = BusinessHealthData.nz((Decimal) ar.get('amt'));
                BusinessHealthData.add(totalMs, proj, amt);
                if ((Boolean) ar.get('appr')) {
                    BusinessHealthData.add(approvedMs, proj, amt);
                }
            }
            for (pse__Proj__c p : projects) {
                if (!fixedFeeIds.contains(p.Id)) {
                    continue;
                }
                Decimal burned = BusinessHealthData.hoursBurnedPct(p);
                Decimal complete = BusinessHealthModel.pct(approvedMs.get(p.Id), totalMs.get(p.Id));
                if (complete == null && totalMs.containsKey(p.Id)) {
                    complete = 0;
                }
                Decimal gap = burned == null || complete == null ? null : burned - complete;
                if (gap != null && gap > FIXED_FEE_BURN_GAP) {
                    burningAhead++;
                }
                burnTable.rows.add(
                    new Map<String, Object>{
                        'id' => p.Id,
                        'name' => p.Name,
                        'budget' => p.pse__Bookings__c,
                        'hoursBurned' => burned,
                        'complete' => complete,
                        'gap' => gap == null ? null : gap.setScale(0),
                        'status' => gap == null
                            ? BusinessHealthModel.STATUS_NEUTRAL
                            : BusinessHealthModel.evaluate(gap, FIXED_FEE_BURN_GAP, 'lower', 1)
                    }
                );
            }
            BusinessHealthModel.sortRows(burnTable.rows, 'gap');
        }
        page.addKpi(new BusinessHealthModel.Kpi('fixedFeeAhead', 'Fixed-fee projects burning ahead', burningAhead, 'number'))
            .target(0, 'lower', 0)
            .note(fixedFeeIds.size() + ' active fixed-fee projects; hours burned more than ' + FIXED_FEE_BURN_GAP.setScale(0) + ' points ahead of % complete.');

        // ---- charts -------------------------------------------------------------------
        List<String> ragLabels = new List<String>{ 'Green', 'Yellow', 'Red', 'Not set' };
        BusinessHealthModel.Chart ragChart = new BusinessHealthModel.Chart('rag', 'Project status mix (active client projects)', 'bar', 'number').labels(ragLabels);
        for (String dim : rag.keySet()) {
            List<Decimal> values = new List<Decimal>();
            for (String l : ragLabels) {
                values.add(count(rag.get(dim), l));
            }
            ragChart.addSeries(dim, values);
        }
        page.charts.add(ragChart);
        page.charts.add(
            new BusinessHealthModel.Chart('eacVsBudget', 'Largest projects: budget vs estimate at completion', 'hbar', 'currency')
                .labels(bigNames)
                .addSeries('Budget', bigBudget)
                .addSeries('EAC', bigEac)
        );
        List<String> keys12 = ctx.completeMonthKeys(12);
        List<Decimal> onTimeSeries = new List<Decimal>();
        for (String k : keys12) {
            onTimeSeries.add(BusinessHealthModel.pct(onTimeByMonth.get(k), completedByMonth.get(k)));
        }
        page.charts.add(
            new BusinessHealthModel.Chart('milestoneTrend', 'Milestones approved on time, by month', 'line', 'percent')
                .labels(ctx.completeMonthLabels(12))
                .addSeries('On time', onTimeSeries)
                .target(ctx.num(s.Milestone_On_Time_Target__c, 85), 'Target')
        );

        page.tables.add(riskTable);
        page.tables.add(burnTable);
        page.tables.add(overdueTable);

        page.signalMissedKpis();
        if (count(rag.get('Overall'), 'Not set') > projects.size() / 4) {
            page.signal(BusinessHealthModel.STATUS_INFO, count(rag.get('Overall'), 'Not set') +
                ' active projects have no Project Status. RAG reporting only works if PMs update status weekly.');
        }
        page.dataGaps.add('EAC relies on PSA Scheduled Time. Projects without current assignment schedules understate EAC.');
        return page;
    }

    private static void tally(Map<String, Integer> m, String status) {
        String key = String.isBlank(status) ? 'Not set' : status;
        m.put(key, (m.containsKey(key) ? m.get(key) : 0) + 1);
    }

    private static Integer count(Map<String, Integer> m, String key) {
        return m.containsKey(key) ? m.get(key) : 0;
    }

    private static String ragStatus(String rag) {
        if (rag == 'Green') {
            return BusinessHealthModel.STATUS_GOOD;
        }
        if (rag == 'Yellow') {
            return BusinessHealthModel.STATUS_WARN;
        }
        if (rag == 'Red') {
            return BusinessHealthModel.STATUS_BAD;
        }
        return BusinessHealthModel.STATUS_NEUTRAL;
    }

    /** Project names follow "Account | Project - - date-Project"; keep the project part. */
    private static String shortName(String name) {
        String n = name.contains('|') ? name.substringAfter('|').trim() : name;
        n = n.substringBefore(' - ').trim();
        return n.abbreviate(36);
    }
}
