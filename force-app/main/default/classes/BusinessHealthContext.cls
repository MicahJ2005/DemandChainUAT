/**
 * @group BusinessHealth
 *
 * @description Request-scoped context for building a Business Health page: the as-of
 * date every trailing window is measured back from, the optional practice scope, and
 * the goals (targets) in force on the as-of date.
 *
 * Goals come from Business_Health_Goal_Set__c, versioned by effective dates and owned by
 * leadership. For each target field the first non-blank value wins, in this order: the
 * Active personal goal set (My Work pages, scoped to the running user), the Active
 * practice goal set (when the page is scoped to a practice), the Active firm-wide goal
 * set, then the system fallback in Business_Health_Setting__mdt (which also holds the
 * AI Advisor configuration). Goal sets are private records (personal quotas), so they
 * are read in system mode, limited to firm-wide, the page's practice and the running
 * user's own set.
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
        'user__c',
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
    public Business_Health_Goal_Set__c userGoalSet;
    /** The person a My Work page is about (always the running user); null on firm pages. */
    public Id userId;
    public String userName;
    /** Bind variables for dynamic SOQL; always carries practiceId (null when unscoped). */
    public Map<String, Object> binds = new Map<String, Object>();

    public static BusinessHealthContext build(Date requestedAsOf, String practiceId) {
        return build(requestedAsOf, practiceId, null);
    }

    /** A context for one person's My Work page: their goals, no practice scope. */
    public static BusinessHealthContext buildForUser(Date requestedAsOf, Id userId) {
        return build(requestedAsOf, null, userId);
    }

    private static BusinessHealthContext build(Date requestedAsOf, String practiceId, Id userId) {
        BusinessHealthContext ctx = new BusinessHealthContext();
        if (userId != null) {
            ctx.userId = userId;
            List<User> users = [SELECT Name FROM User WHERE Id = :userId WITH USER_MODE LIMIT 1];
            ctx.userName = users.isEmpty() ? null : users[0].Name;
        }
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
        ctx.binds.put('userId', ctx.userId);
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
     * @description Finds the Active firm-wide, practice (if scoped) and personal (if a
     * My Work page) goal sets whose effective dates cover the as-of date - the
     * latest-starting one of each if several do - and merges them field by field over
     * the system fallback.
     */
    @TestVisible
    private void resolveGoals() {
        List<String> fields = goalFields();
        String scopeFilter = '(Practice__c = null AND User__c = null)' +
            (practiceId == null ? '' : ' OR Practice__c = :practiceId') +
            (userId == null ? '' : ' OR User__c = :userId');
        String soql =
            'SELECT Id, Name, Practice__c, User__c, Effective_Start__c, Effective_End__c, ' + String.join(fields, ', ') +
            ' FROM Business_Health_Goal_Set__c WHERE Status__c = \'Active\' AND Effective_Start__c <= :asOf' +
            ' AND (Effective_End__c = null OR Effective_End__c >= :asOf)' +
            ' AND (' + scopeFilter + ')' +
            ' ORDER BY Effective_Start__c DESC';
        for (Business_Health_Goal_Set__c g : new GoalReader().read(soql, binds)) {
            if (g.User__c != null) {
                if (userGoalSet == null) {
                    userGoalSet = g;
                }
            } else if (g.Practice__c != null) {
                if (practiceGoalSet == null) {
                    practiceGoalSet = g;
                }
            } else if (firmGoalSet == null) {
                firmGoalSet = g;
            }
        }
        Map<String, Schema.SObjectField> fallbackFields = Schema.SObjectType.Business_Health_Setting__mdt.fields.getMap();
        goals = new Business_Health_Goal_Set__c();
        for (String f : fields) {
            Object v = null;
            for (Business_Health_Goal_Set__c layer : new List<Business_Health_Goal_Set__c>{ userGoalSet, practiceGoalSet, firmGoalSet }) {
                if (v == null && layer != null) {
                    v = layer.get(f);
                }
            }
            if (v == null && fallbackFields.containsKey(f)) {
                v = settings.get(f);
            }
            if (v != null) {
                goals.put(f, v);
            }
        }
    }

    /**
     * Goal sets are private (they hold personal quotas). The query above only ever
     * returns firm-wide sets, the page's practice set and the running user's own set,
     * so it is safe to read them regardless of the user's own goal set access.
     */
    private without sharing class GoalReader {
        List<Business_Health_Goal_Set__c> read(String soql, Map<String, Object> binds) {
            return (List<Business_Health_Goal_Set__c>) Database.queryWithBinds(soql, binds, AccessLevel.SYSTEM_MODE);
        }
    }

    /** Which goal set(s) the page is measured against, for display, most specific first. */
    public String goalSetLabel() {
        List<String> names = new List<String>();
        for (Business_Health_Goal_Set__c g : new List<Business_Health_Goal_Set__c>{ userGoalSet, practiceGoalSet, firmGoalSet }) {
            if (g != null) {
                names.add(g.Name);
            }
        }
        return names.isEmpty() ? 'System defaults (no Active goal set covers this date)' : String.join(names, ' over ');
    }

    /**
     * The goal set to link to from the page header. Null on My Work pages: personal goal
     * sets are private to leadership, so the person can see their targets but not open
     * the record.
     */
    public Id goalSetId() {
        if (userId != null) {
            return null;
        }
        return practiceGoalSet != null ? practiceGoalSet.Id : (firmGoalSet == null ? null : firmGoalSet.Id);
    }

    /**
     * The personal goal period: the personal goal set's effective dates, else the
     * calendar year of the as-of date.
     */
    public Date goalPeriodStart() {
        return userGoalSet != null ? userGoalSet.Effective_Start__c : Date.newInstance(asOfDate.year(), 1, 1);
    }

    public Date goalPeriodEnd() {
        if (userGoalSet != null && userGoalSet.Effective_End__c != null) {
            return userGoalSet.Effective_End__c;
        }
        return userGoalSet != null ? userGoalSet.Effective_Start__c.addYears(1).addDays(-1) : Date.newInstance(asOfDate.year(), 12, 31);
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
        // Recent approved time means the org is current: as of today. Checking the grace
        // window first keeps this cheap (an unbounded MAX() counts every timecard ever
        // toward the query-row limit on every page load).
        Date graceStart = today.addDays(-LATEST_ACTIVITY_GRACE_DAYS);
        Integer recent = [
            SELECT COUNT()
            FROM pse__Timecard_Header__c
            WHERE pse__Status__c = 'Approved' AND pse__End_Date__c >= :graceStart AND pse__End_Date__c <= :today
            WITH USER_MODE
            LIMIT 1
        ];
        if (recent > 0) {
            return today;
        }
        List<AggregateResult> latest = [
            SELECT MAX(pse__End_Date__c) latestEnd
            FROM pse__Timecard_Header__c
            WHERE pse__Status__c = 'Approved' AND pse__End_Date__c <= :today
            WITH USER_MODE
        ];
        Date latestEnd = latest.isEmpty() ? null : (Date) latest[0].get('latestEnd');
        if (latestEnd == null) {
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
        if (userId != null) {
            return userName == null ? 'You' : userName;
        }
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

    /**
     * @description A resource's billable utilization target (percent): the Utilization
     * Target on their resource Contact, else (blank or 0) the target for their role.
     */
    public Decimal resourceTarget(Contact c) {
        return BusinessHealthData.hasUtilizationTarget(c) ? c.pse__Utilization_Target__c : roleTarget(c.pse__Resource_Role__c);
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
