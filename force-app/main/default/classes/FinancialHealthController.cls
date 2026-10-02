/**
 * @group FinancialHealth
 *
 * @description Backs the financialHealthDashboard LWC - a read-only organizational
 * financial health view: current client projects with revenue remaining, Opportunities
 * likely to close soon, and per-resource billable capacity vs. target. All methods are
 * cacheable and consumed via @wire only (never imperatively), so caching carries no
 * staleness risk here - unlike EstimateController.getEstimate(), there's no
 * corresponding write path on this component that could leave a stale cached read
 * behind.
 */
public with sharing class FinancialHealthController {
    /**
     * @description Default stage set shown when the user hasn't picked any - the
     * "currently active" stages, matching the dashboard's original behavior.
     */
    public static final List<String> DEFAULT_STAGES = new List<String>{ 'Planning', 'In Progress', 'Wrapping_Up' };

    /**
     * @description Client projects in the given Stage(s) (excluding internal
     * non-client project buckets like PTO/Bench/Admin Time - those carry no
     * Opportunity link regardless of stage), with remaining budget and hours.
     * @param  stages Stage values to include; defaults to Planning/In Progress/Wrapping Up
     * when null (no filter provided at all). An explicitly EMPTY list is honored as-is -
     * i.e. "no stages selected" correctly returns zero rows, rather than silently
     * falling back to the defaults.
     */
    @AuraEnabled(cacheable=true)
    public static List<pse__Proj__c> getCurrentProjects(List<String> stages) {
        List<String> stageFilter = stages == null ? DEFAULT_STAGES : stages;
        return [
            SELECT
                Id,
                Name,
                pse__Account__r.Name,
                pse__Stage__c,
                pse__Financial_Status__c,
                Remaining_Budget__c,
                Billable_Hours_Remaining__c
            FROM pse__Proj__c
            WHERE pse__Opportunity__c != NULL AND pse__Stage__c IN :stageFilter
            ORDER BY Remaining_Budget__c DESC NULLS LAST
        ];
    }

    /**
     * @description Open Opportunities at or above a probability threshold, closing
     * within a given number of months from today.
     * @param  monthsOut      how many months out to look (e.g. 2 = closing within the next 2 months)
     * @param  minProbability minimum Probability percentage, e.g. 80
     */
    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getNearCloseOpportunities(Integer monthsOut, Decimal minProbability) {
        Date endDate = Date.today().addMonths(monthsOut == null ? 2 : monthsOut);
        Decimal threshold = minProbability == null ? 80 : minProbability;

        return [
            SELECT Id, Name, Account.Name, Amount, Probability, CloseDate, StageName, Owner.Name, Total_Hours__c
            FROM Opportunity
            WHERE IsClosed = false AND Probability >= :threshold AND CloseDate >= TODAY AND CloseDate <= :endDate
            ORDER BY CloseDate ASC
        ];
    }

    /**
     * @description Time period granularities supported by getResourceCapacity -
     * matches pse__Est_Vs_Actuals__c.pse__Time_Period_Type__c's Week/Month values
     * (Quarter is also a valid picklist value on that field but isn't offered here,
     * since the LWC only exposes Week/Month).
     */
    public static final Set<String> RESOURCE_CAPACITY_PERIOD_TYPES = new Set<String>{ 'Week', 'Month' };

    /**
     * @description One row of getResourceCapacity's result - a lightweight DTO rather
     * than an SObject list, since this blends fields from two different objects
     * (Contact and an aggregate query over pse__Est_Vs_Actuals__c).
     */
    public class ResourceCapacityRow {
        @AuraEnabled
        public Id resourceId;
        @AuraEnabled
        public String resourceName;
        @AuraEnabled
        public Decimal targetHours;
        @AuraEnabled
        public Decimal scheduledHours;
        @AuraEnabled
        public Decimal costRate;
    }

    /**
     * @description Per-resource billable capacity for a date range: scheduled hours
     * (summed estimated hours across every project the resource is assigned to in the
     * range) vs. billable target (the resource's Contact.DCS_Billable_Goal__c, prorated
     * to the range - see below). "Resource" is a Contact in this data model, not a
     * User. Available billable hours = targetHours - scheduledHours, computed
     * client-side in the LWC, along with cost/revenue-lost math on top of it, since the
     * average billing rate is an adjustable what-if input, never persisted.
     *
     * DCS_Billable_Goal__c is a WEEKLY goal (its real-world values cluster at 38-40,
     * a full-time/reduced-schedule weekly billable target - confirmed with the user),
     * so it's prorated here as goal x (days in the selected range / 7) rather than
     * used as a flat value, so a Month view or a wide custom range produces a target
     * that's actually comparable to hours summed across that same range.
     *
     * @param  periodType 'Week' or 'Month'; defaults to 'Month' when null or unrecognized.
     * Filters which of pse__Est_Vs_Actuals__c's parallel Week/Month/Quarter rows are
     * summed - those are redundant representations of the same underlying assignment
     * hours at different granularities, so mixing period types would double-count.
     * @param  startDate  inclusive range start (matched against each
     * pse__Est_Vs_Actuals__c row's End Date); defaults to the start of the current
     * month when null.
     * @param  endDate    inclusive range end; defaults to the end of the current month
     * when null.
     */
    @AuraEnabled(cacheable=true)
    public static List<ResourceCapacityRow> getResourceCapacity(String periodType, Date startDate, Date endDate) {
        String periodFilter = RESOURCE_CAPACITY_PERIOD_TYPES.contains(periodType) ? periodType : 'Month';
        Date rangeStart = startDate == null ? Date.today().toStartOfMonth() : startDate;
        Date rangeEnd = endDate == null ? Date.today().toStartOfMonth().addMonths(1).addDays(-1) : endDate;
        Decimal daysInRange = rangeStart.daysBetween(rangeEnd) + 1;
        Decimal weeksInRange = daysInRange / 7;

        Map<Id, Decimal> scheduledHoursByResource = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT pse__Resource__c resourceId, SUM(pse__Estimated_Hours__c) totalHours
            FROM pse__Est_Vs_Actuals__c
            WHERE
                pse__Resource__c != NULL
                AND pse__Resource__r.pse__Is_Resource_Active__c = true
                AND pse__Time_Period_Type__c = :periodFilter
                AND pse__End_Date__c >= :rangeStart
                AND pse__End_Date__c <= :rangeEnd
            GROUP BY pse__Resource__c
        ]) {
            scheduledHoursByResource.put((Id) ar.get('resourceId'), (Decimal) ar.get('totalHours'));
        }

        List<ResourceCapacityRow> rows = new List<ResourceCapacityRow>();
        for (Contact c : [
            SELECT Id, Name, DCS_Billable_Goal__c, pse__Default_Cost_Rate__c
            FROM Contact
            WHERE pse__Is_Resource_Active__c = true
            ORDER BY Name ASC
        ]) {
            ResourceCapacityRow row = new ResourceCapacityRow();
            row.resourceId = c.Id;
            row.resourceName = c.Name;
            row.targetHours = (c.DCS_Billable_Goal__c == null ? 0 : c.DCS_Billable_Goal__c) * weeksInRange;
            row.scheduledHours = scheduledHoursByResource.containsKey(c.Id) ? scheduledHoursByResource.get(c.Id) : 0;
            row.costRate = c.pse__Default_Cost_Rate__c == null ? 0 : c.pse__Default_Cost_Rate__c;
            rows.add(row);
        }
        return rows;
    }
}
