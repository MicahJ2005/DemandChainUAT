/**
 * @group BusinessHealth
 *
 * @description My Work - Solution Architect: the pre-sales pipeline the running user
 * supports (Opportunity Sales Engineer or SOW Author), SOW timing, the win rate on their
 * supported deals against the firm, supported bookings against an optional personal
 * target, and their own billable utilization and schedule as a delivery architect.
 */
public with sharing class MyWorkSolutionArchitectPage implements BusinessHealthPageBuilder {
    private static final Integer SOW_DUE_DAYS = 14;

    public BusinessHealthModel.HealthPage build(BusinessHealthContext ctx) {
        BusinessHealthModel.HealthPage page = new BusinessHealthModel.HealthPage(
            'my-architect',
            'My deals & solutions',
            'Which deals need my solution or SOW next, how are my supported deals converting, and how is my delivery time?',
            'Solution Architect'
        );
        Id meUser = ctx.userId;
        Date asOf = ctx.asOfDate;
        Date from12 = asOf.addMonths(-12);
        Date pStart = ctx.goalPeriodStart();
        Decimal target = ctx.userGoalSet == null ? null : ctx.userGoalSet.Bookings_Quota__c;

        // ---- supported deals -------------------------------------------------------------
        List<Opportunity> open = [
            SELECT Id, Name, Account.Name, Owner.Name, StageName, Amount, Probability, CloseDate, Expected_SOW_Delivery_Date__c,
                Internal_SOW_Approval_Date__c, SOWLink__c, Sales_Engineer__c, SOW_Author__c
            FROM Opportunity
            WHERE IsClosed = false AND (Sales_Engineer__c = :meUser OR SOW_Author__c = :meUser)
            WITH USER_MODE
            ORDER BY CloseDate
            LIMIT 300
        ];
        Decimal openAmount = 0;
        Decimal weighted = 0;
        Integer sowDue = 0;
        Integer sowLate = 0;
        Map<String, Decimal> byStage = new Map<String, Decimal>();
        BusinessHealthModel.Table deals = new BusinessHealthModel.Table('supportedDeals', 'Deals I am supporting',
            'Open opportunities where you are Sales Engineer or SOW Author, soonest SOW or close date first.')
            .link('name', 'Opportunity', 'id')
            .col('account', 'Account', 'text')
            .col('owner', 'AE', 'text')
            .col('stage', 'Stage', 'text')
            .col('amount', 'Amount', 'currency')
            .col('closeDate', 'Close', 'date')
            .col('sowDue', 'SOW due', 'date')
            .col('myRole', 'My role', 'text')
            .col('flag', 'Flag', 'text');
        for (Opportunity o : open) {
            Decimal amt = BusinessHealthData.nz(o.Amount);
            openAmount += amt;
            weighted += amt * BusinessHealthData.nz(o.Probability) / 100;
            BusinessHealthData.add(byStage, o.StageName, amt);
            List<String> flags = new List<String>();
            Boolean sowPending = o.Internal_SOW_Approval_Date__c == null;
            if (sowPending && o.Expected_SOW_Delivery_Date__c != null) {
                if (o.Expected_SOW_Delivery_Date__c < asOf) {
                    sowLate++;
                    flags.add('SOW overdue');
                } else if (o.Expected_SOW_Delivery_Date__c <= asOf.addDays(SOW_DUE_DAYS)) {
                    sowDue++;
                    flags.add('SOW due in ' + asOf.daysBetween(o.Expected_SOW_Delivery_Date__c) + 'd');
                }
            }
            if (o.CloseDate < asOf) {
                flags.add('Close date passed');
            }
            List<String> roles = new List<String>();
            if (o.Sales_Engineer__c == meUser) {
                roles.add('Sales Engineer');
            }
            if (o.SOW_Author__c == meUser) {
                roles.add('SOW Author');
            }
            deals.rows.add(
                new Map<String, Object>{
                    'id' => o.Id,
                    'name' => o.Name,
                    'account' => o.Account == null ? null : o.Account.Name,
                    'owner' => o.Owner == null ? null : o.Owner.Name,
                    'stage' => o.StageName,
                    'amount' => amt,
                    'closeDate' => o.CloseDate,
                    'sowDue' => o.Expected_SOW_Delivery_Date__c,
                    'myRole' => String.join(roles, ' & '),
                    'flag' => String.join(flags, ' · '),
                    'sortKey' => MyWorkSupport.daysFrom(asOf, o.Expected_SOW_Delivery_Date__c != null && sowPending ? o.Expected_SOW_Delivery_Date__c : o.CloseDate)
                }
            );
        }
        BusinessHealthModel.sortRowsAscending(deals.rows, 'sortKey');
        deals.metric = 'supportedPipeline';

        // ---- closed supported deals: win rate, bookings, time to SOW ---------------------------
        Integer won = 0;
        Integer lost = 0;
        Decimal bookedPeriod = 0;
        Decimal sowDays = 0;
        Integer sowCount = 0;
        Map<String, Decimal> wonByQuarter = new Map<String, Decimal>();
        Map<String, Decimal> lostByQuarter = new Map<String, Decimal>();
        Date closedFrom = pStart < from12 ? pStart : from12;
        for (Opportunity o : [
            SELECT IsWon, Amount, CloseDate, CreatedDate, Internal_SOW_Approval_Date__c
            FROM Opportunity
            WHERE IsClosed = true AND CloseDate > :closedFrom AND CloseDate <= :asOf AND (Sales_Engineer__c = :meUser OR SOW_Author__c = :meUser)
            WITH USER_MODE
        ]) {
            String q = o.CloseDate.year() + ' Q' + ((o.CloseDate.month() - 1) / 3 + 1);
            if (o.IsWon && o.CloseDate >= pStart) {
                bookedPeriod += BusinessHealthData.nz(o.Amount);
            }
            if (o.CloseDate <= from12) {
                continue;
            }
            if (o.IsWon) {
                won++;
                BusinessHealthData.add(wonByQuarter, q, 1);
            } else {
                lost++;
                BusinessHealthData.add(lostByQuarter, q, 1);
            }
            if (o.Internal_SOW_Approval_Date__c != null) {
                sowDays += Math.max(0, o.CreatedDate.date().daysBetween(o.Internal_SOW_Approval_Date__c));
                sowCount++;
            }
        }
        List<AggregateResult> firm = [
            SELECT IsWon w, COUNT(Id) c
            FROM Opportunity
            WHERE IsClosed = true AND CloseDate > :from12 AND CloseDate <= :asOf
            WITH USER_MODE
            GROUP BY IsWon
        ];
        Integer firmWon = 0;
        Integer firmTotal = 0;
        for (AggregateResult ar : firm) {
            firmTotal += (Integer) ar.get('c');
            if ((Boolean) ar.get('w')) {
                firmWon += (Integer) ar.get('c');
            }
        }

        // ---- KPIs ----------------------------------------------------------------------------------
        page.addKpi(new BusinessHealthModel.Kpi('supportedPipeline', 'Pipeline I am supporting', openAmount, 'currency'))
            .note(open.size() + ' open deals; ' + BusinessHealthModel.formatValue(weighted, 'currency') + ' weighted.');
        BusinessHealthModel.Kpi bookings = page.addKpi(new BusinessHealthModel.Kpi('supportedBookings', 'Supported bookings this period',
            target == null || target == 0 ? bookedPeriod : BusinessHealthModel.pct(bookedPeriod, target), target == null || target == 0 ? 'currency' : 'percent'));
        if (target != null && target > 0) {
            Decimal elapsed = (Decimal.valueOf(pStart.daysBetween(asOf) + 1) / (pStart.daysBetween(ctx.goalPeriodEnd()) + 1) * 100).setScale(1);
            bookings.target(elapsed, 'higher', 0.15)
                .note(BusinessHealthModel.formatValue(bookedPeriod, 'currency') + ' of a ' + BusinessHealthModel.formatValue(target, 'currency') + ' target since ' + pStart.format() + '.');
        } else {
            bookings.note('Closed Won deals you supported since ' + pStart.format() + '. No personal target is set.');
        }
        Decimal winRate = BusinessHealthModel.pct(won, won + lost);
        page.addKpi(new BusinessHealthModel.Kpi('supportedWinRate', 'Win rate on my deals (T12M)', winRate, 'percent'))
            .target(BusinessHealthModel.pct(firmWon, firmTotal), 'higher', 0.15)
            .note(won + ' won / ' + (won + lost) + ' closed. Target is the firm win rate.');
        page.addKpi(new BusinessHealthModel.Kpi('sowDue', 'SOWs due in ' + SOW_DUE_DAYS + ' days', sowDue, 'number'))
            .note('Supported deals with an expected SOW delivery date coming up and no internal SOW approval yet.');
        page.addKpi(new BusinessHealthModel.Kpi('sowLate', 'SOWs overdue', sowLate, 'number'))
            .target(0, 'lower', 0)
            .note('Expected SOW delivery date has passed with no internal approval.');
        page.addKpi(new BusinessHealthModel.Kpi('timeToSow', 'Average days to SOW approval', sowCount == 0 ? null : (sowDays / sowCount).setScale(0), 'days'))
            .note('Opportunity created to internal SOW approval, closed deals in the last 12 months.');

        // ---- delivery time (if a PSA resource) -------------------------------------------------------
        Contact me = MyWorkSupport.resourceFor(meUser);
        if (me != null) {
            MyWorkSupport.addUtilization(page, ctx, me, false);
        } else {
            page.dataGaps.add('No PSA resource Contact is linked to you, so delivery utilization is not shown.');
        }

        // ---- charts --------------------------------------------------------------------------------
        List<String> stages = new List<String>(byStage.keySet());
        stages.sort();
        List<Decimal> stageAmounts = new List<Decimal>();
        for (String st : stages) {
            stageAmounts.add(byStage.get(st).setScale(0));
        }
        page.charts.add(
            new BusinessHealthModel.Chart('supportedByStage', 'Supported pipeline by stage', 'hbar', 'currency')
                .labels(stages)
                .addSeries('Amount', stageAmounts)
                .metric('supportedPipeline')
        );
        List<String> quarters = new List<String>();
        for (Date d = asOf.addMonths(-11).toStartOfMonth(); d <= asOf; d = d.addMonths(1)) {
            String q = d.year() + ' Q' + ((d.month() - 1) / 3 + 1);
            if (!quarters.contains(q)) {
                quarters.add(q);
            }
        }
        page.charts.add(
            new BusinessHealthModel.Chart('supportedOutcomes', 'My supported deals closed, by quarter', 'bar', 'number')
                .labels(quarters)
                .addSeries('Won', BusinessHealthData.series(wonByQuarter, quarters))
                .addSeries('Lost', BusinessHealthData.series(lostByQuarter, quarters))
                .metric('supportedWinRate')
        );
        page.tables.add(deals);

        page.signalMissedKpis();
        page.briefMetrics = new List<String>{ 'supportedPipeline', 'sowLate', 'supportedWinRate', 'util4' };
        return page;
    }
}
