/**
 * @group BusinessHealth
 *
 * @description Client Portfolio: revenue concentration (top-5 share), client retention
 * and net revenue retention year over year, expansion revenue from existing clients,
 * and recurring (managed services / subscription) revenue share and growth.
 */
public with sharing class BusinessHealthPortfolioPage implements BusinessHealthPageBuilder {
    private static final Decimal RETENTION_TARGET = 80;
    private static final Decimal NRR_TARGET = 100;
    private static final Decimal EXPANSION_TARGET = 50;
    private static final Decimal DECLINE_THRESHOLD = -30;

    public BusinessHealthModel.HealthPage build(BusinessHealthContext ctx) {
        BusinessHealthModel.HealthPage page = new BusinessHealthModel.HealthPage(
            'portfolio',
            'Client Portfolio',
            'How concentrated, sticky and recurring is the revenue base?',
            'Directors'
        );
        Business_Health_Goal_Set__c s = ctx.goals;
        Date cur0 = ctx.windowStart(12);
        Date cur1 = ctx.windowEnd();
        Date prior0 = cur0.addMonths(-12);
        Date prior1 = cur0.addDays(-1);

        List<BusinessHealthData.TimecardFact> tcs = BusinessHealthData.timecards(ctx, prior0);
        List<BusinessHealthData.MilestoneFact> ms = BusinessHealthData.milestoneRevenue(ctx, prior0);
        Map<Id, String> names = new Map<Id, String>();
        Map<Id, Decimal> current = BusinessHealthData.deliveredByAccount(tcs, ms, cur0, cur1, names);
        Map<Id, Decimal> prior = BusinessHealthData.deliveredByAccount(tcs, ms, prior0, prior1, names);

        // Recurring revenue by account and by month.
        Map<Id, Decimal> recurringByAccount = new Map<Id, Decimal>();
        for (BusinessHealthData.TimecardFact f : tcs) {
            if (f.recurring && f.endDate >= cur0 && f.endDate <= cur1) {
                BusinessHealthData.add(recurringByAccount, f.accountId, f.revenue);
            }
        }
        for (BusinessHealthData.MilestoneFact m : ms) {
            if (m.recurring && m.actualDate >= cur0 && m.actualDate <= cur1) {
                BusinessHealthData.add(recurringByAccount, m.accountId, m.amount);
            }
        }
        List<String> keys24 = ctx.completeMonthKeys(24);
        List<String> keys12 = BusinessHealthData.tailLabels(keys24, 12);
        List<String> labels12 = ctx.completeMonthLabels(12);
        Map<String, Decimal> delivered = BusinessHealthData.deliveredByMonth(tcs, ms);
        Map<String, Decimal> recurring = BusinessHealthData.recurringByMonth(tcs, ms);

        Decimal currentTotal = sum(current);
        Decimal priorTotal = sum(prior);

        // ---- concentration ------------------------------------------------------------
        Decimal top5 = BusinessHealthData.topShare(current, 5);
        Id largestId = null;
        for (Id a : current.keySet()) {
            if (largestId == null || current.get(a) > current.get(largestId)) {
                largestId = a;
            }
        }
        page.addKpi(new BusinessHealthModel.Kpi('top5Share', 'Top-5 client share (T12M)', top5, 'percent'))
            .target(ctx.num(s.Concentration_Threshold__c, 35), 'lower', 0.15)
            .note('Above roughly 30-40% the firm carries real concentration risk.');
        page.addKpi(new BusinessHealthModel.Kpi('largestShare', 'Largest client share',
            largestId == null ? null : BusinessHealthModel.pct(current.get(largestId), currentTotal), 'percent'))
            .target(ctx.num(s.Largest_Client_Threshold__c, 15), 'lower', 0.3)
            .note(largestId == null ? null : names.get(largestId) + '.');
        page.addKpi(new BusinessHealthModel.Kpi('activeClients', 'Clients billed (T12M)', current.size(), 'number'))
            .target(prior.size(), 'higher', 0.1)
            .note(prior.size() + ' in the prior 12 months.');

        // ---- retention ------------------------------------------------------------------
        Integer retained = 0;
        Decimal retainedRevenue = 0;
        Integer newClients = 0;
        Decimal newClientRevenue = 0;
        for (Id a : prior.keySet()) {
            if (current.containsKey(a)) {
                retained++;
                retainedRevenue += current.get(a);
            }
        }
        for (Id a : current.keySet()) {
            if (!prior.containsKey(a)) {
                newClients++;
                newClientRevenue += current.get(a);
            }
        }
        page.addKpi(new BusinessHealthModel.Kpi('retention', 'Client retention (YoY)', BusinessHealthModel.pct(retained, prior.size()), 'percent'))
            .target(ctx.num(s.Retention_Target__c, RETENTION_TARGET), 'higher', 0.1)
            .note(retained + ' of ' + prior.size() + ' prior-year clients billed again this year.');
        page.addKpi(new BusinessHealthModel.Kpi('nrr', 'Net revenue retention', BusinessHealthModel.pct(retainedRevenue, priorTotal), 'percent'))
            .target(ctx.num(s.NRR_Target__c, NRR_TARGET), 'higher', 0.1)
            .note('This year\'s revenue from last year\'s clients / last year\'s total. Above 100% means existing clients are expanding.');
        page.addKpi(new BusinessHealthModel.Kpi('newClients', 'New clients (T12M)', newClients, 'number'))
            .note(BusinessHealthModel.formatValue(newClientRevenue, 'currency') + ' revenue from clients not billed in the prior year.');

        // ---- expansion bookings -----------------------------------------------------------
        Decimal existingBookings = 0;
        Decimal totalBookings = 0;
        Map<String, Decimal> existingByQuarter = new Map<String, Decimal>();
        Map<String, Decimal> newByQuarter = new Map<String, Decimal>();
        for (Opportunity o : BusinessHealthData.wonOpportunities(ctx, cur0)) {
            if (o.CloseDate > cur1) {
                continue;
            }
            Decimal amount = BusinessHealthData.nz(o.Amount);
            totalBookings += amount;
            String q = o.CloseDate.year() + ' Q' + ((o.CloseDate.month() - 1) / 3 + 1);
            if (BusinessHealthData.isExistingCustomer(o)) {
                existingBookings += amount;
                BusinessHealthData.add(existingByQuarter, q, amount);
            } else {
                BusinessHealthData.add(newByQuarter, q, amount);
            }
        }
        page.addKpi(new BusinessHealthModel.Kpi('expansionShare', 'Repeat & expansion bookings (T12M)', BusinessHealthModel.pct(existingBookings, totalBookings), 'percent'))
            .target(ctx.num(s.Expansion_Bookings_Target__c, EXPANSION_TARGET), 'higher', 0.2)
            .note(BusinessHealthModel.formatValue(existingBookings, 'currency') + ' of ' + BusinessHealthModel.formatValue(totalBookings, 'currency') +
                ' booked with existing clients (Opportunity Type "Existing Cust" or repeat lead source).');

        // ---- recurring ----------------------------------------------------------------------
        Decimal recurring12 = BusinessHealthData.sumLast(recurring, keys24, 12);
        Decimal recurringPrior = 0;
        for (Integer i = 0; i < 12; i++) {
            recurringPrior += BusinessHealthData.nz(recurring.get(keys24[i]));
        }
        page.addKpi(new BusinessHealthModel.Kpi('recurringShare', 'Recurring revenue share (T12M)', BusinessHealthModel.pct(recurring12, currentTotal), 'percent'))
            .target(ctx.num(s.Recurring_Revenue_Target__c, 25), 'higher', 0.2)
            .note('Managed services and subscription revenue. Smooths project swings and raises firm valuation.');
        page.addKpi(new BusinessHealthModel.Kpi('recurringGrowth', 'Recurring revenue growth (YoY)',
            recurringPrior == 0 ? null : BusinessHealthModel.pct(recurring12 - recurringPrior, recurringPrior), 'percent'))
            .target(ctx.num(s.Revenue_Growth_Target__c, 15), 'higher', 0.5)
            .note(BusinessHealthModel.formatValue(recurring12, 'currency') + ' vs ' + BusinessHealthModel.formatValue(recurringPrior, 'currency') + ' prior year.');

        // ---- charts -----------------------------------------------------------------------
        List<Id> ranked = rank(current);
        List<String> topNames = new List<String>();
        List<Decimal> topCurrent = new List<Decimal>();
        List<Decimal> topPrior = new List<Decimal>();
        for (Integer i = 0; i < Math.min(10, ranked.size()); i++) {
            Id a = ranked[i];
            topNames.add(label(names.get(a)));
            topCurrent.add(current.get(a).setScale(0));
            topPrior.add(BusinessHealthData.nz(prior.get(a)).setScale(0));
        }
        page.charts.add(
            new BusinessHealthModel.Chart('topClients', 'Top 10 clients: this year vs last year', 'hbar', 'currency')
                .labels(topNames)
                .addSeries('Trailing 12 months', topCurrent)
                .addSeries('Prior 12 months', topPrior)
        );
        List<Decimal> projectSeries = new List<Decimal>();
        for (String k : keys12) {
            projectSeries.add((BusinessHealthData.nz(delivered.get(k)) - BusinessHealthData.nz(recurring.get(k))).setScale(0));
        }
        page.charts.add(
            new BusinessHealthModel.Chart('recurringMix', 'Recurring vs project revenue by month', 'bar', 'currency')
                .labels(labels12)
                .addSeries('Recurring', BusinessHealthData.series(recurring, keys12))
                .addSeries('Project', projectSeries)
        );
        List<String> quarters = new List<String>();
        Date qd = cur0;
        while (qd <= cur1) {
            String q = qd.year() + ' Q' + ((qd.month() - 1) / 3 + 1);
            if (!quarters.contains(q)) {
                quarters.add(q);
            }
            qd = qd.addMonths(1);
        }
        page.charts.add(
            new BusinessHealthModel.Chart('bookingsNewVsExisting', 'Bookings: existing vs new clients', 'bar', 'currency')
                .labels(quarters)
                .addSeries('Existing clients', BusinessHealthData.series(existingByQuarter, quarters))
                .addSeries('New clients', BusinessHealthData.series(newByQuarter, quarters))
        );

        // ---- tables -----------------------------------------------------------------------
        Map<Id, Integer> activeProjects = new Map<Id, Integer>();
        for (pse__Proj__c p : BusinessHealthData.activeClientProjects(ctx)) {
            activeProjects.put(p.pse__Account__c, (activeProjects.containsKey(p.pse__Account__c) ? activeProjects.get(p.pse__Account__c) : 0) + 1);
        }
        Map<Id, Decimal> pipeline = new Map<Id, Decimal>();
        for (AggregateResult ar : ctx.aggregate(
            'SELECT AccountId acct, SUM(Amount) amt FROM Opportunity WHERE IsClosed = false AND CloseDate >= :asOf' +
                ctx.practiceClause('pse__Practice__c') +
                ' GROUP BY AccountId'
        )) {
            pipeline.put((Id) ar.get('acct'), (Decimal) ar.get('amt'));
        }
        BusinessHealthModel.Table clientTable = new BusinessHealthModel.Table('clients', 'Client portfolio (T12M)',
            'Largest clients first. Red means revenue fell more than 30% year over year.')
            .link('name', 'Client', 'id')
            .col('revenue', 'T12M revenue', 'currency')
            .col('share', 'Share', 'percent')
            .col('cumulative', 'Cumulative', 'percent')
            .col('prior', 'Prior 12M', 'currency')
            .col('growth', 'YoY', 'percent')
            .col('recurring', 'Recurring', 'currency')
            .col('projects', 'Active projects', 'number')
            .col('pipeline', 'Open pipeline', 'currency')
            .col('status', 'Trend', 'status');
        Decimal cumulative = 0;
        for (Integer i = 0; i < Math.min(25, ranked.size()); i++) {
            Id a = ranked[i];
            Decimal rev = current.get(a);
            cumulative += rev;
            Decimal growth = prior.containsKey(a) ? BusinessHealthModel.pct(rev - prior.get(a), prior.get(a)) : null;
            clientTable.rows.add(
                new Map<String, Object>{
                    'id' => a,
                    'name' => label(names.get(a)),
                    'revenue' => rev.setScale(0),
                    'share' => BusinessHealthModel.pct(rev, currentTotal),
                    'cumulative' => BusinessHealthModel.pct(cumulative, currentTotal),
                    'prior' => BusinessHealthData.nz(prior.get(a)).setScale(0),
                    'growth' => growth,
                    'recurring' => BusinessHealthData.nz(recurringByAccount.get(a)).setScale(0),
                    'projects' => activeProjects.containsKey(a) ? activeProjects.get(a) : 0,
                    'pipeline' => pipeline.get(a),
                    'status' => growth == null
                        ? BusinessHealthModel.STATUS_GOOD
                        : (growth < DECLINE_THRESHOLD ? BusinessHealthModel.STATUS_BAD : (growth < 0 ? BusinessHealthModel.STATUS_WARN : BusinessHealthModel.STATUS_GOOD))
                }
            );
        }
        page.tables.add(clientTable);

        BusinessHealthModel.Table atRisk = new BusinessHealthModel.Table('decliningClients', 'Declining or lapsed clients',
            'Prior-year clients (over $25K) whose revenue fell more than 30%, or stopped, with no active project to replace it.')
            .link('name', 'Client', 'id')
            .col('prior', 'Prior 12M', 'currency')
            .col('revenue', 'T12M revenue', 'currency')
            .col('growth', 'YoY', 'percent')
            .col('projects', 'Active projects', 'number')
            .col('pipeline', 'Open pipeline', 'currency');
        Decimal lapsedRevenue = 0;
        for (Id a : prior.keySet()) {
            Decimal p = prior.get(a);
            Decimal c = BusinessHealthData.nz(current.get(a));
            Decimal growth = BusinessHealthModel.pct(c - p, p);
            Boolean noActiveWork = !activeProjects.containsKey(a);
            if (p >= 25000 && growth != null && growth < DECLINE_THRESHOLD && (noActiveWork || c == 0)) {
                lapsedRevenue += p - c;
                atRisk.rows.add(
                    new Map<String, Object>{
                        'id' => a,
                        'name' => label(names.get(a)),
                        'prior' => p.setScale(0),
                        'revenue' => c.setScale(0),
                        'growth' => growth,
                        'projects' => activeProjects.containsKey(a) ? activeProjects.get(a) : 0,
                        'pipeline' => pipeline.get(a)
                    }
                );
            }
        }
        BusinessHealthModel.sortRows(atRisk.rows, 'prior');
        page.tables.add(atRisk);

        page.signalMissedKpis();
        if (!atRisk.rows.isEmpty()) {
            page.signal(BusinessHealthModel.STATUS_WARN, atRisk.rows.size() + ' former clients account for ' +
                BusinessHealthModel.formatValue(lapsedRevenue, 'currency') + ' of lost annual revenue with no active project. These are win-back targets.');
        }
        return page;
    }

    private static Decimal sum(Map<Id, Decimal> m) {
        Decimal total = 0;
        for (Decimal v : m.values()) {
            total += v;
        }
        return total;
    }

    private static List<Id> rank(Map<Id, Decimal> m) {
        List<BusinessHealthModel.RowSorter> sorters = new List<BusinessHealthModel.RowSorter>();
        for (Id a : m.keySet()) {
            sorters.add(new BusinessHealthModel.RowSorter(new Map<String, Object>{ 'id' => a, 'v' => m.get(a) }, 'v', true));
        }
        sorters.sort();
        List<Id> ids = new List<Id>();
        for (BusinessHealthModel.RowSorter r : sorters) {
            ids.add((Id) r.row.get('id'));
        }
        return ids;
    }

    private static String label(String name) {
        return name == null ? '(record not visible)' : name;
    }
}
