/**
 * @group BusinessHealth
 *
 * @description Marketing: lead volume and quality by source, the lead funnel, speed of
 * follow-up, campaign reach and response, and marketing's contribution to pipeline and
 * bookings, both SOURCED (the opportunity came from a marketing lead source or names a
 * primary campaign) and INFLUENCED (someone at the account responded to a campaign in
 * the INFLUENCE_DAYS before the opportunity was created).
 *
 * Direct campaign attribution is thin in this org (most campaigns reach existing
 * contacts, and few opportunities name a primary campaign), so influence is reported
 * alongside it; an influenced opportunity counts once per touching campaign in the
 * campaign table, so those figures are not additive.
 *
 * Leads and campaigns have no practice, so they are always firm-wide; only the
 * opportunity measures respect the practice filter.
 */
public with sharing class BusinessHealthMarketingPage implements BusinessHealthPageBuilder {
    private static final Integer INFLUENCE_DAYS = 180;
    private static final Integer FOLLOW_UP_QUEUE_DAYS = 90;
    private static final Decimal MQL_SCORE = 50;

    /** Opportunity / lead sources that marketing generates. */
    public static final Set<String> MARKETING_SOURCES = new Set<String>{
        'Website',
        'Lead form on Demand Chain',
        'Campaign/Email',
        'Event',
        'LinkedIn',
        'Outbound Lead Gen',
        'Zoominfo'
    };

    public static String channel(String source) {
        if (String.isBlank(source)) {
            return 'Not recorded';
        }
        if (source == 'Outbound Lead Gen' || source == 'Zoominfo') {
            return 'Outbound & lists';
        }
        if (source == 'Sales') {
            return 'Sales team';
        }
        if (MARKETING_SOURCES.contains(source)) {
            return 'Inbound marketing';
        }
        if (source == BusinessHealthData.SALESFORCE_REFERRAL) {
            return 'Salesforce referral';
        }
        if (source.startsWith('Referral')) {
            return 'Other referrals';
        }
        if (source == 'Repeat Purchase' || source == 'Returning Customer') {
            return 'Existing clients';
        }
        return 'Other';
    }

    private class SourceStats {
        String name;
        Integer leads = 0;
        Integer converted = 0;
        Integer opps = 0;
        Decimal won = 0;
        Decimal scoreTotal = 0;
        Integer scored = 0;
    }

    private class CampaignStats {
        Campaign c;
        Integer members = 0;
        Integer responded = 0;
        Set<Id> influencedOpps = new Set<Id>();
        Decimal influencedPipeline = 0;
    }

    public BusinessHealthModel.HealthPage build(BusinessHealthContext ctx) {
        BusinessHealthModel.HealthPage page = new BusinessHealthModel.HealthPage(
            'marketing',
            'Marketing',
            'Is marketing filling the funnel with leads that turn into pipeline, and which campaigns are earning their keep?',
            'Leadership & Marketing'
        );
        Business_Health_Goal_Set__c s = ctx.goals;
        Date asOf = ctx.asOfDate;
        Date from12 = asOf.addMonths(-12);
        Date from24 = asOf.addMonths(-24);
        Datetime dtFrom12 = Datetime.newInstance(from12, Time.newInstance(0, 0, 0, 0));
        Datetime dtFrom24 = Datetime.newInstance(from24, Time.newInstance(0, 0, 0, 0));
        Datetime dtAsOfEnd = Datetime.newInstance(asOf.addDays(1), Time.newInstance(0, 0, 0, 0));

        // ---- leads: trailing 12 months (detail) and prior 12 months (count) ----------
        List<Lead> leads = [
            SELECT Id, Name, Company, LeadSource, Status, CreatedDate, IsConverted, ConvertedDate, ConvertedOpportunityId,
                ConvertedOpportunity.IsWon, ConvertedOpportunity.Amount, LastActivityDate, pi__score__c, Owner.Name
            FROM Lead
            WHERE CreatedDate >= :dtFrom12 AND CreatedDate < :dtAsOfEnd
            WITH USER_MODE
        ];
        Integer priorLeads = [
            SELECT COUNT()
            FROM Lead
            WHERE CreatedDate >= :dtFrom24 AND CreatedDate < :dtFrom12
            WITH USER_MODE
        ];

        // First logged task per lead (speed to follow-up).
        Map<Id, Datetime> firstTouch = new Map<Id, Datetime>();
        Set<Id> leadIds = new Map<Id, Lead>(leads).keySet();
        if (!leadIds.isEmpty()) {
            for (AggregateResult ar : [
                SELECT WhoId who, MIN(CreatedDate) firstAt
                FROM Task
                WHERE WhoId IN :leadIds
                WITH USER_MODE
                GROUP BY WhoId
            ]) {
                firstTouch.put((Id) ar.get('who'), (Datetime) ar.get('firstAt'));
            }
        }

        Map<String, SourceStats> bySource = new Map<String, SourceStats>();
        Map<String, Map<String, Decimal>> leadsByChannelMonth = new Map<String, Map<String, Decimal>>();
        Integer worked = 0;
        Integer qualified = 0;
        Integer converted = 0;
        Integer toOpp = 0;
        Integer wonFromLeads = 0;
        Integer noSource = 0;
        Integer mql = 0;
        Integer untouched = 0;
        List<Decimal> touchDays = new List<Decimal>();
        BusinessHealthModel.Table queue = new BusinessHealthModel.Table('followUp', 'Leads waiting for follow-up',
            'Open leads from the last ' + FOLLOW_UP_QUEUE_DAYS + ' days with no logged activity, highest Pardot score first.')
            .link('name', 'Lead', 'id')
            .col('company', 'Company', 'text')
            .col('source', 'Source', 'text')
            .col('created', 'Created', 'date')
            .col('score', 'Pardot score', 'number')
            .col('owner', 'Owner', 'text');
        Date queueFrom = asOf.addDays(-FOLLOW_UP_QUEUE_DAYS);
        for (Lead l : leads) {
            String src = String.isBlank(l.LeadSource) ? 'Not recorded' : l.LeadSource;
            if (!bySource.containsKey(src)) {
                SourceStats st = new SourceStats();
                st.name = src;
                bySource.put(src, st);
            }
            SourceStats st = bySource.get(src);
            st.leads++;
            if (l.pi__score__c != null) {
                st.scoreTotal += l.pi__score__c;
                st.scored++;
                if (l.pi__score__c >= MQL_SCORE) {
                    mql++;
                }
            }
            String ch = channel(l.LeadSource);
            if (!leadsByChannelMonth.containsKey(ch)) {
                leadsByChannelMonth.put(ch, new Map<String, Decimal>());
            }
            BusinessHealthData.add(leadsByChannelMonth.get(ch), BusinessHealthContext.monthKey(l.CreatedDate.date()), 1);
            if (String.isBlank(l.LeadSource)) {
                noSource++;
            }
            Boolean touched = l.LastActivityDate != null || firstTouch.containsKey(l.Id);
            if (touched || l.Status != 'Open') {
                worked++;
            }
            if (l.Status == 'Qualified' || l.IsConverted) {
                qualified++;
            }
            if (l.IsConverted) {
                converted++;
                st.converted++;
            }
            if (l.ConvertedOpportunityId != null) {
                toOpp++;
                st.opps++;
                if (l.ConvertedOpportunity != null && l.ConvertedOpportunity.IsWon) {
                    wonFromLeads++;
                    st.won += BusinessHealthData.nz(l.ConvertedOpportunity.Amount);
                }
            }
            if (firstTouch.containsKey(l.Id)) {
                Long millis = Math.max(0L, firstTouch.get(l.Id).getTime() - l.CreatedDate.getTime());
                touchDays.add((Decimal.valueOf(millis) / 86400000).setScale(1));
            }
            if (l.Status == 'Open' && !l.IsConverted && !touched) {
                untouched++;
                if (l.CreatedDate.date() >= queueFrom) {
                    queue.rows.add(
                        new Map<String, Object>{
                            'id' => l.Id,
                            'name' => l.Name,
                            'company' => l.Company,
                            'source' => src,
                            'created' => l.CreatedDate.date(),
                            'score' => l.pi__score__c,
                            'owner' => l.Owner == null ? null : l.Owner.Name
                        }
                    );
                }
            }
        }
        BusinessHealthModel.sortRows(queue.rows, 'score');
        queue.rows = BusinessHealthModel.first(queue.rows, 25);

        // ---- opportunities created in the trailing 12 months ----------------------------
        ctx.bind('oppCreatedFrom', dtFrom12);
        ctx.bind('oppCreatedTo', dtAsOfEnd);
        List<Opportunity> newOpps = (List<Opportunity>) ctx.query(
            'SELECT Id, Name, AccountId, Amount, LeadSource, CampaignId, IsWon, IsClosed, CreatedDate, CloseDate, Type' +
                ' FROM Opportunity WHERE CreatedDate >= :oppCreatedFrom AND CreatedDate < :oppCreatedTo' +
                ctx.practiceClause('pse__Practice__c')
        );
        Decimal pipelineAll = 0;
        Decimal pipelineMarketing = 0;
        Decimal wonMarketing = 0;
        Integer closedMarketing = 0;
        Integer wonMarketingCount = 0;
        Map<String, Decimal> pipelineByChannel = new Map<String, Decimal>();
        Set<Id> oppAccounts = new Set<Id>();
        for (Opportunity o : newOpps) {
            Decimal amt = BusinessHealthData.nz(o.Amount);
            pipelineAll += amt;
            Boolean marketing = isMarketingSourced(o);
            // A deal credited to marketing only through its Primary Campaign gets its own bucket.
            String ch = channel(o.LeadSource);
            if (o.CampaignId != null && !MARKETING_SOURCES.contains(o.LeadSource)) {
                ch = 'Campaign-attributed';
            }
            BusinessHealthData.add(pipelineByChannel, ch, amt);
            if (marketing) {
                pipelineMarketing += amt;
                if (o.IsClosed) {
                    closedMarketing++;
                }
                if (o.IsWon) {
                    wonMarketing += amt;
                    wonMarketingCount++;
                }
            }
            if (o.AccountId != null) {
                oppAccounts.add(o.AccountId);
            }
        }

        // ---- campaigns started in the trailing 12 months, and campaign responses --------
        List<Campaign> campaigns = [
            SELECT Id, Name, Type, Status, StartDate, ActualCost, BudgetedCost, NumberOfOpportunities, NumberOfWonOpportunities, AmountWonOpportunities
            FROM Campaign
            WHERE StartDate > :from12 AND StartDate <= :asOf
            WITH USER_MODE
        ];
        Map<Id, CampaignStats> byCampaign = new Map<Id, CampaignStats>();
        for (Campaign c : campaigns) {
            CampaignStats cs = new CampaignStats();
            cs.c = c;
            byCampaign.put(c.Id, cs);
        }
        // Responses in the 12 months before the opportunity window plus the window
        // itself feed influence; members of this year's campaigns feed response rates.
        Datetime influenceFrom = Datetime.newInstance(from12.addDays(-INFLUENCE_DAYS), Time.newInstance(0, 0, 0, 0));
        Set<Id> campaignIds = byCampaign.keySet();
        Map<Id, List<CampaignMember>> responsesByAccount = new Map<Id, List<CampaignMember>>();
        Integer members = 0;
        Integer responded = 0;
        Map<String, Integer[]> byType = new Map<String, Integer[]>();
        for (CampaignMember m : [
            SELECT CampaignId, Campaign.Type, HasResponded, FirstRespondedDate, CreatedDate, Contact.AccountId, Lead.ConvertedAccountId
            FROM CampaignMember
            WHERE CampaignId IN :campaignIds OR (HasResponded = true AND CreatedDate >= :influenceFrom AND CreatedDate < :dtAsOfEnd)
            WITH USER_MODE
        ]) {
            CampaignStats cs = byCampaign.get(m.CampaignId);
            if (cs != null) {
                cs.members++;
                members++;
                String t = String.isBlank(m.Campaign.Type) ? 'Other' : m.Campaign.Type;
                if (!byType.containsKey(t)) {
                    byType.put(t, new Integer[]{ 0, 0 });
                }
                byType.get(t)[0]++;
                if (m.HasResponded) {
                    cs.responded++;
                    responded++;
                    byType.get(t)[1]++;
                }
            }
            Id acct = m.Contact != null && m.Contact.AccountId != null ? m.Contact.AccountId : (m.Lead != null ? m.Lead.ConvertedAccountId : null);
            if (m.HasResponded && acct != null && oppAccounts.contains(acct)) {
                if (!responsesByAccount.containsKey(acct)) {
                    responsesByAccount.put(acct, new List<CampaignMember>());
                }
                responsesByAccount.get(acct).add(m);
            }
        }

        // Influence: a response at the account within INFLUENCE_DAYS before creation.
        Decimal influencedPipeline = 0;
        Decimal influencedExisting = 0;
        Integer influencedCount = 0;
        Map<Id, Decimal> influencedByCampaignAll = new Map<Id, Decimal>();
        for (Opportunity o : newOpps) {
            List<CampaignMember> touches = responsesByAccount.get(o.AccountId);
            if (touches == null) {
                continue;
            }
            Date created = o.CreatedDate.date();
            Boolean influenced = false;
            Set<Id> touchingCampaigns = new Set<Id>();
            for (CampaignMember m : touches) {
                Date respondedOn = m.FirstRespondedDate != null ? m.FirstRespondedDate : m.CreatedDate.date();
                if (respondedOn <= created && respondedOn >= created.addDays(-INFLUENCE_DAYS)) {
                    influenced = true;
                    touchingCampaigns.add(m.CampaignId);
                }
            }
            if (influenced) {
                influencedCount++;
                influencedPipeline += BusinessHealthData.nz(o.Amount);
                if (o.Type != null && o.Type.startsWith('Existing')) {
                    influencedExisting += BusinessHealthData.nz(o.Amount);
                }
                for (Id cid : touchingCampaigns) {
                    CampaignStats cs = byCampaign.get(cid);
                    if (cs != null && cs.influencedOpps.add(o.Id)) {
                        cs.influencedPipeline += BusinessHealthData.nz(o.Amount);
                    }
                }
            }
        }

        // ---- spend ------------------------------------------------------------------------
        Decimal spend = 0;
        Integer withCost = 0;
        for (Campaign c : campaigns) {
            if (c.ActualCost != null && c.ActualCost > 0) {
                spend += c.ActualCost;
                withCost++;
            }
        }

        // ---- KPIs -------------------------------------------------------------------------
        page.addKpi(new BusinessHealthModel.Kpi('newLeads', 'New leads (T12M)', leads.size(), 'number'))
            .target(priorLeads, 'higher', 0.15)
            .note(priorLeads + ' in the prior 12 months. ' + mql + ' scored ' + MQL_SCORE.setScale(0) + '+ in Pardot (marketing-qualified).');
        page.addKpi(new BusinessHealthModel.Kpi('leadConversion', 'Lead conversion (T12M)', BusinessHealthModel.pct(converted, leads.size()), 'percent'))
            .target(ctx.num(s.Lead_Conversion_Target__c, 10), 'higher', 0.25)
            .note(converted + ' of ' + leads.size() + ' new leads converted; ' + toOpp + ' became opportunities and ' + wonFromLeads + ' were won.');
        page.addKpi(new BusinessHealthModel.Kpi('untouchedLeads', 'Leads never followed up', BusinessHealthModel.pct(untouched, leads.size()), 'percent'))
            .target(ctx.num(s.Untouched_Leads_Threshold__c, 20), 'lower', 0.5)
            .note(untouched + ' open leads with no logged task or activity. List uploads with no owner follow-up inflate this.');
        touchDays.sort();
        Decimal medianTouch = touchDays.isEmpty() ? null : touchDays[touchDays.size() / 2];
        page.addKpi(new BusinessHealthModel.Kpi('speedToLead', 'Median time to first touch', medianTouch, 'days'))
            .target(ctx.num(s.Lead_Follow_Up_Days__c, 2), 'lower', 0.5)
            .note('Lead created to first logged task, for the ' + touchDays.size() + ' new leads that were touched.');
        page.addKpi(new BusinessHealthModel.Kpi('campaignResponse', 'Campaign response rate (T12M)', BusinessHealthModel.pct(responded, members), 'percent'))
            .target(ctx.num(s.Campaign_Response_Target__c, 10), 'higher', 0.25)
            .note(responded + ' responses from ' + members + ' members across ' + campaigns.size() + ' campaigns started in the last 12 months.');
        page.addKpi(new BusinessHealthModel.Kpi('marketingPipelineShare', 'Marketing-sourced pipeline (T12M)', BusinessHealthModel.pct(pipelineMarketing, pipelineAll), 'percent'))
            .target(ctx.num(s.Marketing_Pipeline_Target__c, 25), 'higher', 0.2)
            .note(BusinessHealthModel.formatValue(pipelineMarketing, 'currency') + ' of ' + BusinessHealthModel.formatValue(pipelineAll, 'currency') +
                ' new pipeline came from a marketing lead source (website, events, email, LinkedIn, outbound lead gen, lists) or names a primary campaign.');
        page.addKpi(new BusinessHealthModel.Kpi('influencedPipeline', 'Campaign-influenced pipeline (T12M)', BusinessHealthModel.pct(influencedPipeline, pipelineAll), 'percent'))
            .target(ctx.num(s.Influenced_Pipeline_Target__c, 50), 'higher', 0.3)
            .note(BusinessHealthModel.formatValue(influencedPipeline, 'currency') + ' across ' + influencedCount +
                ' opportunities opened within ' + INFLUENCE_DAYS + ' days after someone at the account responded to a campaign; ' +
                BusinessHealthModel.formatValue(BusinessHealthModel.pct(influencedExisting, influencedPipeline), 'percent') + ' of it is expansion with existing clients.');
        page.addKpi(new BusinessHealthModel.Kpi('marketingBookings', 'Marketing-sourced bookings (T12M cohort)', wonMarketing, 'currency'))
            .note(wonMarketingCount + ' won of ' + closedMarketing + ' closed marketing-sourced opportunities created in the last 12 months.');
        BusinessHealthModel.Kpi spendKpi = page.addKpi(new BusinessHealthModel.Kpi('costPerOpp', 'Marketing cost per influenced opportunity', null, 'currency'));
        if (withCost * 2 < campaigns.size() || influencedCount == 0) {
            spendKpi.markUnavailable('Actual Cost is recorded on only ' + withCost + ' of ' + campaigns.size() +
                ' recent campaigns, so marketing ROI and cost per opportunity cannot be measured.');
        } else {
            spendKpi.value = (spend / influencedCount).setScale(0);
            spendKpi.note(BusinessHealthModel.formatValue(spend, 'currency') + ' recorded spend / ' + influencedCount + ' influenced opportunities.');
        }
        page.addKpi(new BusinessHealthModel.Kpi('leadsNoSource', 'Leads with no source', BusinessHealthModel.pct(noSource, leads.size()), 'percent'))
            .target(ctx.num(s.Lead_Source_Missing_Threshold__c, 5), 'lower', 1)
            .note('Without Lead Source, marketing cannot be credited for, or learn from, these leads.');

        // ---- charts -----------------------------------------------------------------------
        List<String> keys = ctx.completeMonthKeys(12);
        BusinessHealthModel.Chart leadChart = new BusinessHealthModel.Chart('leadsByChannel', 'New leads by month and channel', 'bar', 'number')
            .labels(ctx.completeMonthLabels(12));
        // Name the three largest channels by volume; fold the rest into "All other".
        List<BusinessHealthModel.RowSorter> ranked = new List<BusinessHealthModel.RowSorter>();
        for (String ch : leadsByChannelMonth.keySet()) {
            ranked.add(new BusinessHealthModel.RowSorter(new Map<String, Object>{ 'ch' => ch, 'n' => BusinessHealthData.sum(leadsByChannelMonth.get(ch)) }, 'n', true));
        }
        ranked.sort();
        List<String> topChannels = new List<String>();
        for (Integer i = 0; i < Math.min(3, ranked.size()); i++) {
            topChannels.add((String) ranked[i].row.get('ch'));
        }
        Map<String, Decimal> otherMonths = new Map<String, Decimal>();
        for (String ch : leadsByChannelMonth.keySet()) {
            if (!topChannels.contains(ch)) {
                for (String k : leadsByChannelMonth.get(ch).keySet()) {
                    BusinessHealthData.add(otherMonths, k, leadsByChannelMonth.get(ch).get(k));
                }
            }
        }
        for (String ch : topChannels) {
            leadChart.addSeries(ch, BusinessHealthData.series(leadsByChannelMonth.get(ch), keys));
        }
        if (!otherMonths.isEmpty()) {
            leadChart.addSeries('All other', BusinessHealthData.series(otherMonths, keys));
        }
        page.charts.add(leadChart);
        page.charts.add(
            new BusinessHealthModel.Chart('funnel', 'Lead funnel, leads created in the last 12 months', 'hbar', 'number')
                .labels(new List<String>{ 'Created', 'Worked', 'Qualified', 'Converted', 'Became opportunity', 'Won' })
                .addSeries('Leads', new List<Decimal>{ leads.size(), worked, qualified, converted, toOpp, wonFromLeads })
        );
        List<String> pipeLabels = new List<String>();
        List<Decimal> pipeValues = new List<Decimal>();
        for (String ch : new List<String>{ 'Inbound marketing', 'Outbound & lists', 'Campaign-attributed', 'Salesforce referral', 'Other referrals', 'Existing clients', 'Sales team', 'Other', 'Not recorded' }) {
            if (pipelineByChannel.containsKey(ch)) {
                pipeLabels.add(ch);
                pipeValues.add(pipelineByChannel.get(ch).setScale(0));
            }
        }
        page.charts.add(
            new BusinessHealthModel.Chart('pipelineByChannel', 'New pipeline by source channel (T12M)', 'hbar', 'currency')
                .labels(pipeLabels)
                .addSeries('Pipeline', pipeValues)
        );
        List<String> typeNames = new List<String>(byType.keySet());
        typeNames.sort();
        List<Decimal> typeRates = new List<Decimal>();
        for (String t : typeNames) {
            typeRates.add(BusinessHealthModel.pct(byType.get(t)[1], byType.get(t)[0]));
        }
        page.charts.add(
            new BusinessHealthModel.Chart('responseByType', 'Campaign response rate by type (T12M)', 'hbar', 'percent')
                .labels(typeNames)
                .addSeries('Response rate', typeRates)
                .target(ctx.num(s.Campaign_Response_Target__c, 10), 'Target')
        );

        // ---- tables -----------------------------------------------------------------------
        BusinessHealthModel.Table campaignTable = new BusinessHealthModel.Table('campaigns', 'Campaign scorecard (started in the last 12 months)',
            'Influenced pipeline counts every opportunity at a responding account within ' + INFLUENCE_DAYS +
                ' days, so it overlaps between campaigns. Sourced figures use the opportunity\'s Primary Campaign.')
            .link('name', 'Campaign', 'id')
            .col('type', 'Type', 'text')
            .col('start', 'Start', 'date')
            .col('members', 'Members', 'number')
            .col('responses', 'Responses', 'number')
            .col('rate', 'Response rate', 'percent')
            .col('influencedOpps', 'Influenced opps', 'number')
            .col('influenced', 'Influenced pipeline', 'currency')
            .col('sourcedWon', 'Sourced won', 'currency')
            .col('cost', 'Actual cost', 'currency');
        for (CampaignStats cs : byCampaign.values()) {
            if (cs.members == 0 && cs.influencedOpps.isEmpty()) {
                continue;
            }
            campaignTable.rows.add(
                new Map<String, Object>{
                    'id' => cs.c.Id,
                    'name' => cs.c.Name,
                    'type' => cs.c.Type,
                    'start' => cs.c.StartDate,
                    'members' => cs.members,
                    'responses' => cs.responded,
                    'rate' => BusinessHealthModel.pct(cs.responded, cs.members),
                    'influencedOpps' => cs.influencedOpps.size(),
                    'influenced' => cs.influencedPipeline,
                    'sourcedWon' => cs.c.AmountWonOpportunities,
                    'cost' => cs.c.ActualCost
                }
            );
        }
        BusinessHealthModel.sortRows(campaignTable.rows, 'influenced');
        page.tables.add(campaignTable);

        BusinessHealthModel.Table sourceTable = new BusinessHealthModel.Table('leadSources', 'Lead source quality (leads created in the last 12 months)', null)
            .col('source', 'Lead source', 'text')
            .col('channel', 'Channel', 'text')
            .col('leads', 'Leads', 'number')
            .col('converted', 'Converted', 'number')
            .col('rate', 'Conversion', 'percent')
            .col('opps', 'Opportunities', 'number')
            .col('won', 'Won bookings', 'currency')
            .col('score', 'Avg Pardot score', 'number');
        for (SourceStats st : bySource.values()) {
            sourceTable.rows.add(
                new Map<String, Object>{
                    'source' => st.name,
                    'channel' => channel(st.name == 'Not recorded' ? null : st.name),
                    'leads' => st.leads,
                    'converted' => st.converted,
                    'rate' => BusinessHealthModel.pct(st.converted, st.leads),
                    'opps' => st.opps,
                    'won' => st.won,
                    'score' => st.scored == 0 ? null : (st.scoreTotal / st.scored).setScale(0)
                }
            );
        }
        BusinessHealthModel.sortRows(sourceTable.rows, 'leads');
        page.tables.add(sourceTable);
        page.tables.add(queue);

        // ---- signals & gaps ---------------------------------------------------------------
        page.signalMissedKpis();
        Integer bigNoOpp = 0;
        for (CampaignStats cs : byCampaign.values()) {
            if (cs.responded >= 50 && cs.influencedOpps.isEmpty()) {
                bigNoOpp++;
            }
        }
        if (bigNoOpp > 0) {
            page.signal(BusinessHealthModel.STATUS_WARN, bigNoOpp + ' campaigns drew 50+ responses but no pipeline followed within ' + INFLUENCE_DAYS +
                ' days. Check that responders are routed to sales and followed up.');
        }
        Decimal existingShare = BusinessHealthModel.pct(influencedExisting, influencedPipeline);
        if (existingShare != null && existingShare > 60) {
            page.signal(BusinessHealthModel.STATUS_INFO, 'Campaigns mostly influence existing clients (' + existingShare.setScale(0) +
                '% of influenced pipeline). They are working as expansion programs; new-logo demand generation is thin.');
        }
        page.dataGaps.add('Campaign Actual Cost is rarely entered, so ROI, cost per lead and cost per opportunity cannot be measured.');
        page.dataGaps.add('Pardot grade and UTM fields are empty on new leads, so channel-level digital attribution is not possible.');
        page.dataGaps.add('Campaign Influence is not enabled; influence here is approximated from account-level campaign responses.');
        return page;
    }

    public static Boolean isMarketingSourced(Opportunity o) {
        return MARKETING_SOURCES.contains(o.LeadSource) || o.CampaignId != null;
    }
}
