/**
 * @group BusinessHealth
 *
 * @description Shared, practice-aware data loaders used by several Business Health
 * pages. Each loader is one SOQL query, so a page composes the handful it needs
 * without approaching governor limits.
 *
 * Revenue definitions (used consistently on every page):
 * - Delivered revenue: billable amount of approved/submitted timecards on
 *   non-Fixed-Price projects, plus approved milestone amounts (by Actual Date) on
 *   non-Time-and-Materials projects. Hybrid projects contribute both. This is the
 *   closest PSA proxy for recognized revenue.
 * - Bookings: Amount of Closed Won Opportunities by Close Date.
 * - Billed revenue: released Billing Events by Billing Event Date.
 * - Labor cost: timecard hours x timecard cost rate (falling back to the resource's
 *   default cost rate), across billable AND non-billable hours on client projects -
 *   so write-offs and unbilled effort show up as lost margin.
 */
public with sharing class BusinessHealthData {
    public static final Set<String> ACTIVE_PROJECT_STAGES = new Set<String>{ 'Planning', 'In Progress', 'On Hold', 'Wrapping_Up' };
    public static final Set<String> RECURRING_PRACTICES = new Set<String>{ 'Managed Services' };
    public static final String SALESFORCE_REFERRAL = 'Referral - Salesforce';

    // ---- timecard facts -------------------------------------------------------

    public class TimecardFact {
        public Id projectId;
        public String projectName;
        public Id accountId;
        public String accountName;
        public String practiceName;
        public String billingType;
        public Boolean clientProject;
        public Boolean recurring;
        public Id resourceId;
        public String resourceName;
        public String resourceRole;
        public String assignmentRole;
        public Boolean external;
        public Date endDate;
        public String monthKey;
        public Decimal hours;
        public Decimal billableHours;
        public Decimal revenue;
        public Decimal cost;
        public Boolean unbilled;
    }

    /**
     * @description Approved or submitted timecards ending in [fromDate, ctx.asOfDate],
     * practice-scoped by the PROJECT's practice (revenue and margin views).
     */
    public static List<TimecardFact> timecards(BusinessHealthContext ctx, Date fromDate) {
        return timecards(ctx, fromDate, 'pse__Project__r.pse__Practice__c');
    }

    /**
     * @description Same, practice-scoped by `practiceField` - pass
     * 'pse__Resource__r.pse__Practice__c' for people views (utilization), so a
     * practice's consultants count all their hours, whichever project they bill.
     */
    public static List<TimecardFact> timecards(BusinessHealthContext ctx, Date fromDate, String practiceField) {
        ctx.bind('tcFrom', fromDate);
        String soql =
            'SELECT pse__Project__c, pse__Project__r.Name, pse__Project__r.pse__Account__c, pse__Project__r.pse__Account__r.Name,' +
            ' pse__Project__r.pse__Practice__r.Name, pse__Project__r.pse__Billing_Type__c, pse__Project__r.pse__Opportunity__c,' +
            ' pse__Project__r.pse__Is_Billable__c, pse__Project__r.DCS_Primary_Practice__c, pse__Resource__c, pse__Resource__r.Name,' +
            ' pse__Resource__r.pse__Resource_Role__c, pse__Resource__r.pse__Default_Cost_Rate__c, pse__Assignment__r.pse__Role__c,' +
            ' pse__External_Resource__c, pse__End_Date__c, pse__Total_Hours__c, pse__Total_Billable_Amount__c, pse__Billable__c,' +
            ' pse__Billed__c, pse__Status__c, pse__Cost_Rate_Amount__c' +
            ' FROM pse__Timecard_Header__c' +
            ' WHERE pse__Status__c IN (\'Approved\', \'Submitted\') AND pse__End_Date__c >= :tcFrom AND pse__End_Date__c <= :asOf' +
            ctx.practiceClause(practiceField);
        List<TimecardFact> facts = new List<TimecardFact>();
        for (pse__Timecard_Header__c tc : (List<pse__Timecard_Header__c>) ctx.query(soql)) {
            pse__Proj__c p = tc.pse__Project__r;
            TimecardFact f = new TimecardFact();
            f.projectId = tc.pse__Project__c;
            f.projectName = p == null ? null : p.Name;
            f.accountId = p == null ? null : p.pse__Account__c;
            f.accountName = p == null || p.pse__Account__r == null ? null : p.pse__Account__r.Name;
            f.practiceName = p == null || p.pse__Practice__r == null ? 'Unassigned' : p.pse__Practice__r.Name;
            f.billingType = p == null ? null : p.pse__Billing_Type__c;
            f.clientProject = p != null && p.pse__Opportunity__c != null && p.pse__Is_Billable__c;
            f.recurring = p != null && isRecurring(f.practiceName, p.DCS_Primary_Practice__c, f.billingType);
            f.resourceId = tc.pse__Resource__c;
            f.resourceName = tc.pse__Resource__r == null ? null : tc.pse__Resource__r.Name;
            f.resourceRole = tc.pse__Resource__r == null ? null : tc.pse__Resource__r.pse__Resource_Role__c;
            f.assignmentRole = tc.pse__Assignment__r == null ? null : tc.pse__Assignment__r.pse__Role__c;
            f.external = tc.pse__External_Resource__c;
            f.endDate = tc.pse__End_Date__c;
            f.monthKey = BusinessHealthContext.monthKey(f.endDate);
            f.hours = nz(tc.pse__Total_Hours__c);
            f.billableHours = tc.pse__Billable__c ? f.hours : 0;
            f.revenue = tc.pse__Billable__c && f.billingType != 'Fixed Price' ? nz(tc.pse__Total_Billable_Amount__c) : 0;
            Decimal costRate = tc.pse__Cost_Rate_Amount__c != null && tc.pse__Cost_Rate_Amount__c > 0
                ? tc.pse__Cost_Rate_Amount__c
                : (tc.pse__Resource__r == null ? 0 : nz(tc.pse__Resource__r.pse__Default_Cost_Rate__c));
            f.cost = f.hours * costRate;
            f.unbilled = tc.pse__Billable__c && !tc.pse__Billed__c && tc.pse__Status__c == 'Approved' && f.revenue > 0;
            facts.add(f);
        }
        return facts;
    }

    public static Boolean isRecurring(String practiceName, String primaryPractice, String billingType) {
        return RECURRING_PRACTICES.contains(practiceName) ||
            RECURRING_PRACTICES.contains(primaryPractice) ||
            billingType == 'Subscription';
    }

    // ---- milestone revenue ----------------------------------------------------

    public class MilestoneFact {
        public Id projectId;
        public String projectName;
        public Id accountId;
        public String accountName;
        public String practiceName;
        public Boolean recurring;
        public Date actualDate;
        public String monthKey;
        public Decimal amount;
    }

    /** Approved milestones on non-T&M projects with Actual Date in [fromDate, asOf]. */
    public static List<MilestoneFact> milestoneRevenue(BusinessHealthContext ctx, Date fromDate) {
        ctx.bind('msFrom', fromDate);
        String soql =
            'SELECT pse__Project__c, pse__Project__r.Name, pse__Project__r.pse__Account__c, pse__Project__r.pse__Account__r.Name,' +
            ' pse__Project__r.pse__Practice__r.Name, pse__Project__r.DCS_Primary_Practice__c, pse__Project__r.pse__Billing_Type__c,' +
            ' pse__Actual_Date__c, pse__Milestone_Amount__c' +
            ' FROM pse__Milestone__c' +
            ' WHERE pse__Approved__c = true AND pse__Milestone_Amount__c > 0' +
            ' AND pse__Project__r.pse__Billing_Type__c != \'Time and Materials\'' +
            ' AND pse__Actual_Date__c >= :msFrom AND pse__Actual_Date__c <= :asOf' +
            ctx.practiceClause('pse__Project__r.pse__Practice__c');
        List<MilestoneFact> facts = new List<MilestoneFact>();
        for (pse__Milestone__c m : (List<pse__Milestone__c>) ctx.query(soql)) {
            pse__Proj__c p = m.pse__Project__r;
            MilestoneFact f = new MilestoneFact();
            f.projectId = m.pse__Project__c;
            f.projectName = p.Name;
            f.accountId = p.pse__Account__c;
            f.accountName = p.pse__Account__r == null ? null : p.pse__Account__r.Name;
            f.practiceName = p.pse__Practice__r == null ? 'Unassigned' : p.pse__Practice__r.Name;
            f.recurring = isRecurring(f.practiceName, p.DCS_Primary_Practice__c, p.pse__Billing_Type__c);
            f.actualDate = m.pse__Actual_Date__c;
            f.monthKey = BusinessHealthContext.monthKey(f.actualDate);
            f.amount = nz(m.pse__Milestone_Amount__c);
            facts.add(f);
        }
        return facts;
    }

    /** Delivered revenue by month key, from timecard + milestone facts. */
    public static Map<String, Decimal> deliveredByMonth(List<TimecardFact> tcs, List<MilestoneFact> ms) {
        Map<String, Decimal> byMonth = new Map<String, Decimal>();
        for (TimecardFact f : tcs) {
            add(byMonth, f.monthKey, f.revenue);
        }
        for (MilestoneFact m : ms) {
            add(byMonth, m.monthKey, m.amount);
        }
        return byMonth;
    }

    /** Delivered revenue by account Id (name kept in `names`). */
    public static Map<Id, Decimal> deliveredByAccount(
        List<TimecardFact> tcs,
        List<MilestoneFact> ms,
        Date fromDate,
        Date toDate,
        Map<Id, String> names
    ) {
        Map<Id, Decimal> byAccount = new Map<Id, Decimal>();
        for (TimecardFact f : tcs) {
            if (f.accountId != null && f.revenue != 0 && f.endDate >= fromDate && f.endDate <= toDate) {
                add(byAccount, f.accountId, f.revenue);
                names.put(f.accountId, f.accountName);
            }
        }
        for (MilestoneFact m : ms) {
            if (m.accountId != null && m.actualDate >= fromDate && m.actualDate <= toDate) {
                add(byAccount, m.accountId, m.amount);
                names.put(m.accountId, m.accountName);
            }
        }
        return byAccount;
    }

    // ---- bookings / billing ---------------------------------------------------

    /** Closed Won Opportunities with Close Date in [fromDate, asOf]. */
    public static List<Opportunity> wonOpportunities(BusinessHealthContext ctx, Date fromDate) {
        ctx.bind('oppFrom', fromDate);
        return (List<Opportunity>) ctx.query(
            'SELECT Id, Name, AccountId, Account.Name, Amount, CloseDate, CreatedDate, Type, LeadSource, AccountAE__c,' +
                ' Salesforce_ACV__c, RecordType.DeveloperName, Cloud_s_Included__c, Owner.Name' +
                ' FROM Opportunity WHERE IsWon = true AND CloseDate >= :oppFrom AND CloseDate <= :asOf' +
                ctx.practiceClause('pse__Practice__c')
        );
    }

    public static Map<String, Decimal> bookingsByMonth(List<Opportunity> won) {
        Map<String, Decimal> byMonth = new Map<String, Decimal>();
        for (Opportunity o : won) {
            add(byMonth, BusinessHealthContext.monthKey(o.CloseDate), nz(o.Amount));
        }
        return byMonth;
    }

    /** Released Billing Event totals by month, [fromDate, asOf]. */
    public static Map<String, Decimal> billedByMonth(BusinessHealthContext ctx, Date fromDate) {
        ctx.bind('beFrom', fromDate);
        Map<String, Decimal> byMonth = new Map<String, Decimal>();
        for (AggregateResult ar : ctx.aggregate(
            'SELECT CALENDAR_YEAR(pse__Date__c) y, CALENDAR_MONTH(pse__Date__c) m, SUM(pse__Summary_Amount__c) amt' +
                ' FROM pse__Billing_Event__c WHERE pse__Is_Released__c = true AND pse__Date__c >= :beFrom AND pse__Date__c <= :asOf' +
                ctx.practiceClause('pse__Project__r.pse__Practice__c') +
                ' GROUP BY CALENDAR_YEAR(pse__Date__c), CALENDAR_MONTH(pse__Date__c)'
        )) {
            add(byMonth, BusinessHealthContext.monthKey((Integer) ar.get('y'), (Integer) ar.get('m')), (Decimal) ar.get('amt'));
        }
        return byMonth;
    }

    // ---- projects / backlog ---------------------------------------------------

    /** Active client projects (has Opportunity, active stage), current field values. */
    public static List<pse__Proj__c> activeClientProjects(BusinessHealthContext ctx) {
        ctx.bind('activeStages', ACTIVE_PROJECT_STAGES);
        return (List<pse__Proj__c>) ctx.query(
            'SELECT Id, Name, pse__Account__c, pse__Account__r.Name, pse__Practice__r.Name, pse__Project_Manager__r.Name,' +
                ' pse__Stage__c, pse__Billing_Type__c, pse__Project_Status__c, pse__Financial_Status__c, pse__Schedule_Status__c,' +
                ' pse__Scope_Status__c, pse__Bookings__c, pse__Billings__c, pse__Scheduled_Time__c, Estimate_at_Complete__c,' +
                ' Budget_Variance__c, Remaining_Budget__c, pse__Planned_Hours__c, Billable_Hours_Total__c,' +
                ' pse__Scheduled_Hours_Remaining__c, pse__Non_Billable_Internal_Hours__c, pse__Non_Billable_External_Hours__c, pse__Start_Date__c, pse__End_Date__c, pse__Exclude_from_Backlog__c,' +
                ' DCS_Primary_Practice__c, Margin_Pct__c' +
                ' FROM pse__Proj__c WHERE pse__Is_Active__c = true AND pse__Opportunity__c != null' +
                ' AND pse__Stage__c IN :activeStages' +
                ctx.practiceClause('pse__Practice__c')
        );
    }

    /**
     * @description Percent of planned hours consumed. Fixed-fee time is usually logged
     * non-billable (revenue comes from milestones), so all hours count toward burn.
     */
    public static Decimal hoursBurnedPct(pse__Proj__c p) {
        Decimal logged = nz(p.Billable_Hours_Total__c) + nz(p.pse__Non_Billable_Internal_Hours__c) + nz(p.pse__Non_Billable_External_Hours__c);
        return BusinessHealthModel.pct(logged, p.pse__Planned_Hours__c);
    }

    /** Contracted but not yet billed revenue across active client projects. */
    public static Decimal backlog(List<pse__Proj__c> projects) {
        Decimal total = 0;
        for (pse__Proj__c p : projects) {
            if (!p.pse__Exclude_from_Backlog__c && p.Remaining_Budget__c != null && p.Remaining_Budget__c > 0) {
                total += p.Remaining_Budget__c;
            }
        }
        return total;
    }

    // ---- resources ------------------------------------------------------------

    /** Active PSA resources (Contacts), optionally scoped to a practice. */
    public static List<Contact> activeResources(BusinessHealthContext ctx) {
        return (List<Contact>) ctx.query(
            'SELECT Id, Name, pse__Resource_Role__c, pse__External_Resource__c, DCS_Billable_Goal__c, pse__Default_Cost_Rate__c,' +
                ' pse__Practice__r.Name, pse__Start_Date__c' +
                ' FROM Contact WHERE pse__Is_Resource__c = true AND pse__Is_Resource_Active__c = true' +
                ctx.practiceClause('pse__Practice__c') +
                ' ORDER BY Name'
        );
    }

    /**
     * @description Weekly billable hours goal. DCS_Billable_Goal__c is weekly (typically
     * 38-40), but some records carry an annual figure (e.g. 2040); anything above 80 is
     * treated as annual and divided by 52.
     */
    public static Decimal weeklyGoal(Contact c) {
        Decimal g = nz(c.DCS_Billable_Goal__c);
        return g > 80 ? (g / 52).setScale(1) : g;
    }

    /** Billable resources: internal or external, with a billable goal. */
    public static Boolean isBillableResource(Contact c) {
        return weeklyGoal(c) > 0 || c.pse__External_Resource__c;
    }

    // ---- rate card -------------------------------------------------------------

    /** Standard bill rate by assignment role label (Default_Rate_Card__mdt). */
    public static Map<String, Decimal> standardRates() {
        Map<String, Decimal> rates = new Map<String, Decimal>();
        for (Default_Rate_Card__mdt r : Default_Rate_Card__mdt.getAll().values()) {
            if (r.Price_Per_Hour__c != null) {
                rates.put(normalizeRole(r.MasterLabel), r.Price_Per_Hour__c);
            }
        }
        return rates;
    }

    /** Simple average of the Default Rate Card prices; 150 when none are configured. */
    public static Decimal averageStandardRate() {
        Map<String, Decimal> rates = standardRates();
        if (rates.isEmpty()) {
            return 150;
        }
        Decimal total = 0;
        for (Decimal r : rates.values()) {
            total += r;
        }
        return total / rates.size();
    }

    public static String normalizeRole(String role) {
        return role == null ? null : role.toLowerCase().replaceAll('[^a-z]', '');
    }

    // ---- derived metrics shared across pages -----------------------------------

    /** Labor cost by month on client projects (billable and non-billable hours). */
    public static Map<String, Decimal> clientCostByMonth(List<TimecardFact> tcs) {
        Map<String, Decimal> byMonth = new Map<String, Decimal>();
        for (TimecardFact f : tcs) {
            if (f.clientProject) {
                add(byMonth, f.monthKey, f.cost);
            }
        }
        return byMonth;
    }

    /** Gross margin % per month key: (delivered - client labor cost) / delivered. */
    public static List<Decimal> marginSeries(Map<String, Decimal> delivered, Map<String, Decimal> cost, List<String> keys) {
        List<Decimal> values = new List<Decimal>();
        for (String k : keys) {
            Decimal rev = nz(delivered.get(k));
            values.add(BusinessHealthModel.pct(rev - nz(cost.get(k)), rev));
        }
        return values;
    }

    public static Decimal marginPct(Map<String, Decimal> delivered, Map<String, Decimal> cost, List<String> keys) {
        Decimal rev = 0;
        Decimal c = 0;
        for (String k : keys) {
            rev += nz(delivered.get(k));
            c += nz(cost.get(k));
        }
        return BusinessHealthModel.pct(rev - c, rev);
    }

    public static final Decimal DELIVERY_MIN_QUARTER_HOURS = 40;

    /**
     * @description Internal delivery resources - the utilization denominator: active
     * employees (not subcontractors) with a billable goal, or who logged at least
     * DELIVERY_MIN_QUARTER_HOURS billable hours in the 3 months before as-of. Billable
     * goals are sparsely populated, so the goal alone would miss people who bill.
     */
    public static Map<Id, Contact> internalBillable(List<Contact> resources, List<TimecardFact> tcs, Date asOf) {
        Date since = asOf.addMonths(-3);
        Map<Id, Decimal> recentBillable = new Map<Id, Decimal>();
        for (TimecardFact f : tcs) {
            if (f.endDate > since) {
                add(recentBillable, f.resourceId, f.billableHours);
            }
        }
        Map<Id, Contact> result = new Map<Id, Contact>();
        for (Contact c : resources) {
            if (!c.pse__External_Resource__c && (weeklyGoal(c) > 0 || nz(recentBillable.get(c.Id)) >= DELIVERY_MIN_QUARTER_HOURS)) {
                result.put(c.Id, c);
            }
        }
        return result;
    }

    /**
     * @description Billable utilization % per month for the given resource set:
     * billable hours / (resources x standard hours/week x weeks in month). Uses the
     * CURRENT roster for every month, so it is approximate for months before recent
     * hires or departures.
     */
    public static List<Decimal> utilizationSeries(
        List<TimecardFact> tcs,
        Set<Id> resourceIds,
        List<String> keys,
        Decimal hoursPerWeek
    ) {
        Map<String, Decimal> billable = new Map<String, Decimal>();
        for (TimecardFact f : tcs) {
            if (resourceIds.contains(f.resourceId)) {
                add(billable, f.monthKey, f.billableHours);
            }
        }
        List<Decimal> values = new List<Decimal>();
        for (String k : keys) {
            Integer y = Integer.valueOf(k.left(4));
            Integer m = Integer.valueOf(k.right(2));
            Decimal weeks = Decimal.valueOf(Date.daysInMonth(y, m)) / 7;
            values.add(BusinessHealthModel.pct(nz(billable.get(k)), resourceIds.size() * hoursPerWeek * weeks));
        }
        return values;
    }

    public static final Integer WIP_WINDOW_DAYS = 90;

    /**
     * @description Unbilled WIP split into [current, stale]: approved billable time
     * not yet billed, ending within WIP_WINDOW_DAYS of as-of (current), or older
     * (stale). Stale unbilled time is usually billed outside PSA or never billed -
     * a data-hygiene or write-off question, not cash about to arrive - so it is
     * reported separately rather than inflating WIP.
     */
    public static List<Decimal> unbilledWip(List<TimecardFact> tcs, Date asOf) {
        Date cutoff = asOf.addDays(-WIP_WINDOW_DAYS);
        Decimal current = 0;
        Decimal stale = 0;
        for (TimecardFact f : tcs) {
            if (f.unbilled) {
                if (f.endDate > cutoff) {
                    current += f.revenue;
                } else {
                    stale += f.revenue;
                }
            }
        }
        return new List<Decimal>{ current, stale };
    }

    /** Recurring (managed services / subscription) delivered revenue by month. */
    public static Map<String, Decimal> recurringByMonth(List<TimecardFact> tcs, List<MilestoneFact> ms) {
        Map<String, Decimal> byMonth = new Map<String, Decimal>();
        for (TimecardFact f : tcs) {
            if (f.recurring) {
                add(byMonth, f.monthKey, f.revenue);
            }
        }
        for (MilestoneFact m : ms) {
            if (m.recurring) {
                add(byMonth, m.monthKey, m.amount);
            }
        }
        return byMonth;
    }

    /** Share (0-100) of total held by the top `n` values. */
    public static Decimal topShare(Map<Id, Decimal> byKey, Integer n) {
        List<Decimal> values = byKey.values();
        values.sort();
        Decimal total = 0;
        Decimal top = 0;
        for (Integer i = 0; i < values.size(); i++) {
            total += values[i];
            if (i >= values.size() - n) {
                top += values[i];
            }
        }
        return BusinessHealthModel.pct(top, total);
    }

    /** Resources whose Last Date falls in (fromDate, asOf] - departures. */
    public static List<Contact> departures(BusinessHealthContext ctx, Date fromDate) {
        ctx.bind('depFrom', fromDate);
        return (List<Contact>) ctx.query(
            'SELECT Id, Name, pse__Resource_Role__c, pse__Last_Date__c, pse__Start_Date__c, pse__External_Resource__c' +
                ' FROM Contact WHERE pse__Is_Resource__c = true AND pse__External_Resource__c = false' +
                ' AND pse__Last_Date__c > :depFrom AND pse__Last_Date__c <= :asOf' +
                ctx.practiceClause('pse__Practice__c') +
                ' ORDER BY pse__Last_Date__c DESC'
        );
    }

    /** Annualized attrition % over the trailing 12 months. */
    public static Decimal attritionPct(Integer departures, Integer currentHeadcount) {
        // Average headcount approximated as current + half of those who left.
        Decimal avgHeadcount = currentHeadcount + departures / 2.0;
        return BusinessHealthModel.pct(departures, avgHeadcount);
    }

    /** The last `count` entries of `values`. */
    public static List<Decimal> tail(List<Decimal> values, Integer count) {
        List<Decimal> result = new List<Decimal>();
        for (Integer i = Math.max(0, values.size() - count); i < values.size(); i++) {
            result.add(values[i]);
        }
        return result;
    }

    public static List<String> tailLabels(List<String> values, Integer count) {
        List<String> result = new List<String>();
        for (Integer i = Math.max(0, values.size() - count); i < values.size(); i++) {
            result.add(values[i]);
        }
        return result;
    }

    /** Rolling ratio sum(num, last w)/sum(den, last w) for each key in `keys`. */
    public static List<Decimal> rollingRatio(Map<String, Decimal> num, Map<String, Decimal> den, List<String> allKeys, Integer window) {
        List<Decimal> values = new List<Decimal>();
        for (Integer i = 0; i < allKeys.size(); i++) {
            Decimal n = 0;
            Decimal d = 0;
            for (Integer j = Math.max(0, i - window + 1); j <= i; j++) {
                n += nz(num.get(allKeys[j]));
                d += nz(den.get(allKeys[j]));
            }
            Decimal r = BusinessHealthModel.ratio(n, d);
            values.add(r == null ? null : r.setScale(2));
        }
        return values;
    }

    // ---- small helpers ---------------------------------------------------------

    public static Decimal nz(Decimal d) {
        return d == null ? 0 : d;
    }

    public static void add(Map<String, Decimal> m, String key, Decimal value) {
        if (key == null || value == null) {
            return;
        }
        m.put(key, nz(m.get(key)) + value);
    }

    public static void add(Map<Id, Decimal> m, Id key, Decimal value) {
        if (key == null || value == null) {
            return;
        }
        m.put(key, nz(m.get(key)) + value);
    }

    /** Values for `keys` in order, zero-filled. */
    public static List<Decimal> series(Map<String, Decimal> byKey, List<String> keys) {
        List<Decimal> values = new List<Decimal>();
        for (String k : keys) {
            values.add(nz(byKey.get(k)).setScale(0));
        }
        return values;
    }

    public static Decimal sumLast(Map<String, Decimal> byKey, List<String> keys, Integer lastN) {
        Decimal total = 0;
        for (Integer i = Math.max(0, keys.size() - lastN); i < keys.size(); i++) {
            total += nz(byKey.get(keys[i]));
        }
        return total;
    }

    public static Decimal sum(Map<String, Decimal> byKey) {
        Decimal total = 0;
        for (Decimal v : byKey.values()) {
            total += nz(v);
        }
        return total;
    }

    /** Service lines for an Opportunity from Cloud(s) Included; 'Unspecified' if blank. */
    public static List<String> serviceLines(Opportunity o) {
        if (String.isBlank(o.Cloud_s_Included__c)) {
            return new List<String>{ 'Unspecified' };
        }
        return o.Cloud_s_Included__c.split(';');
    }

    /** Salesforce relationship bucket: Sourced by Salesforce | Salesforce AE involved | Own team. */
    public static String sourcing(Opportunity o) {
        if (o.LeadSource == SALESFORCE_REFERRAL) {
            return 'Sourced by Salesforce';
        }
        if (String.isNotBlank(o.AccountAE__c) || nz(o.Salesforce_ACV__c) > 0) {
            return 'Salesforce AE involved';
        }
        return 'Own team';
    }

    public static Boolean isExistingCustomer(Opportunity o) {
        return o.Type != null && (o.Type.startsWith('Existing') || o.LeadSource == 'Repeat Purchase' || o.LeadSource == 'Returning Customer');
    }
}
