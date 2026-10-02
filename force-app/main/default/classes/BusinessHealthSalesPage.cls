/**
 * @group BusinessHealth
 *
 * @description Sales & Pipeline (leading indicators): pipeline coverage for the next
 * two quarters, win rate, deal size and sales cycle by service line (Opportunity
 * Cloud(s) Included), book-to-bill, backlog runway, and the share of bookings sourced
 * by or co-sold with Salesforce AEs.
 */
public with sharing class BusinessHealthSalesPage implements BusinessHealthPageBuilder {
    private static final Integer PIPELINE_MONTHS = 6;

    private class Bucket {
        String name;
        Integer won = 0;
        Integer lost = 0;
        Decimal wonAmount = 0;
        Decimal cycleDays = 0;
        Decimal openAmount = 0;
        Decimal weighted = 0;

        Bucket(String name) {
            this.name = name;
        }

        Decimal winRate() {
            return BusinessHealthModel.pct(won, won + lost);
        }

        Map<String, Object> row() {
            return new Map<String, Object>{
                'name' => name,
                'won' => won,
                'lost' => lost,
                'winRate' => winRate(),
                'bookings' => wonAmount,
                'avgDeal' => won == 0 ? null : (wonAmount / won).setScale(0),
                'cycle' => won == 0 ? null : (cycleDays / won).setScale(0),
                'openAmount' => openAmount,
                'weighted' => weighted.setScale(0)
            };
        }
    }

    public BusinessHealthModel.HealthPage build(BusinessHealthContext ctx) {
        BusinessHealthModel.HealthPage page = new BusinessHealthModel.HealthPage(
            'sales',
            'Sales & Pipeline',
            'Leading indicators: will there be enough work in the next two quarters, and where is it coming from?',
            'Directors'
        );
        Business_Health_Goal_Set__c s = ctx.goals;
        Date asOf = ctx.asOfDate;
        Date from12 = asOf.addMonths(-12);
        Date from24 = asOf.addMonths(-24);
        Date pipelineEnd = asOf.addMonths(PIPELINE_MONTHS);

        // Closed opportunities, trailing 24 months (current + prior year comparison).
        ctx.bind('closedFrom', from24);
        List<Opportunity> closed = (List<Opportunity>) ctx.query(
            'SELECT Id, Name, Amount, IsWon, CloseDate, CreatedDate, Type, LeadSource, AccountAE__c, Salesforce_ACV__c,' +
                ' Cloud_s_Included__c, LostReason__c' +
                ' FROM Opportunity WHERE IsClosed = true AND CloseDate > :closedFrom AND CloseDate <= :asOf' +
                ctx.practiceClause('pse__Practice__c')
        );
        // Open pipeline: everything still open (overdue close dates reported separately).
        ctx.bind('pipelineEnd', pipelineEnd);
        List<Opportunity> open = (List<Opportunity>) ctx.query(
            'SELECT Id, Name, Account.Name, Amount, Probability, CloseDate, StageName, Owner.Name, LeadSource, AccountAE__c,' +
                ' Salesforce_ACV__c, Cloud_s_Included__c, Stage_Age__c, CreatedDate' +
                ' FROM Opportunity WHERE IsClosed = false AND CloseDate <= :pipelineEnd' +
                ctx.practiceClause('pse__Practice__c') +
                ' ORDER BY CloseDate'
        );

        // Revenue baseline for target, book-to-bill and runway.
        Date from12Months = ctx.windowStart(12);
        List<BusinessHealthData.TimecardFact> tcs = BusinessHealthData.timecards(ctx, from12Months);
        List<BusinessHealthData.MilestoneFact> ms = BusinessHealthData.milestoneRevenue(ctx, from12Months);
        Map<String, Decimal> delivered = BusinessHealthData.deliveredByMonth(tcs, ms);
        List<String> keys12 = ctx.completeMonthKeys(12);
        List<String> labels12 = ctx.completeMonthLabels(12);
        Decimal delivered12 = BusinessHealthData.sumLast(delivered, keys12, 12);
        Decimal delivered3 = BusinessHealthData.sumLast(delivered, keys12, 3);
        Decimal annualTarget = s.Annual_Revenue_Target__c != null && s.Annual_Revenue_Target__c > 0
            ? s.Annual_Revenue_Target__c
            : delivered12 * (1 + ctx.num(s.Revenue_Growth_Target__c, 15) / 100);
        Decimal targetNext2Q = annualTarget / 2;
        Decimal backlog = BusinessHealthData.backlog(BusinessHealthData.activeClientProjects(ctx));

        // ---- aggregate closed deals ------------------------------------------------
        Map<String, Bucket> byLine = new Map<String, Bucket>();
        Map<String, Bucket> bySource = new Map<String, Bucket>();
        for (String src : new List<String>{ 'Sourced by Salesforce', 'Salesforce AE involved', 'Own team' }) {
            bySource.put(src, new Bucket(src));
        }
        Bucket current = new Bucket('Trailing 12 months');
        Bucket prior = new Bucket('Prior 12 months');
        Map<String, Integer> lostReasons = new Map<String, Integer>();
        Map<String, Decimal> lostReasonAmount = new Map<String, Decimal>();
        Map<String, Map<String, Decimal>> bookingsBySourceMonth = new Map<String, Map<String, Decimal>>();
        for (String src : bySource.keySet()) {
            bookingsBySourceMonth.put(src, new Map<String, Decimal>());
        }
        Decimal wonBookings3 = 0;
        Date from3 = ctx.windowStart(3);
        for (Opportunity o : closed) {
            Boolean isCurrent = o.CloseDate > from12;
            Bucket period = isCurrent ? current : prior;
            Decimal amount = BusinessHealthData.nz(o.Amount);
            Decimal cycle = o.CreatedDate.date().daysBetween(o.CloseDate);
            if (o.IsWon) {
                period.won++;
                period.wonAmount += amount;
                period.cycleDays += Math.max(0, cycle);
            } else {
                period.lost++;
            }
            if (o.IsWon && o.CloseDate >= from3 && o.CloseDate <= ctx.windowEnd()) {
                wonBookings3 += amount;
            }
            if (!isCurrent) {
                continue;
            }
            List<Bucket> buckets = new List<Bucket>{ bySource.get(BusinessHealthData.sourcing(o)) };
            for (String line : BusinessHealthData.serviceLines(o)) {
                if (!byLine.containsKey(line)) {
                    byLine.put(line, new Bucket(line));
                }
                buckets.add(byLine.get(line));
            }
            for (Bucket b : buckets) {
                if (o.IsWon) {
                    b.won++;
                    b.wonAmount += amount;
                    b.cycleDays += Math.max(0, cycle);
                } else {
                    b.lost++;
                }
            }
            if (o.IsWon) {
                BusinessHealthData.add(bookingsBySourceMonth.get(BusinessHealthData.sourcing(o)), BusinessHealthContext.monthKey(o.CloseDate), amount);
            } else {
                String reason = String.isBlank(o.LostReason__c) ? 'Not recorded' : o.LostReason__c;
                lostReasons.put(reason, (lostReasons.containsKey(reason) ? lostReasons.get(reason) : 0) + 1);
                BusinessHealthData.add(lostReasonAmount, reason, amount);
            }
        }

        // ---- open pipeline ----------------------------------------------------------
        Decimal weighted = 0;
        Decimal unweighted = 0;
        Integer overdueCount = 0;
        Decimal overdueAmount = 0;
        Map<String, Decimal> weightedByMonth = new Map<String, Decimal>();
        Map<String, Decimal> unweightedByMonth = new Map<String, Decimal>();
        BusinessHealthModel.Table topOpen = new BusinessHealthModel.Table(
            'openPipeline',
            'Pipeline closing in the next two quarters',
            'Open opportunities by weighted value (Amount x Probability). Overdue close dates are excluded here and counted separately.'
        )
            .link('name', 'Opportunity', 'id')
            .col('account', 'Account', 'text')
            .col('stage', 'Stage', 'text')
            .col('closeDate', 'Close', 'date')
            .col('amount', 'Amount', 'currency')
            .col('probability', 'Prob.', 'percent')
            .col('weighted', 'Weighted', 'currency')
            .col('source', 'Source', 'text')
            .col('owner', 'Owner', 'text')
            .col('stageAge', 'Days in stage', 'number');
        List<Map<String, Object>> openRows = new List<Map<String, Object>>();
        for (Opportunity o : open) {
            Decimal amount = BusinessHealthData.nz(o.Amount);
            if (o.CloseDate < asOf) {
                overdueCount++;
                overdueAmount += amount;
                continue;
            }
            Decimal w = amount * BusinessHealthData.nz(o.Probability) / 100;
            weighted += w;
            unweighted += amount;
            String mk = BusinessHealthContext.monthKey(o.CloseDate);
            BusinessHealthData.add(weightedByMonth, mk, w);
            BusinessHealthData.add(unweightedByMonth, mk, amount);
            bySource.get(BusinessHealthData.sourcing(o)).openAmount += amount;
            bySource.get(BusinessHealthData.sourcing(o)).weighted += w;
            for (String line : BusinessHealthData.serviceLines(o)) {
                if (!byLine.containsKey(line)) {
                    byLine.put(line, new Bucket(line));
                }
                byLine.get(line).openAmount += amount;
                byLine.get(line).weighted += w;
            }
            openRows.add(
                new Map<String, Object>{
                    'id' => o.Id,
                    'name' => o.Name,
                    'account' => o.Account == null ? null : o.Account.Name,
                    'stage' => o.StageName,
                    'closeDate' => o.CloseDate,
                    'amount' => amount,
                    'probability' => o.Probability,
                    'weighted' => w.setScale(0),
                    'source' => BusinessHealthData.sourcing(o),
                    'owner' => o.Owner == null ? null : o.Owner.Name,
                    'stageAge' => o.Stage_Age__c
                }
            );
        }
        BusinessHealthModel.sortRows(openRows, 'weighted');
        topOpen.rows = BusinessHealthModel.first(openRows, 25);

        // ---- KPIs ---------------------------------------------------------------------
        Decimal coverage = BusinessHealthModel.ratio(weighted, targetNext2Q);
        page.addKpi(new BusinessHealthModel.Kpi('pipelineCoverage', 'Pipeline coverage (next 2Q)', coverage == null ? null : coverage.setScale(2), 'ratio'))
            .target(ctx.num(s.Pipeline_Coverage_Target__c, 3), 'higher', 0.25)
            .note(BusinessHealthModel.formatValue(weighted, 'currency') + ' weighted pipeline closing by ' + pipelineEnd.format() +
                ' / ' + BusinessHealthModel.formatValue(targetNext2Q, 'currency') + ' revenue target for the period' +
                (s.Annual_Revenue_Target__c == null ? ' (derived: T12M delivered revenue + growth target).' : '.'));
        Decimal gap = Math.max(targetNext2Q - backlog, 0);
        Decimal gapCoverage = gap == 0 ? null : (weighted / gap).setScale(2);
        page.addKpi(new BusinessHealthModel.Kpi('gapCoverage', 'Coverage of revenue gap', gapCoverage, 'ratio'))
            .target(ctx.num(s.Gap_Coverage_Target__c, 1.5), 'higher', 0.25)
            .note('Weighted pipeline / (next-2Q target - ' + BusinessHealthModel.formatValue(backlog, 'currency') +
                ' backlog already contracted). Below 1.0 means backlog plus likely wins will not reach target.');
        page.addKpi(new BusinessHealthModel.Kpi('winRate', 'Win rate (T12M)', current.winRate(), 'percent'))
            .target(ctx.num(s.Win_Rate_Target__c, 35), 'higher', 0.15)
            .note(current.won + ' won / ' + (current.won + current.lost) + ' closed. Prior 12 months: ' +
                BusinessHealthModel.formatValue(prior.winRate(), 'percent') + '.');
        Decimal avgDeal = current.won == 0 ? null : (current.wonAmount / current.won).setScale(0);
        Decimal priorDeal = prior.won == 0 ? null : (prior.wonAmount / prior.won).setScale(0);
        page.addKpi(new BusinessHealthModel.Kpi('avgDeal', 'Average deal size (T12M)', avgDeal, 'currency'))
            .target(priorDeal, 'higher', 0.1)
            .note('Won deals. Target is last year\'s ' + BusinessHealthModel.formatValue(priorDeal, 'currency') + '.');
        Decimal cycle = current.won == 0 ? null : (current.cycleDays / current.won).setScale(0);
        Decimal priorCycle = prior.won == 0 ? null : (prior.cycleDays / prior.won).setScale(0);
        page.addKpi(new BusinessHealthModel.Kpi('salesCycle', 'Sales cycle (T12M)', cycle, 'days'))
            .target(priorCycle, 'lower', 0.15)
            .note('Created to Closed Won, average. Target is last year\'s ' + BusinessHealthModel.formatValue(priorCycle, 'days') + '.');
        Decimal b2b = BusinessHealthModel.ratio(wonBookings3, delivered3);
        page.addKpi(new BusinessHealthModel.Kpi('bookToBill', 'Book-to-bill (T3M)', b2b == null ? null : b2b.setScale(2), 'ratio'))
            .target(ctx.num(s.Book_To_Bill_Target__c, 1.1), 'higher', 0.1)
            .note(BusinessHealthModel.formatValue(wonBookings3, 'currency') + ' booked / ' + BusinessHealthModel.formatValue(delivered3, 'currency') + ' delivered.');
        Decimal runway = BusinessHealthModel.ratio(backlog, delivered3 / 3);
        page.addKpi(new BusinessHealthModel.Kpi('backlogRunway', 'Backlog runway', runway == null ? null : runway.setScale(1), 'months'))
            .target(ctx.num(s.Backlog_Runway_Target__c, 4), 'higher', 0.25)
            .note('Contracted but unbilled revenue / average monthly delivered revenue.');
        Decimal sfBookings = bySource.get('Sourced by Salesforce').wonAmount + bySource.get('Salesforce AE involved').wonAmount;
        page.addKpi(new BusinessHealthModel.Kpi('salesforceShare', 'Salesforce-sourced/influenced bookings', BusinessHealthModel.pct(sfBookings, current.wonAmount), 'percent'))
            .target(ctx.num(s.Salesforce_Sourced_Target__c, 30), 'higher', 0.2)
            .note('Lead Source "Referral - Salesforce", or a Salesforce AE / Salesforce ACV on the deal. Both a growth lever and a dependency risk.');
        page.addKpi(new BusinessHealthModel.Kpi('overduePipeline', 'Overdue pipeline', overdueAmount, 'currency'))
            .target(0, 'lower', 0)
            .note(overdueCount + ' open opportunities with a close date already past. Update or close them so coverage is trustworthy.');

        // ---- charts -----------------------------------------------------------------
        List<String> futureKeys = new List<String>();
        List<String> futureLabels = new List<String>();
        for (Integer i = 0; i < PIPELINE_MONTHS; i++) {
            Date m = asOf.toStartOfMonth().addMonths(i);
            futureKeys.add(BusinessHealthContext.monthKey(m));
            futureLabels.add(BusinessHealthContext.monthLabel(m));
        }
        page.charts.add(
            new BusinessHealthModel.Chart('pipelineByMonth', 'Open pipeline by close month', 'bar', 'currency')
                .labels(futureLabels)
                .addSeries('Unweighted', BusinessHealthData.series(unweightedByMonth, futureKeys))
                .addSeries('Weighted', BusinessHealthData.series(weightedByMonth, futureKeys))
        );
        BusinessHealthModel.Chart sourceChart = new BusinessHealthModel.Chart('bookingsBySource', 'Bookings by source', 'bar', 'currency').labels(labels12);
        for (String src : bySource.keySet()) {
            sourceChart.addSeries(src, BusinessHealthData.series(bookingsBySourceMonth.get(src), keys12));
        }
        page.charts.add(sourceChart);
        List<Bucket> lines = byLine.values();
        List<String> lineNames = new List<String>();
        List<Decimal> lineWinRates = new List<Decimal>();
        for (Bucket b : lines) {
            if (b.won + b.lost >= 3) {
                lineNames.add(b.name);
                lineWinRates.add(b.winRate());
            }
        }
        page.charts.add(
            new BusinessHealthModel.Chart('winRateByLine', 'Win rate by service line (T12M, 3+ decisions)', 'hbar', 'percent')
                .labels(lineNames)
                .addSeries('Win rate', lineWinRates)
                .target(ctx.num(s.Win_Rate_Target__c, 35), 'Target')
        );

        // ---- tables -----------------------------------------------------------------
        BusinessHealthModel.Table lineTable = bucketTable('serviceLines', 'Service line performance (T12M)',
            'From Opportunity Cloud(s) Included; a multi-cloud deal counts toward each of its clouds.');
        List<Map<String, Object>> lineRows = new List<Map<String, Object>>();
        for (Bucket b : lines) {
            lineRows.add(b.row());
        }
        BusinessHealthModel.sortRows(lineRows, 'bookings');
        lineTable.rows = lineRows;
        page.tables.add(lineTable);

        BusinessHealthModel.Table sourceTable = bucketTable('sourcing', 'Salesforce relationship (T12M)',
            'How much of the business comes through Salesforce AEs versus your own team.');
        for (Bucket b : bySource.values()) {
            sourceTable.rows.add(b.row());
        }
        page.tables.add(sourceTable);
        page.tables.add(topOpen);

        BusinessHealthModel.Table lostTable = new BusinessHealthModel.Table('lostReasons', 'Why deals were lost (T12M)', null)
            .col('reason', 'Lost reason', 'text')
            .col('count', 'Deals', 'number')
            .col('amount', 'Amount', 'currency');
        for (String r : lostReasons.keySet()) {
            lostTable.rows.add(new Map<String, Object>{ 'reason' => r, 'count' => lostReasons.get(r), 'amount' => lostReasonAmount.get(r) });
        }
        BusinessHealthModel.sortRows(lostTable.rows, 'count');
        page.tables.add(lostTable);

        // ---- signals & gaps ---------------------------------------------------------
        page.signalMissedKpis();
        Decimal sfShare = BusinessHealthModel.pct(sfBookings, current.wonAmount);
        if (sfShare != null && sfShare > 60) {
            page.signal(BusinessHealthModel.STATUS_WARN, 'Over 60% of bookings depend on Salesforce AEs, a concentration risk if AE coverage changes.');
        }
        if (lostReasons.containsKey('Not recorded') && lostReasons.get('Not recorded') > current.lost / 2) {
            page.signal(BusinessHealthModel.STATUS_INFO, 'Most lost deals have no Lost Reason, so loss patterns cannot be analyzed. Make it required at Closed Lost.');
        }
        if (byLine.containsKey('Unspecified')) {
            page.dataGaps.add(byLine.get('Unspecified').won + byLine.get('Unspecified').lost +
                ' closed deals have no Cloud(s) Included, so their service line is unknown.');
        }
        page.dataGaps.add('Cloud(s) Included has no FSC or Agentforce values. Add them to track those service lines.');
        return page;
    }

    private static BusinessHealthModel.Table bucketTable(String key, String title, String subtitle) {
        return new BusinessHealthModel.Table(key, title, subtitle)
            .col('name', 'Segment', 'text')
            .col('won', 'Won', 'number')
            .col('lost', 'Lost', 'number')
            .col('winRate', 'Win rate', 'percent')
            .col('bookings', 'Bookings', 'currency')
            .col('avgDeal', 'Avg deal', 'currency')
            .col('cycle', 'Cycle (days)', 'number')
            .col('openAmount', 'Open pipeline', 'currency')
            .col('weighted', 'Weighted', 'currency');
    }
}
