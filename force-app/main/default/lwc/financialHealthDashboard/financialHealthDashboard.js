import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCurrentProjects from '@salesforce/apex/FinancialHealthController.getCurrentProjects';
import getNearCloseOpportunities from '@salesforce/apex/FinancialHealthController.getNearCloseOpportunities';
import getResourceCapacity from '@salesforce/apex/FinancialHealthController.getResourceCapacity';

const FINANCIAL_STATUS_CLASS = {
    Green: 'status-pill status-good',
    Yellow: 'status-pill status-warn',
    Red: 'status-pill status-bad'
};

// pse__Proj__c.pse__Stage__c's full picklist (FinancialForce PSA) - fixed set, so
// hardcoded here rather than fetched via a picklist describe, matching how the
// Estimate Builder handles its own known-fixed option lists.
const ALL_STAGES = ['Forecasted', 'Planning', 'In Progress', 'On Hold', 'Wrapping_Up', 'Closed', 'Canceled'];
const DEFAULT_STAGES = ['Planning', 'In Progress', 'Wrapping_Up'];

// Matches the mid-tier rate already used as the Estimate Builder's default rate card -
// a starting point for the "what-if" billing rate, not a stored/authoritative value.
const DEFAULT_BILLING_RATE = 150;

// Formats as YYYY-MM-DD using LOCAL date parts (not toISOString, which converts to UTC
// and can shift the date by a day depending on the viewer's timezone offset) - matches
// the format <input type="date"> both emits and expects.
function toIsoDate(d) {
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
}

function currentMonthRange() {
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth(), 1);
    const end = new Date(now.getFullYear(), now.getMonth() + 1, 0);
    return { start: toIsoDate(start), end: toIsoDate(end) };
}

// PSA's own weekly periods don't need to be matched exactly here - the server-side
// filter is an inclusive date range against each period's end date, so a rolling
// 7-day window from today reliably captures "this week" regardless of which day PSA's
// week boundary falls on.
function currentWeekRange() {
    const now = new Date();
    const end = new Date(now);
    end.setDate(end.getDate() + 6);
    return { start: toIsoDate(now), end: toIsoDate(end) };
}

/**
 * Organization-wide financial health snapshot: current client projects with
 * remaining budget, Opportunities likely to close soon, and per-resource billable
 * capacity vs. target. Loads automatically via @wire (no user action needed) and lets
 * the "months out" / "min probability" window and the average billing rate be
 * adjusted, recalculating live.
 */
export default class FinancialHealthDashboard extends NavigationMixin(LightningElement) {
    activeTab = 'overview';
    monthsOut = 2;
    minProbability = 80;
    selectedStages = [...DEFAULT_STAGES];
    averageBillingRate = DEFAULT_BILLING_RATE;
    resourceCapacityPeriodType = 'Month';
    rangeStart = currentMonthRange().start;
    rangeEnd = currentMonthRange().end;

    projects = [];
    opportunities = [];
    resources = [];
    projectsLoading = true;
    opportunitiesLoading = true;
    resourcesLoading = true;
    projectsError;
    opportunitiesError;
    resourcesError;

    @wire(getCurrentProjects, { stages: '$selectedStages' })
    wiredProjects({ data, error }) {
        this.projectsLoading = false;
        if (data) {
            this.projects = data.map((p) => ({
                key: p.Id,
                id: p.Id,
                name: p.Name,
                accountName: p.pse__Account__r ? p.pse__Account__r.Name : '',
                stage: p.pse__Stage__c,
                financialStatus: p.pse__Financial_Status__c,
                statusClass: FINANCIAL_STATUS_CLASS[p.pse__Financial_Status__c] || 'status-pill status-neutral',
                remainingBudget: p.Remaining_Budget__c,
                hoursRemaining: p.Billable_Hours_Remaining__c
            }));
            this.projectsError = undefined;
        } else if (error) {
            this.projectsError = error;
            this.projects = [];
            this.showError('Unable to load current projects', error);
        }
    }

    @wire(getNearCloseOpportunities, { monthsOut: '$monthsOut', minProbability: '$minProbability' })
    wiredOpportunities({ data, error }) {
        this.opportunitiesLoading = false;
        if (data) {
            this.opportunities = data.map((o) => ({
                key: o.Id,
                id: o.Id,
                name: o.Name,
                accountName: o.Account ? o.Account.Name : '',
                amount: o.Amount,
                probability: o.Probability,
                closeDate: o.CloseDate,
                stageName: o.StageName,
                ownerName: o.Owner ? o.Owner.Name : '',
                estimatedHours: o.Total_Hours__c
            }));
            this.opportunitiesError = undefined;
        } else if (error) {
            this.opportunitiesError = error;
            this.opportunities = [];
            this.showError('Unable to load near-close opportunities', error);
        }
    }

