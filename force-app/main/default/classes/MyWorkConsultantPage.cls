/**
 * @group BusinessHealth
 *
 * @description My Work - Consultant: the running user's billable hours and utilization
 * against their goal, what is scheduled for the next four weeks, timecard compliance,
 * their current assignments, where their hours went, and their certifications.
 */
public with sharing class MyWorkConsultantPage implements BusinessHealthPageBuilder {
    private static final Integer EXPIRY_DAYS = 90;

    public BusinessHealthModel.HealthPage build(BusinessHealthContext ctx) {
        BusinessHealthModel.HealthPage page = new BusinessHealthModel.HealthPage(
            'my-consultant',
            'My utilization & time',
            'Am I on track for my billable goal, is my next month booked, and is my time in?',
            'Consultant'
        );
        Contact me = MyWorkSupport.resourceFor(ctx.userId);
        if (me == null) {
            MyWorkSupport.noResource(page);
            return page;
        }
        Date asOf = ctx.asOfDate;
        MyWorkSupport.Utilization u = MyWorkSupport.addUtilization(page, ctx, me, true);

        // ---- assignments ------------------------------------------------------------------
        Date assignmentFrom = asOf.addDays(-14);
        BusinessHealthModel.Table assignments = new BusinessHealthModel.Table('assignments', 'My assignments',
            'Current and recently ended assignments. Remaining = planned hours minus hours submitted.')
            .link('project', 'Project', 'projectId')
            .col('role', 'Role', 'text')
            .col('start', 'Start', 'date')
            .col('end', 'End', 'date')
            .col('planned', 'Planned hrs', 'hours')
            .col('used', 'Submitted hrs', 'hours')
            .col('remaining', 'Remaining hrs', 'hours')
            .col('billable', 'Billable', 'text');
        Decimal remainingTotal = 0;
        Integer active = 0;
        for (pse__Assignment__c a : [
            SELECT pse__Project__c, pse__Project__r.Name, pse__Role__c, pse__Start_Date__c, pse__End_Date__c, pse__Planned_Hours__c,
                pse__Billable_Hours_Submitted__c, pse__Non_Billable_Hours_Submitted__c, pse__Is_Billable__c
            FROM pse__Assignment__c
            WHERE pse__Resource__c = :me.Id AND pse__End_Date__c >= :assignmentFrom
            WITH USER_MODE
            ORDER BY pse__End_Date__c
            LIMIT 100
        ]) {
            Decimal used = BusinessHealthData.nz(a.pse__Billable_Hours_Submitted__c) + BusinessHealthData.nz(a.pse__Non_Billable_Hours_Submitted__c);
            Decimal remaining = a.pse__Planned_Hours__c == null ? null : Math.max(a.pse__Planned_Hours__c - used, 0);
            if (a.pse__Start_Date__c <= asOf && a.pse__End_Date__c >= asOf) {
                active++;
                remainingTotal += BusinessHealthData.nz(remaining);
            }
            assignments.rows.add(
                new Map<String, Object>{
                    'projectId' => a.pse__Project__c,
                    'project' => a.pse__Project__r.Name,
                    'role' => a.pse__Role__c,
                    'start' => a.pse__Start_Date__c,
                    'end' => a.pse__End_Date__c,
                    'planned' => a.pse__Planned_Hours__c,
                    'used' => used,
                    'remaining' => remaining,
                    'billable' => a.pse__Is_Billable__c ? 'Yes' : 'No'
                }
            );
        }
        page.addKpi(new BusinessHealthModel.Kpi('assignments', 'Active assignments', active, 'number'))
            .note(remainingTotal.setScale(0) + ' planned hours remaining on them.');

        // ---- certifications -------------------------------------------------------------------
        Integer certCount = 0;
        Integer expiring = 0;
        List<String> strategicHeld = new List<String>();
        Date expiryHorizon = asOf.addDays(EXPIRY_DAYS);
        List<pse__Skill_Certification_Rating__c> certs = [
            SELECT pse__Skill_Certification__r.Name, pse__Expiration_Date__c, Status__c, IsPlanned__c
            FROM pse__Skill_Certification_Rating__c
            WHERE pse__Resource__c = :me.Id AND pse__Skill_Certification__r.pse__Skill_Or_Certification__c = 'Certification'
            WITH USER_MODE
        ];
        for (pse__Skill_Certification_Rating__c r : certs) {
            Boolean current = !r.IsPlanned__c && r.Status__c != 'Submitted' && (r.pse__Expiration_Date__c == null || r.pse__Expiration_Date__c >= asOf);
            if (!current) {
                continue;
            }
            certCount++;
            if (r.pse__Expiration_Date__c != null && r.pse__Expiration_Date__c <= expiryHorizon) {
                expiring++;
            }
            for (String k : ctx.strategicSkills()) {
                if (r.pse__Skill_Certification__r.Name != null && r.pse__Skill_Certification__r.Name.containsIgnoreCase(k) && !strategicHeld.contains(k)) {
                    strategicHeld.add(k);
                }
            }
        }
        BusinessHealthModel.Kpi certKpi = page.addKpi(new BusinessHealthModel.Kpi('certifications', 'My certifications', certCount, 'number'));
        if (certs.isEmpty()) {
            certKpi.markUnavailable('No certifications are recorded on your PSA resource. Add them under Skills & Certifications so staffing can find you.');
        } else {
            certKpi.target(ctx.num(ctx.goals.Certs_Per_Employee_Target__c, 3), 'higher', 0.34)
                .note((strategicHeld.isEmpty() ? 'None in strategic skills' : 'Strategic: ' + String.join(strategicHeld, ', ')) +
                    (expiring > 0 ? '. ' + expiring + ' expiring in ' + EXPIRY_DAYS + ' days.' : '.'));
        }

        // ---- hours by project chart and timecard table ------------------------------------------
        List<String> projectNames = new List<String>(u.hoursByProject.keySet());
        List<BusinessHealthModel.RowSorter> sorted = new List<BusinessHealthModel.RowSorter>();
        for (String pn : projectNames) {
            sorted.add(new BusinessHealthModel.RowSorter(new Map<String, Object>{ 'n' => pn, 'h' => u.hoursByProject.get(pn) }, 'h', true));
        }
        sorted.sort();
        List<String> names = new List<String>();
        List<Decimal> hours = new List<Decimal>();
        for (Integer i = 0; i < Math.min(8, sorted.size()); i++) {
            names.add(((String) sorted[i].row.get('n')).abbreviate(34));
            hours.add(((Decimal) sorted[i].row.get('h')).setScale(1));
        }
        page.charts.add(
            new BusinessHealthModel.Chart('hoursByProject', 'Where my hours went, last 4 weeks', 'hbar', 'hours')
                .labels(names)
                .addSeries('Hours', hours)
                .metric('util4')
        );

        BusinessHealthModel.Table weeks = new BusinessHealthModel.Table('myWeeks', 'My timecards by week',
            'Most recent first. Status shows the least-advanced timecard for the week.')
            .col('weekEnding', 'Week ending', 'date')
            .col('billable', 'Billable + credited hrs', 'hours')
            .col('nonBillable', 'Other hrs', 'hours')
            .col('total', 'Total hrs', 'hours')
            .col('status', 'Status', 'text')
            .col('flag', 'Flag', 'text');
        for (Integer w = u.weeks.size() - 1; w >= 0; w--) {
            Date wk = u.weeks[w];
            Decimal b = BusinessHealthData.nz(u.utilizedByWeek.get(wk));
            Decimal nb = BusinessHealthData.nz(u.otherByWeek.get(wk));
            String status = u.statusByWeek.get(wk);
            String flag = b + nb < ctx.hoursPerWeek() * MyWorkSupport.UNDER_LOGGED_SHARE ? 'Under-logged' : (status == 'Saved' ? 'Not submitted' : '');
            weeks.rows.add(new Map<String, Object>{ 'weekEnding' => wk.addDays(6), 'billable' => b, 'nonBillable' => nb, 'total' => b + nb,
                'status' => status == null ? 'No timecard' : status, 'flag' => flag });
        }
        weeks.metric = 'missingTimecards';
        page.tables.add(assignments);
        page.tables.add(weeks);

        page.signalMissedKpis();
        if (u.scheduled4 == 0) {
            page.signal(BusinessHealthModel.STATUS_WARN, 'Nothing billable or credited is scheduled for you in the next 4 weeks. Talk to your resource manager about your next project.', 'scheduled4');
        }
        page.briefMetrics = new List<String>{ 'util4', 'scheduled4', 'missingTimecards', 'savedTimecards' };
        return page;
    }
}
