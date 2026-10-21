/**
 * @group BusinessHealth
 *
 * @description My Work - Account Executive: the running user's quota attainment (against
 * the pace the calendar implies), pipeline coverage of the remaining quota, deal hygiene,
 * win rate / cycle / deal size against the firm, campaign activity at the accounts they
 * own, leads to work and upcoming managed-services renewals.
 *
 * Quota comes from the user's personal goal set (Bookings Quota) over its effective
 * dates; without one, attainment is shown as unavailable and the period is the
 * calendar year.
 */
public with sharing class MyWorkAccountExecutivePage implements BusinessHealthPageBuilder {
    private static final Integer STALE_DAYS = 45;
    private static final Integer NEAR_CLOSE_DAYS = 90;
    private static final Integer CAMPAIGN_DAYS = 90;
    private static final Integer RENEWAL_DAYS = 120;
    private static final Integer PIPELINE_MONTHS = 6;

    public BusinessHealthModel.HealthPage build(BusinessHealthContext ctx) {
        BusinessHealthModel.HealthPage page = new BusinessHealthModel.HealthPage(
            'my-ae',
            'My pipeline & quota',
            'Am I on pace for my number, and which deals and accounts need me this week?',
            'Account Executive'
        );
        Id me = ctx.userId;
        Date asOf = ctx.asOfDate;
        Date pStart = ctx.goalPeriodStart();
        Date pEnd = ctx.goalPeriodEnd();
        Date from12 = asOf.addMonths(-12);
        Decimal quota = ctx.userGoalSet == null ? null : ctx.userGoalSet.Bookings_Quota__c;

        // ---- bookings this goal period ---------------------------------------------
        Decimal booked = 0;
        Integer bookedCount = 0;
        Map<String, Decimal> bookedByMonth = new Map<String, Decimal>();
        for (Opportunity o : [
            SELECT Amount, CloseDate
            FROM Opportunity
            WHERE OwnerId = :me AND IsWon = true AND CloseDate >= :pStart AND CloseDate <= :asOf
            WITH USER_MODE
        ]) {
            booked += BusinessHealthData.nz(o.Amount);
            bookedCount++;
            BusinessHealthData.add(bookedByMonth, BusinessHealthContext.monthKey(o.CloseDate), BusinessHealthData.nz(o.Amount));
        }

        // ---- my closed deals vs the firm, trailing 12 months -------------------------
        Integer myWon = 0;
        Integer myLost = 0;
        Decimal myWonAmount = 0;
        Decimal myCycleDays = 0;
        for (Opportunity o : [
            SELECT IsWon, Amount, CreatedDate, CloseDate
            FROM Opportunity
            WHERE OwnerId = :me AND IsClosed = true AND CloseDate > :from12 AND CloseDate <= :asOf
            WITH USER_MODE
        ]) {
            if (o.IsWon) {
                myWon++;
                myWonAmount += BusinessHealthData.nz(o.Amount);
                myCycleDays += Math.max(0, o.CreatedDate.date().daysBetween(o.CloseDate));
            } else {
                myLost++;
            }
        }
        Integer firmWon = 0;
        Integer firmLost = 0;
        Decimal firmWonAmount = 0;
        Decimal firmCycleDays = 0;
        for (Opportunity o : [
            SELECT IsWon, Amount, CreatedDate, CloseDate
            FROM Opportunity
            WHERE IsClosed = true AND CloseDate > :from12 AND CloseDate <= :asOf
            WITH USER_MODE
        ]) {
            if (o.IsWon) {
                firmWon++;
                firmWonAmount += BusinessHealthData.nz(o.Amount);
                firmCycleDays += Math.max(0, o.CreatedDate.date().daysBetween(o.CloseDate));
            } else {
                firmLost++;
            }
        }

        // ---- my open pipeline -----------------------------------------------------
        Date pipelineEnd = asOf.addMonths(PIPELINE_MONTHS);
        Decimal openAmount = 0;
        Decimal weighted6 = 0;
        Integer overdue = 0;
        Integer stale = 0;
        Set<Id> accountsWithOpenOpps = new Set<Id>();
        Map<String, Decimal> byStage = new Map<String, Decimal>();
        Map<String, Decimal> weightedByMonth = new Map<String, Decimal>();
        Map<String, Decimal> unweightedByMonth = new Map<String, Decimal>();
        BusinessHealthModel.Table pipeline = new BusinessHealthModel.Table('myPipeline', 'My open opportunities',
            'Soonest close date first. Stalled = no logged activity or stage change in ' + STALE_DAYS + ' days; it needs attention when the deal closes within ' + NEAR_CLOSE_DAYS + ' days.')
            .link('name', 'Opportunity', 'id')
            .col('account', 'Account', 'text')
            .col('stage', 'Stage', 'text')
            .col('amount', 'Amount', 'currency')
            .col('probability', 'Prob.', 'percent')
            .col('closeDate', 'Close', 'date')
            .col('idleDays', 'Days since activity or stage change', 'number')
            .col('nextStep', 'Next step', 'text')
            .col('flag', 'Flag', 'text');
        List<Opportunity> open = [
            SELECT Id, Name, AccountId, Account.Name, StageName, Amount, Probability, CloseDate, LastActivityDate, LastStageChangeDate, NextStep, CreatedDate
            FROM Opportunity
            WHERE OwnerId = :me AND IsClosed = false
            WITH USER_MODE
            ORDER BY CloseDate
            LIMIT 500
        ];
        for (Opportunity o : open) {
            Decimal amt = BusinessHealthData.nz(o.Amount);
            Decimal w = amt * BusinessHealthData.nz(o.Probability) / 100;
            openAmount += amt;
            accountsWithOpenOpps.add(o.AccountId);
            BusinessHealthData.add(byStage, o.StageName, amt);
            if (o.CloseDate >= asOf && o.CloseDate <= pipelineEnd) {
                weighted6 += w;
                String mk = BusinessHealthContext.monthKey(o.CloseDate);
                BusinessHealthData.add(weightedByMonth, mk, w);
                BusinessHealthData.add(unweightedByMonth, mk, amt);
            }
            // Last sign of life: logged activity or a stage change (many reps don't log tasks).
            Date lastTouch = o.CreatedDate.date();
            if (o.LastStageChangeDate != null && o.LastStageChangeDate.date() > lastTouch) {
                lastTouch = o.LastStageChangeDate.date();
            }
            if (o.LastActivityDate != null && o.LastActivityDate > lastTouch) {
                lastTouch = o.LastActivityDate;
            }
            Integer idle = lastTouch.daysBetween(asOf);
            Boolean stalled = idle > STALE_DAYS;
            List<String> flags = new List<String>();
            if (o.CloseDate < asOf) {
                overdue++;
                flags.add('Overdue close date');
            } else if (stalled && o.CloseDate <= asOf.addDays(NEAR_CLOSE_DAYS)) {
                stale++;
                flags.add('Closes in ' + asOf.daysBetween(o.CloseDate) + 'd but stalled ' + idle + 'd');
            } else if (stalled) {
                flags.add('Stalled ' + idle + 'd');
            } else if (o.CloseDate.year() == asOf.year() && o.CloseDate.month() == asOf.month()) {
                flags.add('Closing this month');
            }
            pipeline.rows.add(
                new Map<String, Object>{
                    'id' => o.Id,
                    'name' => o.Name,
                    'account' => o.Account == null ? null : o.Account.Name,
                    'stage' => o.StageName,
                    'amount' => amt,
                    'probability' => o.Probability,
                    'closeDate' => o.CloseDate,
                    'idleDays' => idle,
                    'nextStep' => o.NextStep == null ? null : o.NextStep.abbreviate(60),
                    'flag' => String.join(flags, ' · ')
                }
            );
        }

        // ---- KPIs -------------------------------------------------------------------
        Decimal elapsedPct = (Decimal.valueOf(pStart.daysBetween(asOf) + 1) / (pStart.daysBetween(pEnd) + 1) * 100).setScale(1);
        BusinessHealthModel.Kpi attainment = page.addKpi(new BusinessHealthModel.Kpi('quotaAttainment', 'Quota attainment',
            quota == null || quota == 0 ? null : BusinessHealthModel.pct(booked, quota), 'percent'));
        if (quota == null || quota == 0) {
            attainment.markUnavailable('No personal quota is set for you. Leadership adds one as a Business Health Goal Set with you as the User and a Bookings Quota.');
        } else {
            attainment.target(elapsedPct, 'higher', 0.15)
                .note(BusinessHealthModel.formatValue(booked, 'currency') + ' of ' + BusinessHealthModel.formatValue(quota, 'currency') +
                    ' booked. ' + elapsedPct.setScale(0) + '% of the period (' + pStart.format() + ' to ' + pEnd.format() + ') has passed, so that is the pace target.');
        }
        page.addKpi(new BusinessHealthModel.Kpi('bookings', 'Bookings this period', booked, 'currency'))
            .note(bookedCount + ' deals closed won since ' + pStart.format() + '.');
        Decimal remaining = quota == null ? null : Math.max(quota - booked, 0);
        BusinessHealthModel.Kpi coverage = page.addKpi(new BusinessHealthModel.Kpi('pipelineCoverage', 'Coverage of remaining quota',
            remaining == null || remaining == 0 ? null : (weighted6 / remaining).setScale(2), 'ratio'));
        if (remaining == null) {
            coverage.markUnavailable('Needs a personal quota.');
        } else if (remaining == 0) {
            coverage.markUnavailable('Quota already met for this period.');
        } else {
            coverage.target(ctx.num(ctx.goals.Pipeline_Coverage_Target__c, 3), 'higher', 0.25)
                .note(BusinessHealthModel.formatValue(weighted6, 'currency') + ' weighted pipeline closing in the next ' + PIPELINE_MONTHS +
                    ' months / ' + BusinessHealthModel.formatValue(remaining, 'currency') + ' still to book.');
        }
        page.addKpi(new BusinessHealthModel.Kpi('openOpps', 'Open opportunities', open.size(), 'number'))
            .note(BusinessHealthModel.formatValue(openAmount, 'currency') + ' total; ' + BusinessHealthModel.formatValue(weighted6, 'currency') +
                ' weighted in the next ' + PIPELINE_MONTHS + ' months.');
        Decimal myWinRate = BusinessHealthModel.pct(myWon, myWon + myLost);
        page.addKpi(new BusinessHealthModel.Kpi('winRate', 'My win rate (T12M)', myWinRate, 'percent'))
            .target(ctx.num(ctx.goals.Win_Rate_Target__c, 35), 'higher', 0.15)
            .note(myWon + ' won / ' + (myWon + myLost) + ' closed. Firm: ' + BusinessHealthModel.formatValue(BusinessHealthModel.pct(firmWon, firmWon + firmLost), 'percent') + '.');
        Decimal myCycle = myWon == 0 ? null : (myCycleDays / myWon).setScale(0);
        Decimal firmCycle = firmWon == 0 ? null : (firmCycleDays / firmWon).setScale(0);
        page.addKpi(new BusinessHealthModel.Kpi('salesCycle', 'My average sales cycle', myCycle, 'days'))
            .target(firmCycle, 'lower', 0.15)
            .note('Created to Closed Won, trailing 12 months. Target is the firm average.');
        Decimal myDeal = myWon == 0 ? null : (myWonAmount / myWon).setScale(0);
        Decimal firmDeal = firmWon == 0 ? null : (firmWonAmount / firmWon).setScale(0);
        page.addKpi(new BusinessHealthModel.Kpi('avgDeal', 'My average deal size', myDeal, 'currency'))
            .target(firmDeal, 'higher', 0.15)
            .note('Won deals, trailing 12 months. Target is the firm average.');
        page.addKpi(new BusinessHealthModel.Kpi('needsAttention', 'Deals needing attention', overdue + stale, 'number'))
            .target(0, 'lower', 0)
            .note(overdue + ' with a past close date and ' + stale + ' closing within ' + NEAR_CLOSE_DAYS + ' days with no activity or stage change in ' + STALE_DAYS + ' days.');

        // ---- campaign activity at my accounts -----------------------------------------
        Date campaignFrom = asOf.addDays(-CAMPAIGN_DAYS);
        BusinessHealthModel.Table campaigns = new BusinessHealthModel.Table('campaignActivity', 'Campaign responses at my accounts',
            'Contacts at accounts you own who responded to a campaign in the last ' + CAMPAIGN_DAYS + ' days. "No open opp" rows are warm leads.')
            .link('campaign', 'Campaign', 'campaignId')
            .link('contact', 'Contact', 'contactId')
            .col('account', 'Account', 'text')
            .col('status', 'Member status', 'text')
            .col('responded', 'Responded', 'date')
            .col('openOpp', 'Open opp?', 'text');
        Integer responders = 0;
        Integer warm = 0;
        for (CampaignMember m : [
            SELECT CampaignId, Campaign.Name, ContactId, Contact.Name, Contact.AccountId, Contact.Account.Name, Status, FirstRespondedDate
            FROM CampaignMember
            WHERE Contact.Account.OwnerId = :me AND HasResponded = true AND FirstRespondedDate >= :campaignFrom AND FirstRespondedDate <= :asOf
            WITH USER_MODE
            ORDER BY FirstRespondedDate DESC
            LIMIT 200
        ]) {
            responders++;
            Boolean hasOpp = accountsWithOpenOpps.contains(m.Contact.AccountId);
            if (!hasOpp) {
                warm++;
            }
            if (campaigns.rows.size() < 50) {
                campaigns.rows.add(
                    new Map<String, Object>{
                        'campaignId' => m.CampaignId,
                        'campaign' => m.Campaign.Name,
                        'contactId' => m.ContactId,
                        'contact' => m.Contact.Name,
                        'account' => m.Contact.Account.Name,
                        'status' => m.Status,
                        'responded' => m.FirstRespondedDate,
                        'openOpp' => hasOpp ? 'Yes' : 'No open opp'
                    }
                );
            }
        }
        page.addKpi(new BusinessHealthModel.Kpi('campaignResponses', 'Campaign responses at my accounts', responders, 'number'))
            .note(warm + ' of them at accounts with no open opportunity: warm follow-ups. Last ' + CAMPAIGN_DAYS + ' days.');

        // ---- leads and renewals ------------------------------------------------------
        BusinessHealthModel.Table leads = new BusinessHealthModel.Table('myLeads', 'My leads to work',
            'Open leads you own with no logged activity, highest Pardot score first.')
            .link('name', 'Lead', 'id')
            .col('company', 'Company', 'text')
            .col('source', 'Source', 'text')
            .col('created', 'Created', 'date')
            .col('score', 'Pardot score', 'number');
        for (Lead l : [
            SELECT Id, Name, Company, LeadSource, CreatedDate, pi__score__c
            FROM Lead
            WHERE OwnerId = :me AND IsConverted = false AND Status IN ('Open', 'Contacted') AND LastActivityDate = null
            WITH USER_MODE
            ORDER BY pi__score__c DESC NULLS LAST
            LIMIT 25
        ]) {
            leads.rows.add(new Map<String, Object>{ 'id' => l.Id, 'name' => l.Name, 'company' => l.Company, 'source' => l.LeadSource,
                'created' => l.CreatedDate.date(), 'score' => l.pi__score__c });
        }
        if (!leads.rows.isEmpty()) {
            page.addKpi(new BusinessHealthModel.Kpi('untouchedLeads', 'Leads never worked', leads.rows.size(), 'number'))
                .target(0, 'lower', 0)
                .note('Open leads you own with no logged task or call' + (leads.rows.size() == 25 ? ' (showing the top 25)' : '') + '.');
        }
        Date renewalEnd = asOf.addDays(RENEWAL_DAYS);
        BusinessHealthModel.Table renewals = new BusinessHealthModel.Table('renewals', 'Managed services renewals coming due',
            'Won subscriptions at your accounts ending in the next ' + RENEWAL_DAYS + ' days.')
            .link('name', 'Opportunity', 'id')
            .col('account', 'Account', 'text')
            .col('ends', 'Subscription ends', 'date')
            .col('amount', 'Amount', 'currency')
            .col('openOpp', 'Renewal opp open?', 'text');
        for (Opportunity o : [
            SELECT Id, Name, AccountId, Account.Name, Subscription_End_Date__c, Amount
            FROM Opportunity
            WHERE Account.OwnerId = :me AND IsWon = true AND Subscription_End_Date__c >= :asOf AND Subscription_End_Date__c <= :renewalEnd
            WITH USER_MODE
            ORDER BY Subscription_End_Date__c
            LIMIT 50
        ]) {
            renewals.rows.add(new Map<String, Object>{ 'id' => o.Id, 'name' => o.Name, 'account' => o.Account.Name,
                'ends' => o.Subscription_End_Date__c, 'amount' => o.Amount, 'openOpp' => accountsWithOpenOpps.contains(o.AccountId) ? 'Yes' : 'No' });
        }

        // ---- charts --------------------------------------------------------------------
        List<String> monthLabels = new List<String>();
        List<Decimal> cumulative = new List<Decimal>();
        List<Decimal> pace = new List<Decimal>();
        Decimal running = 0;
        Integer periodDays = pStart.daysBetween(pEnd) + 1;
        for (Date m = pStart.toStartOfMonth(); m <= asOf && m <= pEnd; m = m.addMonths(1)) {
            monthLabels.add(BusinessHealthContext.monthLabel(m));
            running += BusinessHealthData.nz(bookedByMonth.get(BusinessHealthContext.monthKey(m)));
            cumulative.add(running.setScale(0));
            Date monthEnd = m.addMonths(1).addDays(-1);
            if (quota != null) {
                pace.add((quota * (pStart.daysBetween(monthEnd < pEnd ? monthEnd : pEnd) + 1) / periodDays).setScale(0));
            }
        }
        BusinessHealthModel.Chart paceChart = new BusinessHealthModel.Chart('quotaPace', 'Bookings this period vs quota pace', 'line', 'currency')
            .labels(monthLabels)
            .addSeries('Booked (cumulative)', cumulative)
            .metric('quotaAttainment');
        if (quota != null) {
            paceChart.addSeries('Quota pace', pace);
        }
        page.charts.add(paceChart);
        List<String> stageNames = new List<String>(byStage.keySet());
        stageNames.sort();
        List<Decimal> stageAmounts = new List<Decimal>();
        for (String st : stageNames) {
            stageAmounts.add(byStage.get(st).setScale(0));
        }
        page.charts.add(
            new BusinessHealthModel.Chart('pipelineByStage', 'My open pipeline by stage', 'hbar', 'currency')
                .labels(stageNames)
                .addSeries('Amount', stageAmounts)
                .metric('openOpps')
        );
        List<String> futureKeys = new List<String>();
        List<String> futureLabels = new List<String>();
        for (Integer i = 0; i < PIPELINE_MONTHS; i++) {
            Date m = asOf.toStartOfMonth().addMonths(i);
            futureKeys.add(BusinessHealthContext.monthKey(m));
            futureLabels.add(BusinessHealthContext.monthLabel(m));
        }
        page.charts.add(
            new BusinessHealthModel.Chart('pipelineByMonth', 'My pipeline by close month', 'bar', 'currency')
                .labels(futureLabels)
                .addSeries('Unweighted', BusinessHealthData.series(unweightedByMonth, futureKeys))
                .addSeries('Weighted', BusinessHealthData.series(weightedByMonth, futureKeys))
                .metric('pipelineCoverage')
        );

        pipeline.metric = 'needsAttention';
        page.tables.add(pipeline);
        page.tables.add(campaigns);
        if (!leads.rows.isEmpty()) {
            page.tables.add(leads);
        }
        if (!renewals.rows.isEmpty()) {
            page.tables.add(renewals);
        }

        page.signalMissedKpis();
        if (open.isEmpty()) {
            page.signal(BusinessHealthModel.STATUS_INFO, 'You own no open opportunities.');
        }
        page.briefMetrics = new List<String>{ 'quotaAttainment', 'pipelineCoverage', 'needsAttention', 'winRate' };
        return page;
    }
}
