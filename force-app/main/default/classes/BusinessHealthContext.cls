/**
 * @group BusinessHealth
 *
 * @description Request-scoped context for building a Business Health page: the as-of
 * date every trailing window is measured back from, the optional practice scope, and
 * the goals (targets) in force on the as-of date.
 *
 * Goals come from Business_Health_Goal_Set__c, versioned by effective dates and owned by
 * leadership. For each target field the first non-blank value wins, in this order: the
 * Active practice goal set (when the page is scoped to a practice), the Active
 * firm-wide goal set, then the system fallback in Business_Health_Setting__mdt (which
 * also holds the AI Advisor configuration).
 *
 * The as-of date defaults to today, unless the org's latest approved timecard is more
 * than LATEST_ACTIVITY_GRACE_DAYS old - then it defaults to that timecard's end date.
 * That keeps a sandbox (whose data stops at its last refresh) showing meaningful
 * trailing windows instead of empty ones, while production always runs "as of today".
 */
public with sharing class BusinessHealthContext {
    public static final Integer LATEST_ACTIVITY_GRACE_DAYS = 45;
    public static final String SETTINGS_RECORD = 'Default';

    @TestVisible
    private static Business_Health_Setting__mdt settingsOverride;

    /** Goal set fields that describe the version rather than hold a target. */
    public static final Set<String> GOAL_SET_META_FIELDS = new Set<String>{
        'status__c',
        'period_type__c',
        'fiscal_year__c',
        'effective_start__c',
        'effective_end__c',
        'practice__c',
        'notes__c'
    };

    public Date asOfDate;
    public Boolean asOfDefaulted = false;
    public Id practiceId;
    public String practiceName;
    public Business_Health_Setting__mdt settings;
    /** Merged targets in force on the as-of date (practice set > firm set > fallback). */
    public Business_Health_Goal_Set__c goals;
    public Business_Health_Goal_Set__c firmGoalSet;
    public Business_Health_Goal_Set__c practiceGoalSet;
    /** Bind variables for dynamic SOQL; always carries practiceId (null when unscoped). */
    public Map<String, Object> binds = new Map<String, Object>();

    public static BusinessHealthContext build(Date requestedAsOf, String practiceId) {
        BusinessHealthContext ctx = new BusinessHealthContext();
        ctx.settings = loadSettings();
        if (requestedAsOf != null) {
            ctx.asOfDate = requestedAsOf;
        } else {
            ctx.asOfDate = defaultAsOfDate();
            ctx.asOfDefaulted = true;
        }
        if (String.isNotBlank(practiceId)) {
            ctx.practiceId = Id.valueOf(practiceId);
            List<pse__Practice__c> practices = [
                SELECT Name
                FROM pse__Practice__c
                WHERE Id = :ctx.practiceId
                WITH USER_MODE
                LIMIT 1
            ];
            ctx.practiceName = practices.isEmpty() ? null : practices[0].Name;
        }
        ctx.binds.put('practiceId', ctx.practiceId);
        ctx.binds.put('asOf', ctx.asOfDate);
        ctx.resolveGoals();
        return ctx;
    }

    /** Custom target fields on Business_Health_Goal_Set__c (lowercase API names). */
    public static List<String> goalFields() {
        List<String> fields = new List<String>();
        for (String f : Schema.SObjectType.Business_Health_Goal_Set__c.fields.getMap().keySet()) {
            if (f.endsWith('__c') && !GOAL_SET_META_FIELDS.contains(f)) {
                fields.add(f);
            }
        }
        return fields;
    }

    /**
     * @description Finds the Active firm-wide and (if scoped) practice goal sets whose
     * effective dates cover the as-of date - the latest-starting one if several do -
     * and merges them field by field over the system fallback.
     */
    @TestVisible
    private void resolveGoals() {
        List<String> fields = goalFields();
        try {
            String soql =
                'SELECT Id, Name, Practice__c, Effective_Start__c, Effective_End__c, ' + String.join(fields, ', ') +
                ' FROM Business_Health_Goal_Set__c WHERE Status__c = \'Active\' AND Effective_Start__c <= :asOf' +
                ' AND (Effective_End__c = null OR Effective_End__c >= :asOf)' +
                ' AND (Practice__c = null' + (practiceId == null ? '' : ' OR Practice__c = :practiceId') + ')' +
                ' ORDER BY Effective_Start__c DESC';
            for (Business_Health_Goal_Set__c g : (List<Business_Health_Goal_Set__c>) query(soql)) {
                if (g.Practice__c == null && firmGoalSet == null) {
                    firmGoalSet = g;
                } else if (g.Practice__c != null && practiceGoalSet == null) {
                    practiceGoalSet = g;
                }
            }
        } catch (QueryException e) {
            // No access to goal sets: fall back to the system defaults below.
            System.debug(LoggingLevel.WARN, 'Business Health goal sets unavailable: ' + e.getMessage());
        }
        Map<String, Schema.SObjectField> fallbackFields = Schema.SObjectType.Business_Health_Setting__mdt.fields.getMap();
        goals = new Business_Health_Goal_Set__c();
        for (String f : fields) {
            Object v = practiceGoalSet == null ? null : practiceGoalSet.get(f);
            if (v == null && firmGoalSet != null) {
                v = firmGoalSet.get(f);
            }
            if (v == null && fallbackFields.containsKey(f)) {
                v = settings.get(f);
            }
            if (v != null) {
                goals.put(f, v);
            }
        }
    }

    /** Which goal set(s) the page is measured against, for display. */
    public String goalSetLabel() {
        if (firmGoalSet == null && practiceGoalSet == null) {
            return 'System defaults (no Active goal set covers this date)';
        }
        if (practiceGoalSet == null) {
            return firmGoalSet.Name;
        }
        return practiceGoalSet.Name + (firmGoalSet == null ? '' : ' over ' + firmGoalSet.Name);
    }

    public Id goalSetId() {
        return practiceGoalSet != null ? practiceGoalSet.Id : (firmGoalSet == null ? null : firmGoalSet.Id);
    }

    public static Business_Health_Setting__mdt loadSettings() {
        if (settingsOverride != null) {
            return settingsOverride;
        }
        Business_Health_Setting__mdt s = Business_Health_Setting__mdt.getInstance(SETTINGS_RECORD);
        return s != null ? s : new Business_Health_Setting__mdt(DeveloperName = SETTINGS_RECORD);
    }

    public static Date defaultAsOfDate() {
        Date today = Date.today();
        List<AggregateResult> latest = [
            SELECT MAX(pse__End_Date__c) latestEnd
            FROM pse__Timecard_Header__c
            WHERE pse__Status__c = 'Approved' AND pse__End_Date__c <= :today
            WITH USER_MODE
        ];
        Date latestEnd = latest.isEmpty() ? null : (Date) latest[0].get('latestEnd');
        if (latestEnd == null || latestEnd.daysBetween(today) <= LATEST_ACTIVITY_GRACE_DAYS) {
            return today;
        }
        // Stale data (e.g. a sandbox): the last week or two before a refresh is often
        // only partly approved, which would read as a utilization collapse. Use the
        // latest week-ending with at least half the busiest recent week's timecards.
        Date lookback = latestEnd.addDays(-56);
        List<AggregateResult> weeks = [
            SELECT pse__End_Date__c weekEnd, COUNT(Id) cards
            FROM pse__Timecard_Header__c
            WHERE pse__Status__c = 'Approved' AND pse__End_Date__c > :lookback AND pse__End_Date__c <= :latestEnd
            WITH USER_MODE
            GROUP BY pse__End_Date__c
        ];
        Integer busiest = 0;
        for (AggregateResult ar : weeks) {
            busiest = Math.max(busiest, (Integer) ar.get('cards'));
        }
        Date best = null;
        for (AggregateResult ar : weeks) {
            Date weekEnd = (Date) ar.get('weekEnd');
            if ((Integer) ar.get('cards') * 2 >= busiest && (best == null || weekEnd > best)) {
                best = weekEnd;
            }
        }
        return best == null ? latestEnd : best;
    }

    public String scopeLabel() {
        return practiceName == null ? 'All practices' : practiceName + ' practice';
    }

    /**
     * @description ' AND <fieldPath> = :practiceId' when scoped to a practice, else ''.
     * Appended to dynamic SOQL run through query()/aggregate() with `binds`.
     */
    public String practiceClause(String fieldPath) {
        return practiceId == null ? '' : ' AND ' + fieldPath + ' = :practiceId';
    }

    public List<SObject> query(String soql) {
        return Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);
    }

    public List<AggregateResult> aggregate(String soql) {
        return (List<AggregateResult>) Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);
    }

    public Object bind(String name, Object value) {
        binds.put(name, value);
        return value;
    }

    // ---- date windows ---------------------------------------------------------

    /** First day of the as-of month shifted by `offset` months (0 = as-of month). */
    public Date monthStart(Integer offset) {
        return asOfDate.toStartOfMonth().addMonths(offset);
    }

    /** Month keys (YYYY-MM) for the `count` months ending with the as-of month. */
    public List<String> monthKeys(Integer count) {
        List<String> keys = new List<String>();
        for (Integer i = count - 1; i >= 0; i--) {
            keys.add(monthKey(monthStart(-i)));
        }
        return keys;
    }

    public List<String> monthLabels(Integer count) {
        List<String> labels = new List<String>();
        for (Integer i = count - 1; i >= 0; i--) {
            labels.add(monthLabel(monthStart(-i)));
        }
        return labels;
    }

    /**
     * @description First day of the latest COMPLETE month on or before the as-of date:
     * the as-of month itself when as-of is its last day, else the month before. Monthly
     * KPIs and trend charts use complete months only, so a half-finished month never
     * reads as a revenue or utilization drop.
     */
    public Date referenceMonthStart() {
        Date lastDayOfAsOfMonth = asOfDate.toStartOfMonth().addMonths(1).addDays(-1);
        return asOfDate == lastDayOfAsOfMonth ? asOfDate.toStartOfMonth() : asOfDate.toStartOfMonth().addMonths(-1);
    }

    /** First day of the `count`-complete-month window ending at referenceMonthStart(). */
    public Date windowStart(Integer count) {
        return referenceMonthStart().addMonths(-(count - 1));
    }

    /** Last day of the latest complete month. */
    public Date windowEnd() {
        return referenceMonthStart().addMonths(1).addDays(-1);
    }

    public List<String> completeMonthKeys(Integer count) {
        List<String> keys = new List<String>();
        for (Integer i = count - 1; i >= 0; i--) {
            keys.add(monthKey(referenceMonthStart().addMonths(-i)));
        }
        return keys;
    }

    public List<String> completeMonthLabels(Integer count) {
        List<String> labels = new List<String>();
        for (Integer i = count - 1; i >= 0; i--) {
            labels.add(monthLabel(referenceMonthStart().addMonths(-i)));
        }
        return labels;
    }

    public static String monthKey(Date d) {
        return d == null ? null : d.year() + '-' + String.valueOf(d.month()).leftPad(2, '0');
    }

    public static String monthKey(Integer year, Integer month) {
        return year + '-' + String.valueOf(month).leftPad(2, '0');
    }

    public static String monthLabel(Date d) {
        return Datetime.newInstance(d.year(), d.month(), 1).format('MMM yy');
    }

    // ---- goal accessors with defaults -------------------------------------

    public Decimal num(Decimal value, Decimal fallback) {
        return value == null ? fallback : value;
    }

    public Decimal hoursPerWeek() {
        return num(goals.Standard_Hours_Per_Week__c, 40);
    }

    /**
     * @description Billable utilization target (percent) for a resource role, from
     * Role_Utilization_Targets__c ("Role=Target;..."), else the delivery default.
     */
    public Decimal roleTarget(String role) {
        Decimal fallback = num(goals.Delivery_Utilization_Target__c, 75);
        if (String.isBlank(role) || String.isBlank(goals.Role_Utilization_Targets__c)) {
            return fallback;
        }
        for (String pair : goals.Role_Utilization_Targets__c.split(';')) {
            List<String> parts = pair.split('=');
            if (parts.size() == 2 && parts[0].trim().equalsIgnoreCase(role.trim())) {
                try {
                    return Decimal.valueOf(parts[1].trim());
                } catch (TypeException e) {
                    return fallback;
                }
            }
        }
        return fallback;
    }

    public List<String> strategicSkills() {
        List<String> skills = new List<String>();
        String raw = String.isBlank(goals.Strategic_Skills__c)
            ? 'Agentforce;AI Specialist;Data Cloud;Financial Services Cloud'
            : goals.Strategic_Skills__c;
        for (String s : raw.split(';')) {
            if (String.isNotBlank(s)) {
                skills.add(s.trim());
            }
        }
        return skills;
    }
}
