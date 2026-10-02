/**
 * @group BusinessHealth
 *
 * @description Utilization & Capacity: billable utilization by role and by person
 * against role targets, bench, forecast utilization for the next 8 weeks (from PSA
 * assignment schedules), open demand (unfilled resource requests) vs available
 * capacity, and subcontractor mix. Together these answer: hire, use subcontractors,
 * or push sales?
 *
 * Weeks are keyed by their start date (Date.toStartOfWeek()), matching PSA's
 * week-ending-Saturday timecards and weekly Est vs Actuals rows.
 */
public with sharing class BusinessHealthCapacityPage implements BusinessHealthPageBuilder {
    private static final Integer PAST_WEEKS = 13;
    private static final Integer FUTURE_WEEKS = 8;
    private static final Decimal BENCH_THRESHOLD = 25;
    private static final Decimal OVERALLOCATED_THRESHOLD = 110;
    private static final Set<String> OPEN_REQUEST_STATUSES = new Set<String>{ 'Draft', 'Ready to Staff', 'Hold', 'Tentative' };

    private class Person {
        Contact c;
        Decimal billable4 = 0;
        Decimal billable13 = 0;
        Decimal scheduled8 = 0;
        Decimal scheduled4 = 0;
    }

    public BusinessHealthModel.HealthPage build(BusinessHealthContext ctx) {
        BusinessHealthModel.HealthPage page = new BusinessHealthModel.HealthPage(
            'capacity',
            'Utilization & Capacity',
            'Are people busy on billable work, and is there enough work, or too much, coming in the next 8 weeks?',
            'Directors'
        );
        Business_Health_Goal_Set__c s = ctx.goals;
        Decimal hpw = ctx.hoursPerWeek();
        Decimal firmTarget = ctx.num(s.Delivery_Utilization_Target__c, 75);

        // Complete weeks only: the last past week is the latest one ending on or before as-of.
        Date lastPastWeekStart = ctx.asOfDate.addDays(-6).toStartOfWeek();
        Date firstPastWeekStart = lastPastWeekStart.addDays(-7 * (PAST_WEEKS - 1));
        Date firstFutureWeekStart = lastPastWeekStart.addDays(7);
        Date futureEnd = firstFutureWeekStart.addDays(7 * FUTURE_WEEKS - 1);
        Date fourWeeksStart = lastPastWeekStart.addDays(-21);

        List<Contact> resources = BusinessHealthData.activeResources(ctx);
        List<BusinessHealthData.TimecardFact> tcs = BusinessHealthData.timecards(ctx, firstPastWeekStart, 'pse__Resource__r.pse__Practice__c');
        Map<Id, Contact> delivery = BusinessHealthData.internalBillable(resources, tcs, ctx.asOfDate);

        Map<Id, Person> people = new Map<Id, Person>();
        for (Contact c : delivery.values()) {
            Person p = new Person();
            p.c = c;
            people.put(c.Id, p);
        }

        // ---- actuals ------------------------------------------------------------------
        Map<Date, Decimal> billableByWeek = new Map<Date, Decimal>();
        Decimal externalBillable = 0;
        Decimal totalBillable = 0;
        for (BusinessHealthData.TimecardFact f : tcs) {
            Date wk = f.endDate.toStartOfWeek();
            if (wk > lastPastWeekStart) {
                continue;
            }
            totalBillable += f.billableHours;
            if (f.external) {
                externalBillable += f.billableHours;
            }
            Person p = people.get(f.resourceId);
            if (p == null) {
                continue;
            }
            addDate(billableByWeek, wk, f.billableHours);
            p.billable13 += f.billableHours;
            if (wk >= fourWeeksStart) {
                p.billable4 += f.billableHours;
            }
        }

        // ---- forecast: scheduled billable hours (weekly Est vs Actuals) -------------------
        ctx.bind('futureStart', firstFutureWeekStart);
        ctx.bind('futureEnd', futureEnd.addDays(6));
        ctx.bind('deliveryIds', people.keySet());
        Map<Date, Decimal> scheduledByWeek = new Map<Date, Decimal>();
        Date fourWeekForecastEnd = firstFutureWeekStart.addDays(7 * 4);
        for (AggregateResult ar : ctx.aggregate(
            'SELECT pse__Resource__c res, pse__End_Date__c wkEnd, SUM(pse__Estimated_Hours__c) hrs FROM pse__Est_Vs_Actuals__c' +
                ' WHERE pse__Time_Period_Type__c = \'Week\' AND pse__Assignment__r.pse__Is_Billable__c = true' +
                ' AND pse__Resource__c IN :deliveryIds AND pse__End_Date__c >= :futureStart AND pse__End_Date__c <= :futureEnd' +
                ' GROUP BY pse__Resource__c, pse__End_Date__c'
        )) {
            Date wk = ((Date) ar.get('wkEnd')).toStartOfWeek();
            Decimal hrs = BusinessHealthData.nz((Decimal) ar.get('hrs'));
            if (wk < firstFutureWeekStart || wk > futureEnd) {
                continue;
            }
            addDate(scheduledByWeek, wk, hrs);
            Person p = people.get((Id) ar.get('res'));
            p.scheduled8 += hrs;
            if (wk < fourWeekForecastEnd) {
                p.scheduled4 += hrs;
            }
        }

        // ---- open demand: unfilled resource requests, prorated per week -------------------
        ctx.bind('openStatuses', OPEN_REQUEST_STATUSES);
        ctx.bind('demandEnd', futureEnd.addDays(6));
        List<pse__Resource_Request__c> requests = (List<pse__Resource_Request__c>) ctx.query(
            'SELECT Id, Name, pse__Resource_Request_Name__c, pse__Project__r.Name, pse__Opportunity__r.Name, pse__Resource_Role__c,' +
                ' pse__Start_Date__c, pse__End_Date__c, pse__SOW_Hours__c, pse__Status__c, pse__Opportunity_Probability__c, pse__Request_Priority__c' +
                ' FROM pse__Resource_Request__c WHERE pse__Status__c IN :openStatuses' +
                ' AND pse__Start_Date__c <= :demandEnd AND pse__End_Date__c >= :futureStart' +
                ctx.practiceClause('pse__Practice__c') +
                ' ORDER BY pse__Start_Date__c'
        );
        Map<Date, Decimal> demandByWeek = new Map<Date, Decimal>();
        BusinessHealthModel.Table requestTable = new BusinessHealthModel.Table('openRequests', 'Open resource requests (next 8 weeks)',
            'Unfilled demand. Hours shown are the part of each request that falls in the window.')
            .link('name', 'Request', 'id')
            .col('work', 'Project / opportunity', 'text')
            .col('role', 'Role', 'text')
            .col('start', 'Start', 'date')
            .col('end', 'End', 'date')
            .col('hours', 'Hours in window', 'hours')
            .col('probability', 'Opp. prob.', 'percent')
            .col('status', 'Status', 'text');
        Decimal openDemand = 0;
        for (pse__Resource_Request__c r : requests) {
            Decimal inWindow = 0;
            Integer totalDays = Math.max(1, r.pse__Start_Date__c.daysBetween(r.pse__End_Date__c) + 1);
            Decimal perDay = BusinessHealthData.nz(r.pse__SOW_Hours__c) / totalDays;
            for (Integer w = 0; w < FUTURE_WEEKS; w++) {
                Date ws = firstFutureWeekStart.addDays(7 * w);
                Date we = ws.addDays(6);
                Date os = r.pse__Start_Date__c > ws ? r.pse__Start_Date__c : ws;
                Date oe = r.pse__End_Date__c < we ? r.pse__End_Date__c : we;
                if (os <= oe) {
                    Decimal h = perDay * (os.daysBetween(oe) + 1);
                    addDate(demandByWeek, ws, h);
                    inWindow += h;
                }
            }
            openDemand += inWindow;
            requestTable.rows.add(
                new Map<String, Object>{
                    'id' => r.Id,
                    'name' => String.isBlank(r.pse__Resource_Request_Name__c) ? r.Name : r.pse__Resource_Request_Name__c,
                    'work' => r.pse__Project__r != null ? r.pse__Project__r.Name : (r.pse__Opportunity__r != null ? r.pse__Opportunity__r.Name : null),
                    'role' => r.pse__Resource_Role__c,
                    'start' => r.pse__Start_Date__c,
                    'end' => r.pse__End_Date__c,
                    'hours' => inWindow.setScale(0),
                    'probability' => r.pse__Opportunity_Probability__c,
                    'status' => r.pse__Status__c
                }
            );
        }

        // ---- firm-level KPIs --------------------------------------------------------------
        Integer n = people.size();
        Decimal b4 = 0;
        Decimal b13 = 0;
        Decimal sched8 = 0;
        Integer bench = 0;
        Integer overallocated = 0;
        for (Person p : people.values()) {
            b4 += p.billable4;
            b13 += p.billable13;
            sched8 += p.scheduled8;
            Decimal f4 = BusinessHealthModel.pct(p.scheduled4, hpw * 4);
            if (f4 != null && f4 < BENCH_THRESHOLD) {
                bench++;
            }
            if (BusinessHealthModel.pct(p.scheduled8, hpw * FUTURE_WEEKS) > OVERALLOCATED_THRESHOLD) {
                overallocated++;
            }
        }
        Decimal capacity8 = n * hpw * FUTURE_WEEKS;
        Decimal available8 = Math.max(capacity8 * firmTarget / 100 - sched8, 0);
        page.addKpi(new BusinessHealthModel.Kpi('util4', 'Billable utilization (last 4 weeks)', BusinessHealthModel.pct(b4, n * hpw * 4), 'percent'))
            .target(firmTarget, 'higher', 0.1)
            .note(n + ' internal delivery resources, billable hours / ' + hpw.setScale(0) + ' hrs per week.');
        page.addKpi(new BusinessHealthModel.Kpi('util13', 'Billable utilization (last 13 weeks)', BusinessHealthModel.pct(b13, n * hpw * PAST_WEEKS), 'percent'))
            .target(firmTarget, 'higher', 0.1);
        page.addKpi(new BusinessHealthModel.Kpi('forecast8', 'Forecast utilization (next 8 weeks)', BusinessHealthModel.pct(sched8, capacity8), 'percent'))
            .target(firmTarget, 'higher', 0.15)
            .note('Scheduled billable assignment hours (PSA Est vs Actuals). Low numbers mean unsold capacity, or schedules not yet entered.');
        Integer benchTarget = Math.max(1, (Integer) Math.floor(n * ctx.num(s.Bench_Threshold__c, 10) / 100));
        page.addKpi(new BusinessHealthModel.Kpi('bench', 'On the bench (next 4 weeks)', bench, 'number'))
            .target(benchTarget, 'lower', 0.5)
            .note('Delivery resources scheduled under ' + BENCH_THRESHOLD.setScale(0) + '% billable for the next 4 weeks. ' +
                overallocated + ' are over-allocated (>' + OVERALLOCATED_THRESHOLD.setScale(0) + '%).');
        Decimal demandRatio = available8 == 0 ? null : (openDemand / available8).setScale(2);
        BusinessHealthModel.Kpi demandKpi = page.addKpi(new BusinessHealthModel.Kpi('demandRatio', 'Open demand / available capacity', demandRatio, 'ratio'))
            .note(openDemand.setScale(0) + ' open request hours vs ' + available8.setScale(0) +
                ' available hours (capacity at target utilization minus scheduled). Above 1.2: hire or subcontract. Below 0.5: push sales.');
        demandKpi.targetLabel = '0.5x - 1.2x';
        demandKpi.status = demandRatio == null
            ? (openDemand > 0 ? BusinessHealthModel.STATUS_BAD : BusinessHealthModel.STATUS_NEUTRAL)
            : (demandRatio > 1.2 || demandRatio < 0.5 ? BusinessHealthModel.STATUS_WARN : BusinessHealthModel.STATUS_GOOD);
        page.addKpi(new BusinessHealthModel.Kpi('available8', 'Unscheduled capacity (next 8 weeks)', available8, 'hours'))
            .note('Hours needed to reach target utilization, i.e. work sales still needs to find. Roughly ' +
                BusinessHealthModel.formatValue(available8 * BusinessHealthData.averageStandardRate(), 'currency') + ' at standard rates.');
        page.addKpi(new BusinessHealthModel.Kpi('subMix', 'Subcontractor mix (13 weeks)', BusinessHealthModel.pct(externalBillable, totalBillable), 'percent'))
            .note('Share of all billable hours delivered by external resources. It drives both margin and quality.');

        // ---- charts -----------------------------------------------------------------------
        List<String> weekLabels = new List<String>();
        List<Decimal> actualSeries = new List<Decimal>();
        List<Decimal> forecastSeries = new List<Decimal>();
        for (Integer w = 0; w < PAST_WEEKS; w++) {
            Date ws = firstPastWeekStart.addDays(7 * w);
            weekLabels.add(Datetime.newInstance(ws.year(), ws.month(), ws.day()).format('M/d'));
            actualSeries.add(BusinessHealthModel.pct(BusinessHealthData.nz(billableByWeek.get(ws)), n * hpw));
            forecastSeries.add(null);
        }
        List<String> futureLabels = new List<String>();
        List<Decimal> capacitySeries = new List<Decimal>();
        List<Decimal> scheduledSeries = new List<Decimal>();
        List<Decimal> demandSeries = new List<Decimal>();
        for (Integer w = 0; w < FUTURE_WEEKS; w++) {
            Date ws = firstFutureWeekStart.addDays(7 * w);
            String label = Datetime.newInstance(ws.year(), ws.month(), ws.day()).format('M/d');
            weekLabels.add(label);
            futureLabels.add(label);
            actualSeries.add(null);
            forecastSeries.add(BusinessHealthModel.pct(BusinessHealthData.nz(scheduledByWeek.get(ws)), n * hpw));
            capacitySeries.add((n * hpw * firmTarget / 100).setScale(0));
            scheduledSeries.add(BusinessHealthData.nz(scheduledByWeek.get(ws)).setScale(0));
            demandSeries.add(BusinessHealthData.nz(demandByWeek.get(ws)).setScale(0));
        }
        page.charts.add(
            new BusinessHealthModel.Chart('weeklyUtilization', 'Weekly billable utilization: actual and scheduled', 'line', 'percent')
                .labels(weekLabels)
                .addSeries('Actual', actualSeries)
                .addSeries('Scheduled', forecastSeries)
                .target(firmTarget, 'Target')
        );
        page.charts.add(
            new BusinessHealthModel.Chart('demandVsCapacity', 'Next 8 weeks: capacity vs scheduled vs open demand (hours)', 'bar', 'hours')
                .labels(futureLabels)
                .addSeries('Capacity at target', capacitySeries)
                .addSeries('Scheduled', scheduledSeries)
                .addSeries('Open demand', demandSeries)
        );

        // ---- by role ------------------------------------------------------------------
        Map<String, List<Person>> byRole = new Map<String, List<Person>>();
        for (Person p : people.values()) {
            String role = String.isBlank(p.c.pse__Resource_Role__c) ? 'No role set' : p.c.pse__Resource_Role__c;
            if (!byRole.containsKey(role)) {
                byRole.put(role, new List<Person>());
            }
            byRole.get(role).add(p);
        }
        BusinessHealthModel.Table roleTable = new BusinessHealthModel.Table('byRole', 'Utilization by role',
            'Targets by role come from Business Health Settings (delivery roles run higher than architects and leaders).')
            .col('role', 'Role', 'text')
            .col('headcount', 'People', 'number')
            .col('util4', 'Last 4 wks', 'percent')
            .col('util13', 'Last 13 wks', 'percent')
            .col('forecast', 'Next 8 wks', 'percent')
            .col('target', 'Target', 'percent')
            .col('status', 'Status', 'status');
        List<String> roleNames = new List<String>();
        List<Decimal> roleUtil = new List<Decimal>();
        for (String role : byRole.keySet()) {
            Decimal rb4 = 0;
            Decimal rb13 = 0;
            Decimal rs8 = 0;
            for (Person p : byRole.get(role)) {
                rb4 += p.billable4;
                rb13 += p.billable13;
                rs8 += p.scheduled8;
            }
            Integer rn = byRole.get(role).size();
            Decimal u13 = BusinessHealthModel.pct(rb13, rn * hpw * PAST_WEEKS);
            Decimal target = ctx.roleTarget(role);
            roleTable.rows.add(
                new Map<String, Object>{
                    'role' => role,
                    'headcount' => rn,
                    'util4' => BusinessHealthModel.pct(rb4, rn * hpw * 4),
                    'util13' => u13,
                    'forecast' => BusinessHealthModel.pct(rs8, rn * hpw * FUTURE_WEEKS),
                    'target' => target,
                    'status' => BusinessHealthModel.evaluate(u13, target, 'higher', 0.1)
                }
            );
            roleNames.add(role);
            roleUtil.add(u13);
        }
        BusinessHealthModel.sortRows(roleTable.rows, 'headcount');
        page.tables.add(roleTable);
        page.charts.add(
            new BusinessHealthModel.Chart('utilByRole', 'Billable utilization by role (last 13 weeks)', 'hbar', 'percent')
                .labels(roleNames)
                .addSeries('Utilization', roleUtil)
                .target(firmTarget, 'Firm target')
        );

        // ---- by person ----------------------------------------------------------------
        BusinessHealthModel.Table personTable = new BusinessHealthModel.Table('byPerson', 'Utilization by person',
            'Sorted by scheduled utilization for the next 8 weeks, lowest first, so bench risk is at the top.')
            .link('name', 'Resource', 'id')
            .col('role', 'Role', 'text')
            .col('practice', 'Practice', 'text')
            .col('util4', 'Last 4 wks', 'percent')
            .col('util13', 'Last 13 wks', 'percent')
            .col('forecast', 'Next 8 wks', 'percent')
            .col('available', 'Open hrs (8 wks)', 'hours')
            .col('target', 'Target', 'percent')
            .col('flag', 'Flag', 'text')
            .col('status', 'Status', 'status');
        for (Person p : people.values()) {
            Decimal u13 = BusinessHealthModel.pct(p.billable13, hpw * PAST_WEEKS);
            Decimal f8 = BusinessHealthModel.pct(p.scheduled8, hpw * FUTURE_WEEKS);
            Decimal f4 = BusinessHealthModel.pct(p.scheduled4, hpw * 4);
            Decimal target = ctx.roleTarget(p.c.pse__Resource_Role__c);
            String flag = f4 != null && f4 < BENCH_THRESHOLD ? 'Bench risk' : (f8 != null && f8 > OVERALLOCATED_THRESHOLD ? 'Over-allocated' : '');
            personTable.rows.add(
                new Map<String, Object>{
                    'id' => p.c.Id,
                    'name' => p.c.Name,
                    'role' => p.c.pse__Resource_Role__c,
                    'practice' => p.c.pse__Practice__r == null ? null : p.c.pse__Practice__r.Name,
                    'util4' => BusinessHealthModel.pct(p.billable4, hpw * 4),
                    'util13' => u13,
                    'forecast' => f8,
                    'available' => Math.max(hpw * FUTURE_WEEKS * target / 100 - p.scheduled8, 0).setScale(0),
                    'target' => target,
                    'flag' => flag,
                    'status' => BusinessHealthModel.evaluate(f8, target, 'higher', 0.15)
                }
            );
        }
        BusinessHealthModel.sortRowsAscending(personTable.rows, 'forecast');
        page.tables.add(personTable);
        page.tables.add(requestTable);

        // ---- signals ----------------------------------------------------------------------
        page.signalMissedKpis();
        if (requests.isEmpty()) {
            page.signal(BusinessHealthModel.STATUS_INFO, 'No open resource requests. Demand is only visible once pipeline deals raise PSA resource requests.');
        }
        Decimal f8firm = BusinessHealthModel.pct(sched8, capacity8);
        Decimal u4firm = BusinessHealthModel.pct(b4, n * hpw * 4);
        if (f8firm != null && u4firm != null && f8firm < u4firm - 20) {
            page.signal(BusinessHealthModel.STATUS_WARN, 'Scheduled utilization drops ' + (u4firm - f8firm).setScale(0) +
                ' points below recent actuals. Either work is ending without replacements, or assignment schedules are not being kept current.');
        }
        page.dataGaps.add('Forecast depends on PSA assignment schedules. Work without a scheduled assignment is invisible here.');
        return page;
    }

    private static void addDate(Map<Date, Decimal> m, Date key, Decimal value) {
        m.put(key, BusinessHealthData.nz(m.get(key)) + BusinessHealthData.nz(value));
    }
}
