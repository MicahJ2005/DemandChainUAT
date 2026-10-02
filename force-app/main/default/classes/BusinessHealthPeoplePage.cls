/**
 * @group BusinessHealth
 *
 * @description People & Capability: headcount, attrition, hiring (time to fill, new-hire
 * ramp), engagement (weekly pulse survey), and Salesforce certification coverage in
 * the strategic skills being sold (Agentforce, Data Cloud, ...), which also drives
 * Salesforce partner program standing.
 */
public with sharing class BusinessHealthPeoplePage implements BusinessHealthPageBuilder {
    private static final Decimal ENGAGEMENT_TARGET = 4.0;
    private static final Integer RAMP_WEEKS = 13;
    private static final Integer EXPIRY_WINDOW_DAYS = 90;
    private static final Set<String> OPEN_POSTING_STATUSES = new Set<String>{ 'Requested', 'Approved', 'Tentative', 'Go for Hire' };

    public BusinessHealthModel.HealthPage build(BusinessHealthContext ctx) {
        BusinessHealthModel.HealthPage page = new BusinessHealthModel.HealthPage(
            'people',
            'People & Capability',
            'People are the product: are we keeping, growing and certifying the team we need for what we sell?',
            'Leadership & Directors'
        );
        Business_Health_Goal_Set__c s = ctx.goals;
        Date asOf = ctx.asOfDate;
        Date from12 = asOf.addMonths(-12);

        // All internal resources ever, for headcount history, hires and departures.
        List<Contact> everyone = (List<Contact>) ctx.query(
            'SELECT Id, Name, pse__Resource_Role__c, pse__Start_Date__c, pse__Last_Date__c, pse__Is_Resource_Active__c' +
                ' FROM Contact WHERE pse__Is_Resource__c = true AND pse__External_Resource__c = false' +
                ctx.practiceClause('pse__Practice__c')
        );
        List<Contact> active = new List<Contact>();
        List<Contact> departures = new List<Contact>();
        List<Contact> hires = new List<Contact>();
        Integer subcontractors = 0;
        for (Contact c : everyone) {
            Boolean left = c.pse__Last_Date__c != null && c.pse__Last_Date__c <= asOf;
            if (c.pse__Is_Resource_Active__c && !left) {
                active.add(c);
            }
            if (c.pse__Last_Date__c != null && c.pse__Last_Date__c > from12 && c.pse__Last_Date__c <= asOf) {
                departures.add(c);
            }
            if (c.pse__Start_Date__c != null && c.pse__Start_Date__c > from12 && c.pse__Start_Date__c <= asOf) {
                hires.add(c);
            }
        }
        for (Contact c : BusinessHealthData.activeResources(ctx)) {
            if (c.pse__External_Resource__c) {
                subcontractors++;
            }
        }

        page.addKpi(new BusinessHealthModel.Kpi('headcount', 'Employees (resources)', active.size(), 'number'))
            .note(subcontractors + ' active subcontractors in addition.');
        page.addKpi(new BusinessHealthModel.Kpi('attrition', 'Attrition (T12M)', BusinessHealthData.attritionPct(departures.size(), active.size()), 'percent'))
            .target(ctx.num(s.Attrition_Target__c, 12), 'lower', 0.25)
            .note(departures.size() + ' departures in 12 months. Voluntary vs involuntary and top-performer status are not recorded.');
        page.addKpi(new BusinessHealthModel.Kpi('hires', 'New hires (T12M)', hires.size(), 'number'))
            .target(departures.size(), 'higher', 0.25)
            .note('Target: at least replace departures (' + departures.size() + ').');

        // ---- new-hire ramp: billable utilization in the first 13 weeks -----------------------
        List<BusinessHealthData.TimecardFact> tcs = BusinessHealthData.timecards(ctx, from12, 'pse__Resource__r.pse__Practice__c');
        Map<Id, Contact> hireById = new Map<Id, Contact>(hires);
        // Only hires who log time (delivery hires) with 4+ weeks of tenure are measured.
        Map<Id, Decimal> rampBillableById = new Map<Id, Decimal>();
        Set<Id> logsTime = new Set<Id>();
        for (BusinessHealthData.TimecardFact f : tcs) {
            Contact c = hireById.get(f.resourceId);
            if (c != null && f.endDate <= c.pse__Start_Date__c.addDays(7 * RAMP_WEEKS)) {
                logsTime.add(c.Id);
                BusinessHealthData.add(rampBillableById, c.Id, f.billableHours);
            }
        }
        Integer rampPeople = 0;
        Decimal rampWeeks = 0;
        Decimal rampBillable = 0;
        for (Contact c : hires) {
            Integer weeksIn = Math.min(RAMP_WEEKS, c.pse__Start_Date__c.daysBetween(asOf) / 7);
            if (weeksIn >= 4 && logsTime.contains(c.Id)) {
                rampPeople++;
                rampWeeks += weeksIn;
                rampBillable += BusinessHealthData.nz(rampBillableById.get(c.Id));
            }
        }
        BusinessHealthModel.Kpi rampKpi = page.addKpi(new BusinessHealthModel.Kpi('ramp', 'New-hire ramp (first 13 weeks)',
            rampPeople == 0 ? null : BusinessHealthModel.pct(rampBillable, rampWeeks * ctx.hoursPerWeek()), 'percent'));
        if (rampPeople == 0) {
            rampKpi.markUnavailable('No delivery hires (people logging time) with at least 4 weeks of tenure in the last 12 months.');
        } else {
            rampKpi.target(ctx.num(s.New_Hire_Ramp_Target__c, 45), 'higher', 0.25)
                .note('Billable utilization of ' + rampPeople + ' recent hires in their first weeks.');
        }

        // ---- recruiting ------------------------------------------------------------------------
        List<Candidate__c> postings = [
            SELECT Id, Name, Role__c, RequestDate__c, Target_Fill_Date__c, Status__c, NewReplacement__c
            FROM Candidate__c
            WHERE RecordType.DeveloperName = 'Posting' AND Status__c IN :OPEN_POSTING_STATUSES
            WITH USER_MODE
            ORDER BY RequestDate__c
        ];
        List<Candidate__c> hiredCandidates = [
            SELECT Job_Posting__r.RequestDate__c, Application_Date__c, Contact__r.pse__Start_Date__c
            FROM Candidate__c
            WHERE Status__c = 'Hired' AND Contact__r.pse__Start_Date__c > :from12 AND Contact__r.pse__Start_Date__c <= :asOf
            WITH USER_MODE
        ];
        Decimal fillDays = 0;
        Integer filled = 0;
        for (Candidate__c c : hiredCandidates) {
            Date opened = c.Job_Posting__r != null && c.Job_Posting__r.RequestDate__c != null ? c.Job_Posting__r.RequestDate__c : c.Application_Date__c;
            if (opened != null) {
                fillDays += opened.daysBetween(c.Contact__r.pse__Start_Date__c);
                filled++;
            }
        }
        BusinessHealthModel.Kpi fillKpi = page.addKpi(new BusinessHealthModel.Kpi('timeToFill', 'Time to fill (T12M)', filled == 0 ? null : (fillDays / filled).setScale(0), 'days'));
        if (filled == 0) {
            fillKpi.markUnavailable('No hires in the last 12 months are linked to a Candidate record. Recruiting is not being tracked in Salesforce.');
        } else {
            fillKpi.target(ctx.num(s.Time_To_Fill_Target__c, 45), 'lower', 0.3).note(filled + ' hires, request (or application) date to start date.');
        }
        page.addKpi(new BusinessHealthModel.Kpi('openRoles', 'Open roles', postings.size(), 'number'))
            .note('Job postings in Requested / Approved / Tentative / Go for Hire.');

        // ---- engagement (weekly pulse survey, 1-5) --------------------------------------------------
        Datetime since90 = Datetime.newInstance(asOf.addDays(-90), Time.newInstance(0, 0, 0, 0));
        Datetime asOfEnd = Datetime.newInstance(asOf.addDays(1), Time.newInstance(0, 0, 0, 0));
        List<AggregateResult> pulse = [
            SELECT AVG(Survey_Response_Number__c) score, COUNT(Id) cnt, COUNT_DISTINCT(User__c) people
            FROM Weekly_Survey_Result__c
            WHERE Survey_Response_Number__c != NULL AND CreatedDate >= :since90 AND CreatedDate < :asOfEnd
            WITH USER_MODE
        ];
        Integer pulseCount = pulse.isEmpty() ? 0 : (Integer) pulse[0].get('cnt');
        BusinessHealthModel.Kpi pulseKpi = page.addKpi(new BusinessHealthModel.Kpi('engagement', 'Engagement pulse (last 90 days)',
            pulseCount == 0 ? null : ((Decimal) pulse[0].get('score')).setScale(2), 'score'));
        if (pulseCount == 0) {
            List<Weekly_Survey_Result__c> last = [
                SELECT CreatedDate
                FROM Weekly_Survey_Result__c
                WHERE CreatedDate < :asOfEnd
                WITH USER_MODE
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            pulseKpi.markUnavailable('No weekly survey responses in the last 90 days' +
                (last.isEmpty() ? '.' : '. The last response was ' + last[0].CreatedDate.date().format() + '.'));
            page.signal(BusinessHealthModel.STATUS_WARN, 'The weekly engagement pulse has stopped. Leadership has no current read on morale.');
        } else {
            pulseKpi.target(ctx.num(s.Engagement_Target__c, ENGAGEMENT_TARGET), 'higher', 0.1).note(pulseCount + ' responses from ' + pulse[0].get('people') + ' people, 1-5 scale.');
        }

        // ---- certifications ---------------------------------------------------------------------
        Set<Id> activeIds = new Map<Id, Contact>(active).keySet();
        ctx.bind('activeResourceIds', activeIds);
        List<pse__Skill_Certification_Rating__c> certs = (List<pse__Skill_Certification_Rating__c>) ctx.query(
            'SELECT pse__Resource__c, pse__Resource__r.Name, pse__Resource__r.pse__Resource_Role__c, pse__Skill_Certification__r.Name,' +
                ' pse__Skill_Certification__r.Salesforce_Cloud__c, pse__Expiration_Date__c, Status__c, IsPlanned__c, pse__Date_Achieved__c,' +
                ' Target_Achievement_Date__c, PartnerProgramPoints__c' +
                ' FROM pse__Skill_Certification_Rating__c' +
                ' WHERE pse__Resource__c IN :activeResourceIds AND pse__Skill_Certification__r.pse__Skill_Or_Certification__c = \'Certification\''
        );
        List<String> strategic = ctx.strategicSkills();
        Map<String, Set<Id>> certifiedBySkill = new Map<String, Set<Id>>();
        Map<String, Set<Id>> plannedBySkill = new Map<String, Set<Id>>();
        for (String k : strategic) {
            certifiedBySkill.put(k, new Set<Id>());
            plannedBySkill.put(k, new Set<Id>());
        }
        Map<Id, List<String>> certsByPerson = new Map<Id, List<String>>();
        Map<Id, Integer> expiringByPerson = new Map<Id, Integer>();
        Map<String, Decimal> byCloud = new Map<String, Decimal>();
        Integer achieved = 0;
        Integer expiring = 0;
        Decimal partnerPoints = 0;
        Date expiryHorizon = asOf.addDays(EXPIRY_WINDOW_DAYS);
        for (pse__Skill_Certification_Rating__c r : certs) {
            String certName = r.pse__Skill_Certification__r.Name;
            Boolean planned = r.IsPlanned__c || r.Status__c == 'Submitted';
            Boolean expired = r.pse__Expiration_Date__c != null && r.pse__Expiration_Date__c < asOf;
            for (String k : strategic) {
                if (certName != null && certName.containsIgnoreCase(k)) {
                    (planned || expired ? plannedBySkill : certifiedBySkill).get(k).add(r.pse__Resource__c);
                }
            }
            if (planned || expired) {
                continue;
            }
            achieved++;
            partnerPoints += BusinessHealthData.nz(r.PartnerProgramPoints__c);
            BusinessHealthData.add(byCloud, cloudFor(certName, r.pse__Skill_Certification__r.Salesforce_Cloud__c), 1);
            if (!certsByPerson.containsKey(r.pse__Resource__c)) {
                certsByPerson.put(r.pse__Resource__c, new List<String>());
            }
            certsByPerson.get(r.pse__Resource__c).add(certName);
            if (r.pse__Expiration_Date__c != null && r.pse__Expiration_Date__c <= expiryHorizon) {
                expiring++;
                expiringByPerson.put(r.pse__Resource__c, (expiringByPerson.containsKey(r.pse__Resource__c) ? expiringByPerson.get(r.pse__Resource__c) : 0) + 1);
            }
        }
        Decimal minCertified = ctx.num(s.Strategic_Skill_Min_Certified__c, 3);
        Integer covered = 0;
        BusinessHealthModel.Table skillTable = new BusinessHealthModel.Table('strategicSkills', 'Strategic skill coverage',
            'Certified active employees per skill you are selling toward (Business Health Settings: Strategic Skills).')
            .col('skill', 'Skill', 'text')
            .col('certified', 'Certified', 'number')
            .col('planned', 'Planned / expired', 'number')
            .col('target', 'Minimum', 'number')
            .col('status', 'Status', 'status');
        for (String k : strategic) {
            Integer n = certifiedBySkill.get(k).size();
            if (n >= minCertified) {
                covered++;
            }
            skillTable.rows.add(
                new Map<String, Object>{
                    'skill' => k,
                    'certified' => n,
                    'planned' => plannedBySkill.get(k).size(),
                    'target' => minCertified,
                    'status' => BusinessHealthModel.evaluate(n, minCertified, 'higher', 0.34)
                }
            );
        }
        page.addKpi(new BusinessHealthModel.Kpi('certsPerPerson', 'Certifications per employee', active.isEmpty() ? null : (Decimal.valueOf(achieved) / active.size()).setScale(1), 'number'))
            .target(ctx.num(s.Certs_Per_Employee_Target__c, 3), 'higher', 0.25)
            .note(achieved + ' current certifications across ' + active.size() + ' employees.' + (partnerPoints > 0 ? ' ' + partnerPoints.setScale(0) + ' partner program points.' : ''));
        page.addKpi(new BusinessHealthModel.Kpi('strategicCoverage', 'Strategic skills covered', BusinessHealthModel.pct(covered, strategic.size()), 'percent'))
            .target(100, 'higher', 0.34)
            .note(covered + ' of ' + strategic.size() + ' strategic skills have at least ' + minCertified.setScale(0) + ' certified people.');
        page.addKpi(new BusinessHealthModel.Kpi('expiring', 'Certifications expiring (90 days)', expiring, 'number'))
            .target(0, 'lower', 0)
            .note('Lapsed certifications count against Salesforce partner tier requirements.');

        // ---- charts -----------------------------------------------------------------------------
        List<String> labels = ctx.completeMonthLabels(12);
        // Inactive resources with no Last Date can't be placed in time; leave them out of
        // the history (and say so) rather than counting them as still employed.
        Integer undated = 0;
        for (Contact c : everyone) {
            if (!c.pse__Is_Resource_Active__c && c.pse__Last_Date__c == null) {
                undated++;
            }
        }
        List<Decimal> headcountSeries = new List<Decimal>();
        Date m = ctx.windowStart(12);
        for (Integer i = 0; i < 12; i++) {
            Date monthEnd = m.addMonths(i + 1).addDays(-1);
            Integer n = 0;
            for (Contact c : everyone) {
                Boolean undatedLeaver = !c.pse__Is_Resource_Active__c && c.pse__Last_Date__c == null;
                if (!undatedLeaver && c.pse__Start_Date__c != null && c.pse__Start_Date__c <= monthEnd &&
                    (c.pse__Last_Date__c == null || c.pse__Last_Date__c > monthEnd)) {
                    n++;
                }
            }
            headcountSeries.add(n);
        }
        page.charts.add(
            new BusinessHealthModel.Chart('headcount', 'Employee headcount at month end', 'line', 'number')
                .labels(labels)
                .addSeries('Employees', headcountSeries)
        );
        List<String> cloudNames = new List<String>(byCloud.keySet());
        cloudNames.sort();
        List<Decimal> cloudCounts = new List<Decimal>();
        for (String c : cloudNames) {
            cloudCounts.add(byCloud.get(c));
        }
        page.charts.add(
            new BusinessHealthModel.Chart('certsByCloud', 'Current certifications by Salesforce cloud', 'hbar', 'number')
                .labels(cloudNames)
                .addSeries('Certifications', cloudCounts)
        );

        // ---- tables -----------------------------------------------------------------------------
        page.tables.add(skillTable);
        BusinessHealthModel.Table personTable = new BusinessHealthModel.Table('certsByPerson', 'Certifications by person', null)
            .link('name', 'Employee', 'id')
            .col('role', 'Role', 'text')
            .col('count', 'Certifications', 'number')
            .col('strategic', 'Strategic', 'text')
            .col('expiring', 'Expiring (90d)', 'number');
        for (Contact c : active) {
            List<String> held = certsByPerson.containsKey(c.Id) ? certsByPerson.get(c.Id) : new List<String>();
            List<String> strategicHeld = new List<String>();
            for (String k : strategic) {
                if (certifiedBySkill.get(k).contains(c.Id)) {
                    strategicHeld.add(k);
                }
            }
            personTable.rows.add(
                new Map<String, Object>{
                    'id' => c.Id,
                    'name' => c.Name,
                    'role' => c.pse__Resource_Role__c,
                    'count' => held.size(),
                    'strategic' => String.join(strategicHeld, ', '),
                    'expiring' => expiringByPerson.containsKey(c.Id) ? expiringByPerson.get(c.Id) : 0
                }
            );
        }
        BusinessHealthModel.sortRowsAscending(personTable.rows, 'count');
        page.tables.add(personTable);

        BusinessHealthModel.Table leftTable = new BusinessHealthModel.Table('departures', 'Departures (T12M)', null)
            .link('name', 'Employee', 'id')
            .col('role', 'Role', 'text')
            .col('start', 'Start', 'date')
            .col('last', 'Last day', 'date')
            .col('tenure', 'Tenure (months)', 'number');
        for (Contact c : departures) {
            leftTable.rows.add(
                new Map<String, Object>{
                    'id' => c.Id,
                    'name' => c.Name,
                    'role' => c.pse__Resource_Role__c,
                    'start' => c.pse__Start_Date__c,
                    'last' => c.pse__Last_Date__c,
                    'tenure' => c.pse__Start_Date__c == null ? null : c.pse__Start_Date__c.monthsBetween(c.pse__Last_Date__c)
                }
            );
        }
        page.tables.add(leftTable);

        BusinessHealthModel.Table rolesTable = new BusinessHealthModel.Table('openRoles', 'Open roles', null)
            .link('name', 'Posting', 'id')
            .col('role', 'Role', 'text')
            .col('type', 'New / replacement', 'text')
            .col('requested', 'Requested', 'date')
            .col('target', 'Target fill', 'date')
            .col('status', 'Status', 'text');
        for (Candidate__c p : postings) {
            rolesTable.rows.add(
                new Map<String, Object>{
                    'id' => p.Id,
                    'name' => p.Name,
                    'role' => p.Role__c,
                    'type' => p.NewReplacement__c,
                    'requested' => p.RequestDate__c,
                    'target' => p.Target_Fill_Date__c,
                    'status' => p.Status__c
                }
            );
        }
        page.tables.add(rolesTable);

        page.signalMissedKpis();
        if (!postings.isEmpty() && postings[0].RequestDate__c != null && postings[0].RequestDate__c.daysBetween(asOf) > 365) {
            page.signal(BusinessHealthModel.STATUS_INFO, 'Open job postings are over a year old. Close stale postings, or track recruiting in Salesforce again.');
        }
        if (undated > 0) {
            page.dataGaps.add(undated + ' inactive resources have no Last Date, so their departures are missing from attrition and headcount history.');
        }
        page.dataGaps.add('Voluntary vs involuntary attrition and performance ratings are not stored on the resource record.');
        page.dataGaps.add('Salesforce partner tier and customer success scores come from the Partner Community and are not synced into this org.');
        return page;
    }

    /** Keyword -> cloud, checked in order, for certifications without a Salesforce Cloud value. */
    private static final List<List<String>> CLOUD_KEYWORDS = new List<List<String>>{
        new List<String>{ 'Agentforce', 'AI & Agentforce' },
        new List<String>{ 'AI ', 'AI & Agentforce' },
        new List<String>{ 'Data Cloud', 'Data Cloud' },
        new List<String>{ 'Sales Cloud', 'Sales Cloud' },
        new List<String>{ 'Service Cloud', 'Service Cloud' },
        new List<String>{ 'Field Service', 'Service Cloud' },
        new List<String>{ 'Experience Cloud', 'Experience Cloud' },
        new List<String>{ 'Community', 'Experience Cloud' },
        new List<String>{ 'Marketing', 'Marketing' },
        new List<String>{ 'Pardot', 'Marketing' },
        new List<String>{ 'CPQ', 'Revenue Cloud' },
        new List<String>{ 'Revenue', 'Revenue Cloud' },
        new List<String>{ 'Financial Services', 'Industries' },
        new List<String>{ 'Nonprofit', 'Industries' },
        new List<String>{ 'Commerce', 'Commerce' },
        new List<String>{ 'Tableau', 'Analytics' },
        new List<String>{ 'Analytics', 'Analytics' },
        new List<String>{ 'Architect', 'Architecture' },
        new List<String>{ 'Designer', 'Architecture' },
        new List<String>{ 'Developer', 'Platform & Development' },
        new List<String>{ 'App Builder', 'Platform & Development' },
        new List<String>{ 'Administrator', 'Admin' },
        new List<String>{ 'Business Analyst', 'Consulting' },
        new List<String>{ 'Strategy', 'Consulting' }
    };

    private static String cloudFor(String certName, String cloud) {
        if (String.isNotBlank(cloud)) {
            return cloud;
        }
        for (List<String> pair : CLOUD_KEYWORDS) {
            if (certName != null && (certName + ' ').containsIgnoreCase(pair[0])) {
                return pair[1];
            }
        }
        return 'Other';
    }
}
