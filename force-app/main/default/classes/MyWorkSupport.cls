/**
 * @group BusinessHealth
 *
 * @description Shared pieces of the My Work (personal) views: finding the running user's
 * PSA resource record, and the personal utilization / schedule / timecard block used by
 * both the Consultant and Solution Architect views.
 *
 * Weeks run Sunday to Saturday (Date.toStartOfWeek), matching PSA's week-ending-Saturday
 * timecards and weekly Est vs Actuals rows. Only complete weeks (ending on or before the
 * as-of date) count as actuals.
 */
public with sharing class MyWorkSupport {
    public static final Integer PAST_WEEKS = 12;
    public static final Integer FUTURE_WEEKS = 4;
    /** A week with less than this share of standard hours logged counts as a missing timecard. */
    public static final Decimal UNDER_LOGGED_SHARE = 0.5;

    /**
     * @description The PSA resource Contact for a user, or null. Uses the org's own
     * mapping first - User.FFResourceContactId__c, which the FF_PROJECT_SYNC_PO_AND_PM
     * flow also uses to set each project's Project Manager from its owner - then falls
     * back to the PSA Salesforce User link on the Contact (active resource first).
     */
    public static Contact resourceFor(Id userId) {
        List<User> users = [SELECT FFResourceContactId__c FROM User WHERE Id = :userId WITH USER_MODE LIMIT 1];
        Id mapped = null;
        if (!users.isEmpty() && String.isNotBlank(users[0].FFResourceContactId__c)) {
            try {
                mapped = Id.valueOf(users[0].FFResourceContactId__c.trim());
            } catch (StringException e) {
                mapped = null; // not a valid Id; fall back to the PSA link
            }
        }
        List<Contact> contacts = [
            SELECT Id, Name, pse__Resource_Role__c, DCS_Billable_Goal__c, pse__Utilization_Target__c, pse__External_Resource__c,
                pse__Practice__r.Name, pse__Is_Resource_Active__c, pse__Region__c
            FROM Contact
            WHERE Id = :mapped OR pse__Salesforce_User__c = :userId
            WITH USER_MODE
            ORDER BY pse__Is_Resource_Active__c DESC
            LIMIT 5
        ];
        for (Contact c : contacts) {
            if (c.Id == mapped) {
                return c;
            }
        }
        return contacts.isEmpty() ? null : contacts[0];
    }

    /** A page saying no PSA resource is linked, so delivery data can't be matched. */
    public static void noResource(BusinessHealthModel.HealthPage page) {
        page.addKpi(new BusinessHealthModel.Kpi('noResource', 'PSA resource record', null, 'number'))
            .markUnavailable('No PSA resource (Contact) is linked to your Salesforce user, so your projects, assignments and timecards cannot be matched to you.');
        page.signal(BusinessHealthModel.STATUS_INFO, 'Ask your Salesforce admin to set FF Resource Contact Id on your user, or Salesforce User on your resource Contact.');
        page.dataGaps.add('Neither your user\'s FF Resource Contact Id nor any resource Contact\'s Salesforce User points to you.');
    }

    /**
     * @description Personal utilization target (percent): the Utilization Target
     * on the resource Contact; when that is blank or 0, the personal goal set's Delivery
     * Utilization Target, else the target for the resource's role.
     */
    public static Decimal utilizationTarget(BusinessHealthContext ctx, Contact c) {
        if (BusinessHealthData.hasUtilizationTarget(c)) {
            return c.pse__Utilization_Target__c;
        }
        if (ctx.userGoalSet != null && ctx.userGoalSet.Delivery_Utilization_Target__c != null) {
            return ctx.userGoalSet.Delivery_Utilization_Target__c;
        }
        return ctx.roleTarget(c.pse__Resource_Role__c);
    }

    /**
     * @description Weekly billable hours goal: standard hours x the Utilization Target when
     * the resource Contact has one (so hours and utilization agree), else the resource's DCS
     * Billable Goal, else standard hours x the fallback target.
     */
    public static Decimal weeklyGoalHours(BusinessHealthContext ctx, Contact c, Decimal targetPct) {
        Decimal g = BusinessHealthData.weeklyGoal(c);
        return g > 0 && !BusinessHealthData.hasUtilizationTarget(c) ? g : (ctx.hoursPerWeek() * targetPct / 100).setScale(1);
    }

    /** First day (Sunday) of the latest complete week on or before the as-of date. */
    public static Date lastCompleteWeekStart(Date asOf) {
        return asOf.addDays(-6).toStartOfWeek();
    }

    public static String weekLabel(Date weekStart) {
        Date weekEnd = weekStart.addDays(6);
        return Datetime.newInstance(weekEnd.year(), weekEnd.month(), weekEnd.day()).format('M/d');
    }

    public class Utilization {
        public Decimal targetPct;
        public Decimal weeklyGoal;
        /** Billable + PSA credited hours (see BusinessHealthData); excluded hours come off available hours. */
        public Decimal lastWeekUtilized = 0;
        public Decimal utilized4 = 0;
        public Decimal utilizedYtd = 0;
        public Decimal excluded4 = 0;
        public Decimal excludedYtd = 0;
        public Integer weeksYtd = 0;
        public Decimal scheduled4 = 0;
        public Integer underLoggedWeeks = 0;
        public Integer savedTimecards = 0;
        public List<Date> weeks = new List<Date>();
        public Map<Date, Decimal> utilizedByWeek = new Map<Date, Decimal>();
        public Map<Date, Decimal> otherByWeek = new Map<Date, Decimal>();
        public Map<Date, Decimal> scheduledByWeek = new Map<Date, Decimal>();
        public Map<Date, String> statusByWeek = new Map<Date, String>();
        public Map<String, Decimal> hoursByProject = new Map<String, Decimal>();
    }

    /**
     * @description Loads the resource's timecards (year to date and the trailing
     * PAST_WEEKS weeks) and scheduled billable or credited hours (next FUTURE_WEEKS weeks), and
     * adds the utilization KPIs and weekly hours chart to the page.
     * @param includeCompliance also add timecard compliance KPIs (missing / unsubmitted)
     */
    public static Utilization addUtilization(BusinessHealthModel.HealthPage page, BusinessHealthContext ctx, Contact c, Boolean includeCompliance) {
        Utilization u = new Utilization();
        u.targetPct = utilizationTarget(ctx, c);
        u.weeklyGoal = weeklyGoalHours(ctx, c, u.targetPct);
        Decimal hpw = ctx.hoursPerWeek();
        Date lastWeek = lastCompleteWeekStart(ctx.asOfDate);
        Date firstWeek = lastWeek.addDays(-7 * (PAST_WEEKS - 1));
        Date yearStart = Date.newInstance(ctx.asOfDate.year(), 1, 1);
        Date from0 = yearStart < firstWeek ? yearStart : firstWeek;
        Date lastWeekEnd = lastWeek.addDays(6);
        for (Integer w = 0; w < PAST_WEEKS; w++) {
            u.weeks.add(firstWeek.addDays(7 * w));
        }

        for (pse__Timecard_Header__c tc : [
            SELECT pse__End_Date__c, pse__Total_Hours__c, pse__Billable__c, pse__Time_Credited__c, pse__Time_Excluded__c,
                pse__Exclude_From_Utilization__c, pse__Status__c, pse__Project__r.Name
            FROM pse__Timecard_Header__c
            WHERE pse__Resource__c = :c.Id AND pse__End_Date__c >= :from0 AND pse__End_Date__c <= :lastWeekEnd
            WITH USER_MODE
        ]) {
            Date wk = tc.pse__End_Date__c.toStartOfWeek();
            Decimal h = BusinessHealthData.nz(tc.pse__Total_Hours__c);
            Boolean counts = tc.pse__Status__c != 'Rejected' && !tc.pse__Exclude_From_Utilization__c;
            Boolean utilized = counts && (tc.pse__Billable__c || tc.pse__Time_Credited__c);
            Decimal excluded = counts && !utilized && tc.pse__Time_Excluded__c ? h : 0;
            if (wk >= yearStart) {
                u.utilizedYtd += utilized ? h : 0;
                u.excludedYtd += excluded;
            }
            if (wk >= lastWeek.addDays(-21)) {
                u.utilized4 += utilized ? h : 0;
                u.excluded4 += excluded;
            }
            if (wk == lastWeek && utilized) {
                u.lastWeekUtilized += h;
            }
            if (wk < firstWeek) {
                continue;
            }
            Map<Date, Decimal> bucket = utilized ? u.utilizedByWeek : u.otherByWeek;
            bucket.put(wk, BusinessHealthData.nz(bucket.get(wk)) + h);
            if (tc.pse__Status__c == 'Saved') {
                u.savedTimecards++;
            }
            String prior = u.statusByWeek.get(wk);
            // Show the least-advanced status for the week (Saved before Submitted before Approved).
            if (prior == null || rank(tc.pse__Status__c) < rank(prior)) {
                u.statusByWeek.put(wk, tc.pse__Status__c);
            }
            if (wk >= lastWeek.addDays(-21) && tc.pse__Project__r != null) {
                BusinessHealthData.add(u.hoursByProject, tc.pse__Project__r.Name, h);
            }
        }
        for (Date d = yearStart.toStartOfWeek(); d <= lastWeek; d = d.addDays(7)) {
            u.weeksYtd++;
        }
        for (Integer w = PAST_WEEKS - 4; w < PAST_WEEKS; w++) {
            Date wk = u.weeks[w];
            Decimal logged = BusinessHealthData.nz(u.utilizedByWeek.get(wk)) + BusinessHealthData.nz(u.otherByWeek.get(wk));
            if (logged < hpw * UNDER_LOGGED_SHARE) {
                u.underLoggedWeeks++;
            }
        }

        // Scheduled billable or credited hours, next FUTURE_WEEKS weeks.
        Date futureStart = lastWeek.addDays(7);
        Date futureEnd = futureStart.addDays(7 * FUTURE_WEEKS - 1);
        for (AggregateResult ar : [
            SELECT pse__End_Date__c wkEnd, SUM(pse__Estimated_Hours__c) hrs
            FROM pse__Est_Vs_Actuals__c
            WHERE pse__Resource__c = :c.Id AND pse__Time_Period_Type__c = 'Week' AND pse__Assignment__r.pse__Exclude_From_Utilization__c = false
                AND (pse__Assignment__r.pse__Is_Billable__c = true OR pse__Assignment__r.pse__Time_Credited__c = true)
                AND pse__End_Date__c >= :futureStart AND pse__End_Date__c <= :futureEnd
            WITH USER_MODE
            GROUP BY pse__End_Date__c
        ]) {
            Date wk = ((Date) ar.get('wkEnd')).toStartOfWeek();
            Decimal h = BusinessHealthData.nz((Decimal) ar.get('hrs'));
            u.scheduledByWeek.put(wk, BusinessHealthData.nz(u.scheduledByWeek.get(wk)) + h);
            u.scheduled4 += h;
        }

        page.addKpi(new BusinessHealthModel.Kpi('lastWeekBillable', 'Billable + credited hours, last week', u.lastWeekUtilized.setScale(1), 'hours'))
            .target(u.weeklyGoal, 'higher', 0.15)
            .note('Week ending ' + lastWeek.addDays(6).format() + '. Your weekly goal is ' + u.weeklyGoal.setScale(1) + ' hours.');
        String targetSource = BusinessHealthData.hasUtilizationTarget(c)
            ? 'Your target: ' + u.targetPct.setScale(0) + '% (Utilization Target on your resource record).'
            : 'Target: ' + u.targetPct.setScale(0) + '%, the default for ' +
                (String.isBlank(c.pse__Resource_Role__c) ? 'your role' : c.pse__Resource_Role__c) +
                '. Your resource record has no Utilization Target.';
        Decimal util4 = BusinessHealthModel.pct(u.utilized4, Math.max(hpw * 4 - u.excluded4, 0));
        Decimal utilYtd = BusinessHealthModel.pct(u.utilizedYtd, Math.max(hpw * Math.max(1, u.weeksYtd) - u.excludedYtd, 0));
        page.addKpi(new BusinessHealthModel.Kpi('util4', 'Utilization, last 4 weeks', util4, 'percent'))
            .target(u.targetPct, 'higher', 0.1)
            .note('Billable + credited hours / available hours (' + hpw.setScale(0) +
                ' a week, less time PSA excludes such as pre-sales). ' + targetSource + BusinessHealthModel.ofTarget(util4, u.targetPct, 'your target'));
        page.addKpi(new BusinessHealthModel.Kpi('utilYtd', 'Utilization, year to date', utilYtd, 'percent'))
            .target(u.targetPct, 'higher', 0.1)
            .note(u.utilizedYtd.setScale(0) + ' billable + credited hours over ' + u.weeksYtd + ' weeks' +
                (u.excludedYtd > 0 ? ', with ' + u.excludedYtd.setScale(0) + ' excluded hours taken out of available time.' : '.') +
                BusinessHealthModel.ofTarget(utilYtd, u.targetPct, 'your target'));
        page.addKpi(new BusinessHealthModel.Kpi('scheduled4', 'Scheduled, next 4 weeks', BusinessHealthModel.pct(u.scheduled4, hpw * FUTURE_WEEKS), 'percent'))
            .target(u.targetPct, 'higher', 0.2)
            .note(u.scheduled4.setScale(0) + ' hours on your billable or credited assignment schedules. Low means you need your next project lined up.');
        if (includeCompliance) {
            page.addKpi(new BusinessHealthModel.Kpi('missingTimecards', 'Weeks under-logged (last 4)', u.underLoggedWeeks, 'number'))
                .target(0, 'lower', 0)
                .note('Weeks with less than ' + (hpw * UNDER_LOGGED_SHARE).setScale(0) + ' hours logged in total (billable, non-billable and PTO).');
            page.addKpi(new BusinessHealthModel.Kpi('savedTimecards', 'Timecards saved, not submitted', u.savedTimecards, 'number'))
                .target(0, 'lower', 0)
                .note('Saved timecards from the last ' + PAST_WEEKS + ' weeks. Unsubmitted time cannot be approved or billed.');
        }

        // Weekly hours chart: past weeks actuals, next weeks scheduled.
        List<String> labels = new List<String>();
        List<Decimal> utilized = new List<Decimal>();
        List<Decimal> other = new List<Decimal>();
        List<Decimal> scheduled = new List<Decimal>();
        for (Date wk : u.weeks) {
            labels.add(weekLabel(wk));
            utilized.add(BusinessHealthData.nz(u.utilizedByWeek.get(wk)).setScale(1));
            other.add(BusinessHealthData.nz(u.otherByWeek.get(wk)).setScale(1));
            scheduled.add(null);
        }
        for (Integer w = 0; w < FUTURE_WEEKS; w++) {
            Date wk = futureStart.addDays(7 * w);
            labels.add(weekLabel(wk));
            utilized.add(null);
            other.add(null);
            scheduled.add(BusinessHealthData.nz(u.scheduledByWeek.get(wk)).setScale(1));
        }
        page.charts.add(
            new BusinessHealthModel.Chart('weeklyHours', 'Your hours by week: logged and scheduled', 'bar', 'hours')
                .labels(labels)
                .addSeries('Billable + credited', utilized)
                .addSeries('Other', other)
                .addSeries('Scheduled', scheduled)
                .target(u.weeklyGoal, 'Weekly goal')
                .metric('util4')
        );
        return u;
    }

    private static Integer rank(String status) {
        return status == 'Saved' ? 0 : status == 'Rejected' ? 1 : status == 'Submitted' ? 2 : 3;
    }

    /** Sortable number of days from the as-of date (negative = in the past). */
    public static Integer daysFrom(Date asOf, Date d) {
        return d == null ? null : asOf.daysBetween(d);
    }
}
