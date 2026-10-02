/**
 * @group BusinessHealth
 *
 * @description Leadership Scorecard: the compact, trend-based view - book-to-bill,
 * backlog runway, gross margin, utilization, cash (unbilled WIP / DSO), attrition,
 * client concentration and recurring revenue growth, month over month against
 * targets. Operational drill-downs live on the director pages.
 */
public with sharing class BusinessHealthLeadershipPage implements BusinessHealthPageBuilder {
    private static final Integer TREND_MONTHS = 6;

    public BusinessHealthModel.HealthPage build(BusinessHealthContext ctx) {
        BusinessHealthModel.HealthPage page = new BusinessHealthModel.HealthPage(
            'leadership',
            'Leadership Scorecard',
            'The firm-level signals, month over month against target. Complete months through ' +
                BusinessHealthContext.monthLabel(ctx.referenceMonthStart()) + '.',
            'Leadership'
        );
        Business_Health_Goal_Set__c s = ctx.goals;

        // 16 complete months: 12 for trailing-year metrics, plus 3 more so the first
        // point of a 6-month trailing-3-month trend and the prior-year recurring
        // comparison both have full windows.
        List<String> keys16 = ctx.completeMonthKeys(16);
        List<String> labels16 = ctx.completeMonthLabels(16);
        List<String> keys12 = BusinessHealthData.tailLabels(keys16, 12);
        List<String> labels12 = BusinessHealthData.tailLabels(labels16, 12);
        List<String> keys3 = BusinessHealthData.tailLabels(keys16, 3);
        List<String> trendKeys = BusinessHealthData.tailLabels(keys16, TREND_MONTHS);
        List<String> trendLabels = BusinessHealthData.tailLabels(labels16, TREND_MONTHS);
        Date from16 = ctx.windowStart(16);

        List<BusinessHealthData.TimecardFact> tcs = BusinessHealthData.timecards(ctx, from16);
        List<BusinessHealthData.MilestoneFact> ms = BusinessHealthData.milestoneRevenue(ctx, from16);
        Map<String, Decimal> delivered = BusinessHealthData.deliveredByMonth(tcs, ms);
        Map<String, Decimal> bookings = BusinessHealthData.bookingsByMonth(BusinessHealthData.wonOpportunities(ctx, from16));
        Map<String, Decimal> billed = BusinessHealthData.billedByMonth(ctx, from16);
        Map<String, Decimal> cost = BusinessHealthData.clientCostByMonth(tcs);
        List<pse__Proj__c> projects = BusinessHealthData.activeClientProjects(ctx);
        List<Contact> resources = BusinessHealthData.activeResources(ctx);
        Map<Id, Contact> billableStaff = BusinessHealthData.internalBillable(resources, tcs, ctx.asOfDate);

        Decimal delivered3 = BusinessHealthData.sumLast(delivered, keys16, 3);
        Decimal bookings3 = BusinessHealthData.sumLast(bookings, keys16, 3);
        Decimal avgMonthly = delivered3 / 3;

        // 1. Book-to-bill (trailing 3 months), with a 6-month rolling trend.
        List<Decimal> b2bRolling = BusinessHealthData.tail(BusinessHealthData.rollingRatio(bookings, delivered, keys16, 3), TREND_MONTHS);
        Decimal b2b = BusinessHealthModel.ratio(bookings3, delivered3);
        page.addKpi(new BusinessHealthModel.Kpi('bookToBill', 'Book-to-bill (T3M)', b2b == null ? null : b2b.setScale(2), 'ratio'))
            .target(ctx.num(s.Book_To_Bill_Target__c, 1.1), 'higher', 0.1)
            .note('New bookings / delivered revenue, trailing 3 complete months. Below 1.0 for several months is an early warning.')
            .trend(trendLabels, b2bRolling);

        // 2. Backlog runway.
        Decimal backlog = BusinessHealthData.backlog(projects);
        Decimal runway = BusinessHealthModel.ratio(backlog, avgMonthly);
        page.addKpi(new BusinessHealthModel.Kpi('backlogRunway', 'Backlog runway', runway == null ? null : runway.setScale(1), 'months'))
            .target(ctx.num(s.Backlog_Runway_Target__c, 4), 'higher', 0.25)
            .note(BusinessHealthModel.formatValue(backlog, 'currency') + ' contracted but unbilled across ' + projects.size() +
                ' active client projects, / average monthly delivered revenue (T3M).');

        // 3. Gross margin.
        List<Decimal> marginTrend = BusinessHealthData.marginSeries(delivered, cost, trendKeys);
        page.addKpi(new BusinessHealthModel.Kpi('grossMargin', 'Delivery gross margin (T3M)', BusinessHealthData.marginPct(delivered, cost, keys3), 'percent'))
            .target(ctx.num(s.Gross_Margin_Target__c, 40), 'higher', 0.15)
            .note('(Delivered revenue - labor cost of all hours on client projects) / delivered revenue.')
            .trend(trendLabels, marginTrend);

        // 4. Billable utilization.
        List<Decimal> utilTrend = BusinessHealthData.utilizationSeries(tcs, billableStaff.keySet(), trendKeys, ctx.hoursPerWeek());
        List<Decimal> util3 = BusinessHealthData.utilizationSeries(tcs, billableStaff.keySet(), keys3, ctx.hoursPerWeek());
        page.addKpi(new BusinessHealthModel.Kpi('utilization', 'Billable utilization (T3M)', average(util3), 'percent'))
            .target(ctx.num(s.Delivery_Utilization_Target__c, 75), 'higher', 0.1)
            .note(billableStaff.size() + ' internal delivery resources; billable hours / ' + ctx.hoursPerWeek().setScale(0) + ' hrs per week.')
            .trend(trendLabels, utilTrend);

        // 5. Cash: unbilled WIP (days) and DSO.
        List<Decimal> wip = BusinessHealthData.unbilledWip(tcs, ctx.asOfDate);
        Decimal wipDays = BusinessHealthModel.ratio(wip[0], delivered3 / 91);
        page.addKpi(new BusinessHealthModel.Kpi('unbilledWipDays', 'Unbilled WIP', wipDays == null ? null : wipDays.setScale(0), 'days'))
            .target(ctx.num(s.Unbilled_WIP_Days_Target__c, 10), 'lower', 0.5)
            .note(BusinessHealthModel.formatValue(wip[0], 'currency') + ' of approved billable time from the last ' +
                BusinessHealthData.WIP_WINDOW_DAYS + ' days not yet billed, in days of average revenue.');
        if (wip[1] > 0) {
            page.signal(BusinessHealthModel.STATUS_WARN, BusinessHealthModel.formatValue(wip[1], 'currency') +
                ' of approved billable time older than ' + BusinessHealthData.WIP_WINDOW_DAYS +
                ' days is still flagged unbilled in PSA. Bill it, write it off, or correct the Billed flag.');
        }
        page.addKpi(new BusinessHealthModel.Kpi('dso', 'DSO', null, 'days'))
            .markUnavailable('Needs invoice payment dates. Billing Events here record invoicing but not cash receipt. Connect accounting (e.g. QuickBooks) payments to enable.');

        // 6. Attrition.
        List<Contact> left = BusinessHealthData.departures(ctx, ctx.asOfDate.addMonths(-12));
        Integer internalHeadcount = 0;
        for (Contact c : resources) {
            if (!c.pse__External_Resource__c) {
                internalHeadcount++;
            }
        }
        page.addKpi(new BusinessHealthModel.Kpi('attrition', 'Attrition (T12M)', BusinessHealthData.attritionPct(left.size(), internalHeadcount), 'percent'))
            .target(ctx.num(s.Attrition_Target__c, 12), 'lower', 0.25)
            .note(left.size() + ' departures vs ' + internalHeadcount + ' current internal resources. Voluntary vs involuntary is not recorded.');

        // 7. Client concentration (T12M).
        Map<Id, String> names = new Map<Id, String>();
        Map<Id, Decimal> byAccount = BusinessHealthData.deliveredByAccount(tcs, ms, ctx.windowStart(12), ctx.windowEnd(), names);
        page.addKpi(new BusinessHealthModel.Kpi('concentration', 'Top-5 client share (T12M)', BusinessHealthData.topShare(byAccount, 5), 'percent'))
            .target(ctx.num(s.Concentration_Threshold__c, 35), 'lower', 0.15)
            .note(byAccount.size() + ' clients billed in the trailing 12 months.');

        // 8. Recurring revenue share and growth.
        Map<String, Decimal> recurring = BusinessHealthData.recurringByMonth(tcs, ms);
        Decimal recurring3 = BusinessHealthData.sumLast(recurring, keys16, 3);
        Decimal recurringPrior = 0;
        for (Integer i = 0; i < 3; i++) {
            // Same three months, one year earlier: keys16[1..3] when keys16 is 16 long.
            recurringPrior += BusinessHealthData.nz(recurring.get(keys16[keys16.size() - 15 + i]));
        }
        List<Decimal> recurringShareTrend = new List<Decimal>();
        for (String k : trendKeys) {
            recurringShareTrend.add(BusinessHealthModel.pct(BusinessHealthData.nz(recurring.get(k)), BusinessHealthData.nz(delivered.get(k))));
        }
        page.addKpi(new BusinessHealthModel.Kpi('recurringShare', 'Recurring revenue share (T3M)', BusinessHealthModel.pct(recurring3, delivered3), 'percent'))
            .target(ctx.num(s.Recurring_Revenue_Target__c, 25), 'higher', 0.2)
            .note('Managed services and subscription work as a share of delivered revenue.')
            .trend(trendLabels, recurringShareTrend);
        Decimal recurringGrowth = recurringPrior == 0 ? null : BusinessHealthModel.pct(recurring3 - recurringPrior, recurringPrior);
        page.addKpi(new BusinessHealthModel.Kpi('recurringGrowth', 'Recurring revenue growth (YoY)', recurringGrowth, 'percent'))
            .target(ctx.num(s.Revenue_Growth_Target__c, 15), 'higher', 0.5)
            .note(BusinessHealthModel.formatValue(recurring3, 'currency') + ' last 3 months vs ' +
                BusinessHealthModel.formatValue(recurringPrior, 'currency') + ' in the same months a year earlier.');

        // Charts.
        page.charts.add(
            new BusinessHealthModel.Chart('revenueMix', 'Bookings, delivered and billed revenue', 'bar', 'currency')
                .labels(labels12)
                .addSeries('Bookings', BusinessHealthData.series(bookings, keys12))
                .addSeries('Delivered', BusinessHealthData.series(delivered, keys12))
                .addSeries('Billed', BusinessHealthData.series(billed, keys12))
        );
        BusinessHealthModel.Chart b2bChart = new BusinessHealthModel.Chart('bookToBillTrend', 'Book-to-bill, trailing 3 months', 'line', 'ratio')
            .labels(labels12)
            .addSeries('Book-to-bill', BusinessHealthData.tail(BusinessHealthData.rollingRatio(bookings, delivered, keys16, 3), 12))
            .target(ctx.num(s.Book_To_Bill_Target__c, 1.1), 'Target');
        page.charts.add(b2bChart);
        BusinessHealthModel.Chart utilChart = new BusinessHealthModel.Chart('utilizationTrend', 'Billable utilization by month', 'line', 'percent')
            .labels(labels12)
            .addSeries('Utilization', BusinessHealthData.utilizationSeries(tcs, billableStaff.keySet(), keys12, ctx.hoursPerWeek()))
            .target(ctx.num(s.Delivery_Utilization_Target__c, 75), 'Target');
        page.charts.add(utilChart);
        BusinessHealthModel.Chart marginChart = new BusinessHealthModel.Chart('marginTrend', 'Delivery gross margin by month', 'line', 'percent')
            .labels(labels12)
            .addSeries('Gross margin', BusinessHealthData.marginSeries(delivered, cost, keys12))
            .target(ctx.num(s.Gross_Margin_Target__c, 40), 'Target');
        page.charts.add(marginChart);

        // Scorecard: each trended KPI, current vs 1, 3 and 5 months earlier.
        BusinessHealthModel.Table scorecard = new BusinessHealthModel.Table(
            'scorecard',
            'Month-over-month scorecard',
            'Each metric by complete month, oldest on the right. Status compares the latest month with target.'
        )
            .col('metric', 'Metric', 'text')
            .col('m0', trendLabels[TREND_MONTHS - 1], 'text')
            .col('m1', trendLabels[TREND_MONTHS - 2], 'text')
            .col('m3', trendLabels[TREND_MONTHS - 4], 'text')
            .col('m5', trendLabels[0], 'text')
            .col('target', 'Target', 'text')
            .col('status', 'Status', 'status');
        for (BusinessHealthModel.Kpi k : page.kpis) {
            if (k.trend == null || k.trend.size() < TREND_MONTHS) {
                continue;
            }
            Decimal latest = k.trend[TREND_MONTHS - 1];
            scorecard.rows.add(
                new Map<String, Object>{
                    'metric' => k.label.replace(' (T3M)', ''),
                    'm0' => BusinessHealthModel.formatValue(latest, k.format),
                    'm1' => BusinessHealthModel.formatValue(k.trend[TREND_MONTHS - 2], k.format),
                    'm3' => BusinessHealthModel.formatValue(k.trend[TREND_MONTHS - 4], k.format),
                    'm5' => BusinessHealthModel.formatValue(k.trend[0], k.format),
                    'target' => k.targetLabel,
                    'status' => BusinessHealthModel.evaluate(latest, k.target, k.direction, 0.1)
                }
            );
        }
        page.tables.add(scorecard);

        page.signalMissedKpis();
        if (b2bRolling.size() >= 3) {
            Integer below = 0;
            for (Integer i = b2bRolling.size() - 3; i < b2bRolling.size(); i++) {
                if (b2bRolling[i] != null && b2bRolling[i] < 1) {
                    below++;
                }
            }
            if (below == 3) {
                page.signal(BusinessHealthModel.STATUS_BAD, 'Book-to-bill has been below 1.0 for three consecutive months, so the backlog is shrinking.');
            }
        }
        page.dataGaps.add('DSO and AR aging need invoice payment dates, which are not stored in Salesforce today.');
        page.dataGaps.add('Attrition cannot be split voluntary vs involuntary: PSA Employment Status is not populated.');
        return page;
    }

    private static Decimal average(List<Decimal> values) {
        Decimal total = 0;
        Integer n = 0;
        for (Decimal v : values) {
            if (v != null) {
                total += v;
                n++;
            }
        }
        return n == 0 ? null : (total / n).setScale(1);
    }
}
