/**
 * @group BusinessHealth
 *
 * @description Financial Performance: bookings vs delivered vs billed revenue, gross
 * margin by project / practice / client (firm averages hide unprofitable work), rate
 * realization against the standard rate card, revenue per billable consultant, and
 * the cash side - unbilled WIP, billed-not-invoiced, and AR in collections.
 */
public with sharing class BusinessHealthFinancePage implements BusinessHealthPageBuilder {
    private static final Decimal MATERIAL_PROJECT_AMOUNT = 5000;
    private static final Decimal MIN_BILLABLE_HOURS = 80;

    private class Agg {
        Id id;
        String name;
        String account;
        String practice;
        String billingType;
        Decimal revenue = 0;
        Decimal cost = 0;
        Decimal billableHours = 0;
        Decimal nonBillableHours = 0;
        Decimal standardValue = 0;
        Decimal unbilled = 0;
        Date oldestUnbilled;

        Decimal marginPct() {
            return BusinessHealthModel.pct(revenue - cost, revenue);
        }
    }

    public BusinessHealthModel.HealthPage build(BusinessHealthContext ctx) {
        BusinessHealthModel.HealthPage page = new BusinessHealthModel.HealthPage(
            'finance',
            'Financial Performance',
            'Where the money is made and lost, and how much of it has turned into cash.',
            'Directors'
        );
        Business_Health_Goal_Set__c s = ctx.goals;
        Decimal marginTarget = ctx.num(s.Gross_Margin_Target__c, 40);
        Decimal marginFloor = ctx.num(s.Gross_Margin_Floor__c, 30);
        List<String> keys12 = ctx.completeMonthKeys(12);
        List<String> labels12 = ctx.completeMonthLabels(12);
        Date from12 = ctx.windowStart(12);
        Date to12 = ctx.windowEnd();

        List<BusinessHealthData.TimecardFact> allTcs = BusinessHealthData.timecards(ctx, from12);
        List<BusinessHealthData.MilestoneFact> ms = BusinessHealthData.milestoneRevenue(ctx, from12);
        List<Opportunity> won = BusinessHealthData.wonOpportunities(ctx, from12);
        Map<String, Decimal> delivered = BusinessHealthData.deliveredByMonth(allTcs, ms);
        Map<String, Decimal> bookings = BusinessHealthData.bookingsByMonth(won);
        Map<String, Decimal> billed = BusinessHealthData.billedByMonth(ctx, from12);
        Map<String, Decimal> cost = BusinessHealthData.clientCostByMonth(allTcs);
        Map<String, Decimal> rates = BusinessHealthData.standardRates();
        // Billable consultants = anyone (employee or subcontractor) who logged at least
        // MIN_BILLABLE_HOURS billable hours in the window - billable goals are too
        // sparsely populated to define the population.
        Map<Id, Decimal> billableHoursByResource = new Map<Id, Decimal>();
        for (BusinessHealthData.TimecardFact f : allTcs) {
            if (f.endDate <= to12) {
                BusinessHealthData.add(billableHoursByResource, f.resourceId, f.billableHours);
            }
        }
        Integer billableConsultants = 0;
        for (Decimal h : billableHoursByResource.values()) {
            if (h >= MIN_BILLABLE_HOURS) {
                billableConsultants++;
            }
        }

        // ---- per project / client / practice / role aggregation ------------------
        Map<Id, Agg> byProject = new Map<Id, Agg>();
        Map<Id, Agg> byClient = new Map<Id, Agg>();
        Map<String, Agg> byPractice = new Map<String, Agg>();
        Map<String, Agg> byRole = new Map<String, Agg>();
        Decimal realizedRevenue = 0;
        Decimal realizedStandard = 0;
        Decimal effectiveStandard = 0;
        Date wipCutoff = ctx.asOfDate.addDays(-BusinessHealthData.WIP_WINDOW_DAYS);
        for (BusinessHealthData.TimecardFact f : allTcs) {
            if (!f.clientProject) {
                continue;
            }
            Boolean inWindow = f.endDate <= to12;
            Decimal stdRate = f.assignmentRole == null ? null : rates.get(BusinessHealthData.normalizeRole(f.assignmentRole));
            List<Agg> targets = new List<Agg>{
                project(byProject, f.projectId, f.projectName, f.accountName, f.practiceName, f.billingType),
                keyed(byClient, f.accountId, f.accountName),
                named(byPractice, f.practiceName)
            };
            if (inWindow) {
                for (Agg a : targets) {
                    a.revenue += f.revenue;
                    a.cost += f.cost;
                    a.billableHours += f.billableHours;
                    a.nonBillableHours += f.hours - f.billableHours;
                }
            }
            if (f.unbilled && f.endDate > wipCutoff) {
                Agg p = targets[0];
                p.unbilled += f.revenue;
                p.oldestUnbilled = p.oldestUnbilled == null || f.endDate < p.oldestUnbilled ? f.endDate : p.oldestUnbilled;
            }
            // Rate realization: T&M work with a known standard rate for its role.
            if (inWindow && stdRate != null && f.billingType != 'Fixed Price') {
                Agg r = named(byRole, f.assignmentRole);
                r.revenue += f.revenue;
                r.billableHours += f.billableHours;
                r.nonBillableHours += f.hours - f.billableHours;
                r.standardValue += f.billableHours * stdRate;
                realizedRevenue += f.revenue;
                realizedStandard += f.billableHours * stdRate;
                effectiveStandard += f.hours * stdRate;
            }
        }
        for (BusinessHealthData.MilestoneFact m : ms) {
            if (m.actualDate > to12) {
                continue;
            }
            for (Agg a : new List<Agg>{
                project(byProject, m.projectId, m.projectName, m.accountName, m.practiceName, 'Fixed Price'),
                keyed(byClient, m.accountId, m.accountName),
                named(byPractice, m.practiceName)
            }) {
                a.revenue += m.amount;
            }
        }

        // ---- KPIs -------------------------------------------------------------------
        Decimal bookings12 = BusinessHealthData.sumLast(bookings, keys12, 12);
        Decimal delivered12 = BusinessHealthData.sumLast(delivered, keys12, 12);
        Decimal billed12 = BusinessHealthData.sumLast(billed, keys12, 12);
        page.addKpi(new BusinessHealthModel.Kpi('bookings', 'Bookings (T12M)', bookings12, 'currency')).note('Closed Won Opportunity Amount.');
        BusinessHealthModel.Kpi deliveredKpi = page.addKpi(new BusinessHealthModel.Kpi('delivered', 'Delivered revenue (T12M)', delivered12, 'currency'))
            .note('Recognized-revenue proxy: T&M billable time + approved fixed-fee milestones.');
        if (s.Annual_Revenue_Target__c != null && s.Annual_Revenue_Target__c > 0) {
            deliveredKpi.target(s.Annual_Revenue_Target__c, 'higher', 0.1);
        }
        page.addKpi(new BusinessHealthModel.Kpi('billed', 'Billed revenue (T12M)', billed12, 'currency')).note('Released Billing Events.');
        page.addKpi(new BusinessHealthModel.Kpi('grossMargin', 'Delivery gross margin (T12M)', BusinessHealthData.marginPct(delivered, cost, keys12), 'percent'))
            .target(marginTarget, 'higher', 0.15)
            .note('Labor cost includes non-billable hours on client projects, so write-offs show up here.');
        page.addKpi(new BusinessHealthModel.Kpi('rateRealization', 'Rate realization (T12M)', BusinessHealthModel.pct(realizedRevenue, realizedStandard), 'percent'))
            .target(ctx.num(s.Rate_Realization_Target__c, 90), 'higher', 0.1)
            .note('Effective bill rate on billed T&M hours / Default Rate Card rate for the assignment role. Exposes discounting.');
        page.addKpi(new BusinessHealthModel.Kpi('effectiveRealization', 'Realization incl. non-billable', BusinessHealthModel.pct(realizedRevenue, effectiveStandard), 'percent'))
            .target(ctx.num(s.Rate_Realization_Target__c, 90) - 10, 'higher', 0.1)
            .note('Same, but every hour on client T&M projects is valued at standard rate, so non-billable hours count as write-offs.');
        Decimal revPerConsultant = billableConsultants == 0 ? null : (delivered12 / billableConsultants).setScale(0);
        Decimal avgStdRate = BusinessHealthData.averageStandardRate();
        Decimal potential = ctx.hoursPerWeek() * 52 * ctx.num(s.Delivery_Utilization_Target__c, 75) / 100 * avgStdRate;
        page.addKpi(new BusinessHealthModel.Kpi('revenuePerConsultant', 'Revenue per billable consultant', revPerConsultant, 'currency'))
            .target(potential.setScale(0), 'higher', 0.2)
            .note(billableConsultants + ' people (employees and subcontractors) with ' + MIN_BILLABLE_HOURS.setScale(0) +
                '+ billable hours. Target = utilization target x ' +
                ctx.hoursPerWeek().setScale(0) + ' hrs x 52 weeks x average standard rate ($' + avgStdRate.setScale(0) + ').');

        List<Decimal> wip = BusinessHealthData.unbilledWip(allTcs, ctx.asOfDate);
        Decimal delivered3 = BusinessHealthData.sumLast(delivered, keys12, 3);
        Decimal wipDays = BusinessHealthModel.ratio(wip[0], delivered3 / 91);
        page.addKpi(new BusinessHealthModel.Kpi('unbilledWip', 'Unbilled WIP', wip[0], 'currency'))
            .target(ctx.num(s.Unbilled_WIP_Days_Target__c, 10) * delivered3 / 91, 'lower', 0.5)
            .note((wipDays == null ? '' : wipDays.setScale(0) + ' days of revenue. ') + 'Approved billable time from the last ' +
                BusinessHealthData.WIP_WINDOW_DAYS + ' days not yet billed.');

        List<AggregateResult> notInvoiced = ctx.aggregate(
            'SELECT SUM(pse__Summary_Amount__c) amt, COUNT(Id) cnt FROM pse__Billing_Event__c' +
                ' WHERE pse__Is_Released__c = true AND pse__Invoiced__c = false AND pse__Date__c <= :asOf' +
                ctx.practiceClause('pse__Project__r.pse__Practice__c')
        );
        Decimal billedNotInvoiced = notInvoiced.isEmpty() ? 0 : BusinessHealthData.nz((Decimal) notInvoiced[0].get('amt'));
        page.addKpi(new BusinessHealthModel.Kpi('billedNotInvoiced', 'Billed, not invoiced', billedNotInvoiced, 'currency'))
            .target(0, 'lower', 0)
            .note('Released Billing Events without an invoice. Cash that has not been asked for yet.');

        List<AggregateResult> collections = [
            SELECT SUM(CollectionAmount__c) amt, COUNT(Id) cnt
            FROM Account_Collection__c
            WHERE Status__c = 'In Collections'
            WITH USER_MODE
        ];
        Decimal inCollections = collections.isEmpty() ? 0 : BusinessHealthData.nz((Decimal) collections[0].get('amt'));
        page.addKpi(new BusinessHealthModel.Kpi('inCollections', 'AR in collections', inCollections, 'currency'))
            .note((collections.isEmpty() ? 0 : (Integer) collections[0].get('cnt')) + ' Account Collection records In Collections (firm-wide).');
        page.addKpi(new BusinessHealthModel.Kpi('dso', 'DSO', null, 'days'))
            .markUnavailable('Needs invoice payment dates, which are not stored in Salesforce today. Connect accounting payments to enable DSO and AR aging.');

        // ---- charts -----------------------------------------------------------------
        page.charts.add(
            new BusinessHealthModel.Chart('revenueMix', 'Bookings, delivered and billed revenue', 'bar', 'currency')
                .labels(labels12)
                .addSeries('Bookings', BusinessHealthData.series(bookings, keys12))
                .addSeries('Delivered', BusinessHealthData.series(delivered, keys12))
                .addSeries('Billed', BusinessHealthData.series(billed, keys12))
        );
        page.charts.add(
            new BusinessHealthModel.Chart('marginTrend', 'Delivery gross margin by month', 'line', 'percent')
                .labels(labels12)
                .addSeries('Gross margin', BusinessHealthData.marginSeries(delivered, cost, keys12))
                .target(marginTarget, 'Target')
        );
        List<String> practiceNames = new List<String>();
        List<Decimal> practiceMargins = new List<Decimal>();
        for (Agg a : byPractice.values()) {
            if (a.revenue >= MATERIAL_PROJECT_AMOUNT) {
                practiceNames.add(a.name);
                practiceMargins.add(a.marginPct());
            }
        }
        page.charts.add(
            new BusinessHealthModel.Chart('marginByPractice', 'Gross margin by practice (T12M)', 'hbar', 'percent')
                .labels(practiceNames)
                .addSeries('Gross margin', practiceMargins)
                .target(marginTarget, 'Target')
        );

        // ---- tables -----------------------------------------------------------------
        BusinessHealthModel.Table projectTable = marginTable('projectMargin', 'Project margin, lowest first (T12M)',
            'Client projects with at least $5K of revenue or cost in the window. Red is below the ' + marginFloor.setScale(0) + '% floor.')
            .link('name', 'Project', 'id');
        projectTable.col('account', 'Account', 'text').col('practice', 'Practice', 'text').col('billingType', 'Billing', 'text');
        // The link column replaces marginTable's plain 'name' column (same key).
        reorder(projectTable, new List<String>{ 'name', 'account', 'practice', 'billingType', 'revenue', 'cost', 'margin', 'marginPct', 'billableHours', 'nonBillableHours', 'status' });
        Integer belowFloor = 0;
        Decimal belowFloorRevenue = 0;
        for (Agg a : byProject.values()) {
            if (a.revenue < MATERIAL_PROJECT_AMOUNT && a.cost < MATERIAL_PROJECT_AMOUNT) {
                continue;
            }
            Map<String, Object> row = marginRow(a, marginTarget, marginFloor);
            row.put('id', a.id);
            row.put('account', a.account);
            row.put('practice', a.practice);
            row.put('billingType', a.billingType);
            projectTable.rows.add(row);
            if (row.get('status') == BusinessHealthModel.STATUS_BAD) {
                belowFloor++;
                belowFloorRevenue += a.revenue;
            }
        }
        BusinessHealthModel.sortRowsAscending(projectTable.rows, 'marginPct');
        projectTable.rows = BusinessHealthModel.first(projectTable.rows, 30);
        page.tables.add(projectTable);

        BusinessHealthModel.Table clientTable = marginTable('clientMargin', 'Client margin, largest clients (T12M)', null);
        for (Agg a : byClient.values()) {
            if (a.revenue > 0) {
                clientTable.rows.add(marginRow(a, marginTarget, marginFloor));
            }
        }
        BusinessHealthModel.sortRows(clientTable.rows, 'revenue');
        clientTable.rows = BusinessHealthModel.first(clientTable.rows, 15);
        page.tables.add(clientTable);

        BusinessHealthModel.Table practiceTable = marginTable('practiceMargin', 'Practice margin (T12M)', null);
        for (Agg a : byPractice.values()) {
            practiceTable.rows.add(marginRow(a, marginTarget, marginFloor));
        }
        BusinessHealthModel.sortRows(practiceTable.rows, 'revenue');
        page.tables.add(practiceTable);

        BusinessHealthModel.Table roleTable = new BusinessHealthModel.Table('rateRealization', 'Rate realization by assignment role (T12M)',
            'T&M billable hours vs the Default Rate Card price for the role.')
            .col('name', 'Role', 'text')
            .col('billableHours', 'Billable hrs', 'hours')
            .col('nonBillableHours', 'Non-billable hrs', 'hours')
            .col('effectiveRate', 'Effective rate', 'currency')
            .col('standardRate', 'Standard rate', 'currency')
            .col('realization', 'Realization', 'percent')
            .col('status', 'Status', 'status');
        Decimal realizationTarget = ctx.num(s.Rate_Realization_Target__c, 90);
        for (Agg a : byRole.values()) {
            Decimal realization = BusinessHealthModel.pct(a.revenue, a.standardValue);
            roleTable.rows.add(
                new Map<String, Object>{
                    'name' => a.name,
                    'billableHours' => a.billableHours.setScale(0),
                    'nonBillableHours' => a.nonBillableHours.setScale(0),
                    'effectiveRate' => a.billableHours == 0 ? null : (a.revenue / a.billableHours).setScale(0),
                    'standardRate' => a.billableHours == 0 ? null : (a.standardValue / a.billableHours).setScale(0),
                    'realization' => realization,
                    'status' => BusinessHealthModel.evaluate(realization, realizationTarget, 'higher', 0.1)
                }
            );
        }
        BusinessHealthModel.sortRows(roleTable.rows, 'billableHours');
        page.tables.add(roleTable);

        BusinessHealthModel.Table wipTable = new BusinessHealthModel.Table('unbilledWip', 'Unbilled WIP by project',
            'Approved billable time from the last ' + BusinessHealthData.WIP_WINDOW_DAYS + ' days that has not been billed.')
            .link('name', 'Project', 'id')
            .col('account', 'Account', 'text')
            .col('unbilled', 'Unbilled', 'currency')
            .col('oldest', 'Oldest week ending', 'date');
        for (Agg a : byProject.values()) {
            if (a.unbilled > 0) {
                wipTable.rows.add(new Map<String, Object>{ 'id' => a.id, 'name' => a.name, 'account' => a.account, 'unbilled' => a.unbilled, 'oldest' => a.oldestUnbilled });
            }
        }
        BusinessHealthModel.sortRows(wipTable.rows, 'unbilled');
        wipTable.rows = BusinessHealthModel.first(wipTable.rows, 20);
        page.tables.add(wipTable);

        // ---- signals ----------------------------------------------------------------
        page.signalMissedKpis();
        if (belowFloor > 0) {
            page.signal(BusinessHealthModel.STATUS_BAD, belowFloor + ' client projects (' + BusinessHealthModel.formatValue(belowFloorRevenue, 'currency') +
                ' revenue) are below the ' + marginFloor.setScale(0) + '% margin floor.');
        }
        if (wip[1] > 0) {
            page.signal(BusinessHealthModel.STATUS_WARN, BusinessHealthModel.formatValue(wip[1], 'currency') + ' of approved billable time older than ' +
                BusinessHealthData.WIP_WINDOW_DAYS + ' days is still flagged unbilled in PSA.');
        }
        page.dataGaps.add('DSO and AR aging need payment dates from the accounting system.');
        page.dataGaps.add('Margin uses labor cost only (timecard cost rates). Expenses and overhead are excluded. Confirm PSA cost rates are fully loaded (salary, benefits, taxes).');
        return page;
    }

    // ---- helpers ------------------------------------------------------------------

    private static Agg project(Map<Id, Agg> m, Id id, String name, String account, String practice, String billingType) {
        Agg a = keyed(m, id, name);
        a.account = account;
        a.practice = practice;
        a.billingType = a.billingType == null ? billingType : a.billingType;
        return a;
    }

    private static Agg keyed(Map<Id, Agg> m, Id id, String name) {
        if (!m.containsKey(id)) {
            Agg a = new Agg();
            a.id = id;
            // A lookup whose parent isn't visible (or wasn't copied to a sandbox) has an Id but no name.
            a.name = name == null ? (id == null ? '(none)' : '(record not visible)') : name;
            m.put(id, a);
        }
        return m.get(id);
    }

    private static Agg named(Map<String, Agg> m, String name) {
        String key = name == null ? 'Unassigned' : name;
        if (!m.containsKey(key)) {
            Agg a = new Agg();
            a.name = key;
            m.put(key, a);
        }
        return m.get(key);
    }

    private static BusinessHealthModel.Table marginTable(String key, String title, String subtitle) {
        return new BusinessHealthModel.Table(key, title, subtitle)
            .col('name', 'Name', 'text')
            .col('revenue', 'Revenue', 'currency')
            .col('cost', 'Labor cost', 'currency')
            .col('margin', 'Margin', 'currency')
            .col('marginPct', 'Margin %', 'percent')
            .col('billableHours', 'Billable hrs', 'hours')
            .col('nonBillableHours', 'Non-billable hrs', 'hours')
            .col('status', 'Status', 'status');
    }

    private static Map<String, Object> marginRow(Agg a, Decimal target, Decimal floor) {
        Decimal pct = a.marginPct();
        String status = pct == null
            ? (a.cost > 0 ? BusinessHealthModel.STATUS_BAD : BusinessHealthModel.STATUS_NEUTRAL)
            : (pct < floor ? BusinessHealthModel.STATUS_BAD : (pct < target ? BusinessHealthModel.STATUS_WARN : BusinessHealthModel.STATUS_GOOD));
        return new Map<String, Object>{
            'name' => a.name,
            'revenue' => a.revenue.setScale(0),
            'cost' => a.cost.setScale(0),
            'margin' => (a.revenue - a.cost).setScale(0),
            'marginPct' => pct,
            'billableHours' => a.billableHours.setScale(0),
            'nonBillableHours' => a.nonBillableHours.setScale(0),
            'status' => status
        };
    }

    private static void reorder(BusinessHealthModel.Table t, List<String> order) {
        Map<String, BusinessHealthModel.Column> byKey = new Map<String, BusinessHealthModel.Column>();
        for (BusinessHealthModel.Column c : t.columns) {
            byKey.put(c.key, c);
        }
        List<BusinessHealthModel.Column> ordered = new List<BusinessHealthModel.Column>();
        for (String k : order) {
            if (byKey.containsKey(k)) {
                ordered.add(byKey.remove(k));
            }
        }
        t.columns = ordered;
    }
}