    @wire(getResourceCapacity, {
        periodType: '$resourceCapacityPeriodType',
        startDate: '$rangeStart',
        endDate: '$rangeEnd'
    })
    wiredResources({ data, error }) {
        this.resourcesLoading = false;
        if (data) {
            // Apex already aggregates per resource (summing Est_Vs_Actuals hours
            // across every project/period in range, and prorating the billable goal
            // to the range) - one row per resource here, no further grouping needed.
            this.resources = data.map((r) => {
                const scheduled = r.scheduledHours || 0;
                const target = r.targetHours || 0;
                const costRate = r.costRate || 0;
                const availableHours = target - scheduled;
                return {
                    key: r.resourceId,
                    id: r.resourceId,
                    name: r.resourceName,
                    scheduledHours: scheduled,
                    targetHours: target,
                    availableHours,
                    costRate,
                    costOfAvailable: availableHours * costRate
                };
            });
            this.resourcesError = undefined;
        } else if (error) {
            this.resourcesError = error;
            this.resources = [];
            this.showError('Unable to load resource capacity', error);
        }
    }

    // Revenue lost depends on the adjustable averageBillingRate, so it's derived here
    // (recalculates instantly on input change) rather than baked into `resources` at
    // wire time.
    get resourceRows() {
        return this.resources.map((r) => ({
            ...r,
            revenueLost: r.availableHours * this.averageBillingRate
        }));
    }

    get isLoading() {
        return this.projectsLoading || this.opportunitiesLoading || this.resourcesLoading;
    }

    get isOverviewTab() {
        return this.activeTab === 'overview';
    }

    get isResourceCapacityTab() {
        return this.activeTab === 'resourceCapacity';
    }

    get overviewTabClass() {
        return this.isOverviewTab ? 'tab-btn tab-btn-active' : 'tab-btn';
    }

    get resourceCapacityTabClass() {
        return this.isResourceCapacityTab ? 'tab-btn tab-btn-active' : 'tab-btn';
    }

    handleOverviewTabClick() {
        this.activeTab = 'overview';
    }

    handleResourceCapacityTabClick() {
        this.activeTab = 'resourceCapacity';
    }

    get hasProjects() {
        return this.projects.length > 0;
    }

    get hasOpportunities() {
        return this.opportunities.length > 0;
    }

    get projectCount() {
        return this.projects.length;
    }

    get opportunityCount() {
        return this.opportunities.length;
    }

    get totalRemainingBudget() {
        return this.projects.reduce((sum, p) => sum + (p.remainingBudget || 0), 0);
    }

    get totalNearCloseAmount() {
        return this.opportunities.reduce((sum, o) => sum + (o.amount || 0), 0);
    }

    get totalProjectHours() {
        return this.projects.reduce((sum, p) => sum + (p.hoursRemaining || 0), 0);
    }

    get totalOpportunityHours() {
        return this.opportunities.reduce((sum, o) => sum + (o.estimatedHours || 0), 0);
    }

    get combinedTotal() {
        return this.totalRemainingBudget + this.totalNearCloseAmount;
    }

    get combinedHoursTotal() {
        return this.totalProjectHours + this.totalOpportunityHours;
    }

    get combinedTotalExplanation() {
        return 'Total Remaining Budget + Near-Close Amount: revenue still to be delivered on current projects, plus the value of Opportunities likely to close soon. Not the same as booked/recognized revenue - it blends in-flight delivery with not-yet-won pipeline.';
    }

    get combinedHoursExplanation() {
        return 'Total Hours Remaining (Projects) + Total Estimated Hours (Opportunities): work still to be delivered on current projects, plus the estimated effort behind Opportunities likely to close soon.';
    }

    get opportunitiesWindowLabel() {
        const n = Number(this.monthsOut) || 0;
        return n === 1 ? 'next month' : `next ${n} months`;
    }

    get selectedStagesLabel() {
        return this.selectedStages.length
            ? this.selectedStages.map((s) => s.replace(/_/g, ' ')).join(', ')
            : 'no stages selected';
    }

    get remainingBudgetExplanation() {
        const noun = this.projectCount === 1 ? 'project' : 'projects';
        return `Sum of Remaining Budget across ${this.projectCount} current client ${noun} (${this.selectedStagesLabel}).`;
    }

    get projectHoursExplanation() {
        const noun = this.projectCount === 1 ? 'project' : 'projects';
        return `Sum of Hours Remaining across ${this.projectCount} current client ${noun} (${this.selectedStagesLabel}).`;
    }

    get nearCloseExplanation() {
        const noun = this.opportunityCount === 1 ? 'opportunity' : 'opportunities';
        return `Sum of Amount across ${this.opportunityCount} open ${noun} at ${this.minProbability}%+ probability, closing in the ${this.opportunitiesWindowLabel}.`;
    }

    get opportunityHoursExplanation() {
        const noun = this.opportunityCount === 1 ? 'opportunity' : 'opportunities';
        return `Sum of Total Hours across ${this.opportunityCount} open ${noun} at ${this.minProbability}%+ probability, closing in the ${this.opportunitiesWindowLabel}.`;
    }

    get stageOptions() {
        return ALL_STAGES.map((stage) => ({
            value: stage,
            label: stage.replace(/_/g, ' '),
            checked: this.selectedStages.includes(stage)
        }));
    }

    get hasResources() {
        return this.resources.length > 0;
    }

    get resourceCount() {
        return this.resources.length;
    }

    get totalAvailableHours() {
        // True signed sum - an over-allocated resource's negative availability nets
        // against the total, per the user's decision.
        return this.resources.reduce((sum, r) => sum + r.availableHours, 0);
    }

    get totalCostOfAvailable() {
        return this.resources.reduce((sum, r) => sum + r.costOfAvailable, 0);
    }

    get totalRevenueLost() {
        return this.totalAvailableHours * this.averageBillingRate;
    }

    get periodTypeOptions() {
        return [
            { value: 'Month', label: 'Month', selected: this.resourceCapacityPeriodType === 'Month' },
            { value: 'Week', label: 'Week', selected: this.resourceCapacityPeriodType === 'Week' }
        ];
    }

    get resourceCapacityWindowLabel() {
        return `${this.rangeStart} to ${this.rangeEnd} (${this.resourceCapacityPeriodType})`;
    }

    get resourceCapacityExplanation() {
        const noun = this.resourceCount === 1 ? 'active resource' : 'active resources';
        return `Sum of (Billable Target - Scheduled Billable Hours) across ${this.resourceCount} ${noun}, ${this.resourceCapacityWindowLabel}. Positive means idle billable capacity; negative means the resource is over-allocated against target.`;
    }

    get costOfAvailableExplanation() {
        return `Total Available Billable Hours x each resource’s loaded hourly cost rate, ${this.resourceCapacityWindowLabel}: what the company is paying for idle billable capacity.`;
    }

    get revenueLostExplanation() {
        return `Total Available Billable Hours x the average billing rate below ($${this.averageBillingRate}/hr), ${this.resourceCapacityWindowLabel}: the revenue opportunity being missed on unsold capacity.`;
    }

    handleAverageBillingRateChange(event) {
        const value = Number(event.target.value);
        this.averageBillingRate = value >= 0 ? value : DEFAULT_BILLING_RATE;
    }

    handlePeriodTypeChange(event) {
        this.resourceCapacityPeriodType = event.target.value;
        const range = this.resourceCapacityPeriodType === 'Week' ? currentWeekRange() : currentMonthRange();
        this.rangeStart = range.start;
        this.rangeEnd = range.end;
        this.resourcesLoading = true;
    }

    handleRangeStartChange(event) {
        this.rangeStart = event.target.value;
        this.resourcesLoading = true;
    }

    handleRangeEndChange(event) {
        this.rangeEnd = event.target.value;
        this.resourcesLoading = true;
    }

    handleOpenResource(event) {
        this.navigateToRecord(event.currentTarget.dataset.id, 'Contact');
    }

    handleStageToggle(event) {
        const stage = event.target.dataset.value;
        const checked = event.target.checked;
        this.selectedStages = checked
            ? [...this.selectedStages, stage]
            : this.selectedStages.filter((s) => s !== stage);
        this.projectsLoading = true;
    }

    handleMonthsOutChange(event) {
        const value = Number(event.target.value);
        this.monthsOut = value > 0 ? value : 1;
        this.opportunitiesLoading = true;
    }

    handleMinProbabilityChange(event) {
        const value = Number(event.target.value);
        this.minProbability = value >= 0 && value <= 100 ? value : 80;
        this.opportunitiesLoading = true;
    }

    handleOpenProject(event) {
        this.navigateToRecord(event.currentTarget.dataset.id, 'pse__Proj__c');
    }

    handleOpenOpportunity(event) {
        this.navigateToRecord(event.currentTarget.dataset.id, 'Opportunity');
    }

    navigateToRecord(recordId, objectApiName) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName,
                actionName: 'view'
            }
        });
    }

    showError(title, error) {
        const message =
            (error && error.body && error.body.message) || (error && error.message) || 'Unknown error occurred.';
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'error' }));
    }
}
