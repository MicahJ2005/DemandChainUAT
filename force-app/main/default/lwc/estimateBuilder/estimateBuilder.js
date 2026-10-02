import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getEstimate from '@salesforce/apex/EstimateController.getEstimate';
import getEstimateVersions from '@salesforce/apex/EstimateController.getEstimateVersions';
import getDefaultRateCard from '@salesforce/apex/EstimateController.getDefaultRateCard';
import saveEstimate from '@salesforce/apex/EstimateController.saveEstimate';
import createNewVersion from '@salesforce/apex/EstimateController.createNewVersion';
import activateVersion from '@salesforce/apex/EstimateController.activateVersion';
import deleteEstimate from '@salesforce/apex/EstimateController.deleteEstimate';
import generatePdf from '@salesforce/apex/EstimateExportController.generatePdf';
import generateWord from '@salesforce/apex/EstimateExportController.generateWord';

import {
    RATE_CLASSES,
    DELIVERABLE_PHASES,
    SLA_TIERS,
    nz,
    recalcLine,
    sumField,
    marginPercent,
    weeklyJsonToPhaseHours,
    tempId
} from 'c/estimateCalculations';

const SLA_MULTIPLIERS = { Standard: 1, Priority: 1.15, Expedited: 1.35 };

const toOptions = (values) => values.map((v) => ({ label: v, value: v }));

function fieldValueFromEvent(event) {
    if (event.detail && event.detail.recordId !== undefined) {
        return event.detail.recordId;
    }
    if (event.detail && event.detail.value !== undefined) {
        return event.detail.value;
    }
    return event.target.type === 'checkbox' ? event.target.checked : event.target.value;
}

const ACTIVE_USER_FILTER = {
    criteria: [{ fieldPath: 'IsActive', operator: 'eq', value: true }]
};

const NEW_HEADER_DEFAULTS = {
    Status__c: 'Draft',
    Version_Number__c: 1,
    Pricing_Mode__c: 'Time and Materials',
    Hours_Entry_Mode__c: 'By Phase',
    Planning_Weeks__c: 1,
    Discovery_Weeks__c: 2,
    PB_Sprints__c: 6,
    Sprint_Length_Weeks__c: 2,
    Deploy_Weeks__c: 1,
    Wrapup_Weeks__c: 1,
    MS_Cadence__c: 'Retainer',
    MS_Contract_Months__c: 12,
    MS_QBR_Cadence__c: 'Quarterly',
    TM_Requests_Per_Month__c: 4
};

export default class EstimateBuilder extends LightningElement {
    @api recordId; // Opportunity Id (record page context)
    @api estimateId; // optional: open a specific version on load

    currentEstimateId;
    versions = [];
    defaultRates = [];
    header = {};
    rates = [];
    lineItems = [];
    deletedRateIds = [];
    deletedLineItemIds = [];
    activeTab = 'project-info';
    isLoading = false;
    isSaving = false;

    wiredVersionsResult;

    connectedCallback() {
        if (this.estimateId) {
            this.loadEstimate(this.estimateId);
        }
    }

    @wire(getEstimateVersions, { opportunityId: '$recordId' })
    wiredVersions(result) {
        this.wiredVersionsResult = result;
        const { data, error } = result;
        if (data) {
            this.versions = data;
            if (!this.currentEstimateId && !this.estimateId) {
                const active = data.find((v) => v.Status__c === 'Active') || data[0];
                if (active) {
                    this.loadEstimate(active.Id);
                } else {
                    this.startNewEstimate();
                }
            }
        } else if (error) {
            this.showError('Unable to load estimate versions', error);
        }
    }

    @wire(getDefaultRateCard)
    wiredDefaultRates({ data, error }) {
        if (data) {
            this.defaultRates = data;
            if (!this.currentEstimateId && !this.rates.length) {
                this.applyDefaultRateCard();
            }
        } else if (error) {
            this.showError('Unable to load default rate card', error);
        }
    }

    // -------------------------------------------------------------- loading
    loadEstimate(id) {
        this.isLoading = true;
        return getEstimate({ estimateId: id })
            .then((result) => {
                this.currentEstimateId = result.Id;
                this.header = { ...result };
                this.rates = (result.Estimate_Rates__r || []).map((r) => ({ ...r, key: r.Id }));
                this.lineItems = (result.Estimate_Line_Items__r || []).map((li) => ({ ...li, key: li.Id }));
                this.deletedRateIds = [];
                this.deletedLineItemIds = [];
                // self-heal: if the Rate Card changed since this version was last saved
                // (e.g. reopening an old Draft), bring derived Cost/Price back in sync.
                this.cascadeRateChangesToLines();
            })
            .catch((error) => this.showError('Unable to load estimate', error))
            .finally(() => {
                this.isLoading = false;
            });
    }

    startNewEstimate() {
        this.currentEstimateId = null;
        this.header = { ...NEW_HEADER_DEFAULTS, Opportunity__c: this.recordId };
        this.lineItems = [];
        this.deletedRateIds = [];
        this.deletedLineItemIds = [];
        this.applyDefaultRateCard();
    }

    applyDefaultRateCard() {
        this.rates = (this.defaultRates || []).map((d) => ({
            key: tempId('rate'),
            Rate_Class__c: d.Label,
            Cost_Per_Hour__c: d.Cost_Per_Hour__c,
            Price_Per_Hour__c: d.Price_Per_Hour__c,
            Managed_Services_Price_Per_Hour__c: d.Managed_Services_Price_Per_Hour__c,
            Is_Locked_Cost__c: d.Is_Locked_Cost__c,
            Sequence__c: d.Sequence__c
        }));
    }

    // ---------------------------------------------------------------- tabs
    get isProjectInfoTab() {
        return this.activeTab === 'project-info';
    }
    get isRateCardTab() {
        return this.activeTab === 'rate-card';
    }
    get isProjectTrackTab() {
        return this.activeTab === 'project-track';
    }
    get isManagedServicesTab() {
        return this.activeTab === 'managed-services';
    }
    get isAdHocTmTab() {
        return this.activeTab === 'adhoc-tm';
    }
    get isSummaryTab() {
        return this.activeTab === 'summary';
    }

    get projectInfoTabClass() {
        return this.tabClass('project-info');
    }
    get rateCardTabClass() {
        return this.tabClass('rate-card');
    }
    get projectTrackTabClass() {
        return this.tabClass('project-track');
    }
    get managedServicesTabClass() {
        return this.tabClass('managed-services');
    }
    get adHocTmTabClass() {
        return this.tabClass('adhoc-tm');
    }
    get summaryTabClass() {
        return this.tabClass('summary');
    }
    tabClass(tab) {
        return this.activeTab === tab ? 'tab active' : 'tab';
    }

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    // --------------------------------------------------------- version bar
    get versionSelectValue() {
        return this.currentEstimateId || '';
    }
    get hasCurrentEstimate() {
        return !!this.currentEstimateId;
    }
    get isDraft() {
        return this.header.Status__c === 'Draft';
    }
    get canActivate() {
        return this.hasCurrentEstimate && this.header.Status__c !== 'Active';
    }
    get statusPillClass() {
        const status = this.header.Status__c;
        if (status === 'Active') return 'pill pill-good';
        if (status === 'Draft') return 'pill pill-warn';
        return 'pill pill-track';
    }

    get versionOptions() {
        return (this.versions || []).map((v) => ({
            label: `v${v.Version_Number__c} - ${v.Status__c} - ${v.Project_Name__c || 'Untitled'}`,
            value: v.Id
        }));
    }

    handleVersionChange(event) {
        const id = fieldValueFromEvent(event);
        if (id) {
            this.loadEstimate(id);
        }
    }

    handleStartNew() {
        this.startNewEstimate();
    }

    // -------------------------------------------------------------- toasts
    showSuccess(message) {
        this.dispatchEvent(new ShowToastEvent({ title: 'Success', message, variant: 'success' }));
    }
    showError(title, error) {
        const message =
            (error && error.body && error.body.message) || (error && error.message) || 'Unknown error occurred.';
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'error' }));
    }

    // -------------------------------------------------------------- actions
    stripKey(record) {
        // eslint-disable-next-line no-unused-vars
        const { key, Estimate_Rates__r, Estimate_Line_Items__r, Opportunity__r, ...rest } = record;
        return rest;
    }

    handleSave() {
        this.isSaving = true;
        const headerToSave = this.stripKey({ ...this.header, Opportunity__c: this.header.Opportunity__c || this.recordId });
        const ratesToSave = this.rates.map((r) => this.stripKey(r));
        const lineItemsToSave = this.lineItems.map((li) => this.stripKey(li));

        saveEstimate({
            estimateHeader: headerToSave,
            rates: ratesToSave,
            lineItems: lineItemsToSave,
            deletedRateIds: this.deletedRateIds,
            deletedLineItemIds: this.deletedLineItemIds
        })
            .then((id) => {
                this.showSuccess('Estimate saved.');
                return this.loadEstimate(id);
            })
            .then(() => refreshApex(this.wiredVersionsResult))
            .catch((error) => this.showError('Unable to save estimate', error))
            .finally(() => {
                this.isSaving = false;
            });
    }

    handleNewVersion() {
        if (!this.currentEstimateId) {
            this.showError('Save first', { message: 'Save this estimate before creating a new version.' });
            return;
        }
        this.isSaving = true;
        createNewVersion({ currentEstimateId: this.currentEstimateId })
            .then((newId) => {
                this.showSuccess('New draft version created.');
                return this.loadEstimate(newId);
            })
            .then(() => refreshApex(this.wiredVersionsResult))
            .catch((error) => this.showError('Unable to create new version', error))
            .finally(() => {
                this.isSaving = false;
            });
    }

    handleActivate() {
        if (!this.currentEstimateId) {
            return;
        }
        this.isSaving = true;
        activateVersion({ estimateId: this.currentEstimateId })
            .then(() => {
                this.showSuccess('Version activated.');
                return this.loadEstimate(this.currentEstimateId);
            })
            .then(() => refreshApex(this.wiredVersionsResult))
            .catch((error) => this.showError('Unable to activate version', error))
            .finally(() => {
                this.isSaving = false;
            });
    }

    handleDelete() {
        if (!this.currentEstimateId) {
            return;
        }
        this.isSaving = true;
        deleteEstimate({ estimateId: this.currentEstimateId })
            .then(() => {
                this.showSuccess('Draft deleted.');
                this.startNewEstimate();
                return refreshApex(this.wiredVersionsResult);
            })
            .catch((error) => this.showError('Unable to delete estimate', error))
            .finally(() => {
                this.isSaving = false;
            });
    }

    handleExportPdf() {
        this.exportFile(generatePdf);
    }
    handleExportWord() {
        this.exportFile(generateWord);
    }
    exportFile(apexMethod) {
        if (!this.currentEstimateId) {
            this.showError('Save first', { message: 'Save this estimate before exporting.' });
            return;
        }
        this.isSaving = true;
        apexMethod({ estimateId: this.currentEstimateId })
            .then((contentVersionId) => {
                window.open(`/sfc/servlet.shepherd/version/download/${contentVersionId}`, '_blank');
            })
            .catch((error) => this.showError('Unable to generate export', error))
            .finally(() => {
                this.isSaving = false;
            });
    }

    // --------------------------------------------------------- header form
    handleHeaderFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        this.header = { ...this.header, [field]: fieldValueFromEvent(event) };
    }

    get activeUserFilter() {
        return ACTIVE_USER_FILTER;
    }

    get discoveryCostPreview() {
        const rate = this.rates.find((r) => r.Rate_Class__c === this.header.Discovery_Rate_Class__c);
        return nz(this.header.Discovery_Hours__c) * nz(rate ? rate.Cost_Per_Hour__c : 0);
    }
    get discoveryMarginPreview() {
        return marginPercent(nz(this.header.Discovery_Fee__c), this.discoveryCostPreview);
    }

    // ----------------------------------------------------------- rate card
    handleRateFieldChange(event) {
        const key = event.currentTarget.dataset.key;
        const field = event.currentTarget.dataset.field;
        const value = fieldValueFromEvent(event);
        this.rates = this.rates.map((r) => (r.key === key ? { ...r, [field]: value } : r));
        this.cascadeRateChangesToLines();
    }

    handleRestoreDefaultRates() {
        this.applyDefaultRateCard();
        this.cascadeRateChangesToLines();
        this.showSuccess('Default rate card restored.');
    }

    /**
     * @description Re-derives Cost/hr and Price/hr on every Team Resource/MS Tier/T&M
     * line from the current Rate Card. Those fields aren't directly editable on those
     * tabs - they always mirror whichever Rate Class the line has selected, and stay in
     * sync whenever the Rate Card itself is edited or restored to defaults.
     */
    cascadeRateChangesToLines() {
        const derivedTypes = ['Team Resource', 'MS Tier', 'T&M Line'];
        this.lineItems = this.lineItems.map((l) => {
            if (!derivedTypes.includes(l.Line_Type__c)) {
                return l;
            }
            return recalcLine(this.applyRateClassDefaults(l));
        });
    }

    // -------------------------------------------------------- line items
    get teamLines() {
        return this.lineItems.filter((l) => l.Line_Type__c === 'Team Resource');
    }
    get fixedLines() {
        return this.lineItems.filter((l) => l.Line_Type__c === 'Fixed Deliverable');
    }
    get msLines() {
        return this.lineItems.filter((l) => l.Line_Type__c === 'MS Tier');
    }
    get tmLines() {
        return this.lineItems.filter((l) => l.Line_Type__c === 'T&M Line');
    }

    get isFixedBid() {
        return this.header.Pricing_Mode__c === 'Fixed Bid';
    }
    get isWeeklyGridMode() {
        return this.header.Hours_Entry_Mode__c === 'Weekly Grid';
    }
    get isPhaseHoursMode() {
        return !this.isWeeklyGridMode;
    }

    addLine(defaults) {
        this.lineItems = [
            ...this.lineItems,
            {
                key: tempId('line'),
                Include_In_Rollup__c: true,
                Sequence__c: this.lineItems.length,
                Cost_Per_Hour__c: 0,
                Price_Per_Hour__c: 0,
                ...defaults
            }
        ];
    }
    handleAddTeamResource() {
        this.addLine({ Line_Type__c: 'Team Resource', Name: 'New Resource' });
    }
    handleAddFixedDeliverable() {
        this.addLine({ Line_Type__c: 'Fixed Deliverable', Name: 'New Functionality' });
    }
    handleAddMsTier() {
        this.addLine({ Line_Type__c: 'MS Tier', Name: 'New Delivery Tier', Delivery_Tier__c: 'New Delivery Tier' });
    }
    handleAddTmLine() {
        this.addLine({ Line_Type__c: 'T&M Line', Name: 'New T&M Line', SLA_Tier__c: 'Standard' });
    }

    handleRemoveLine(event) {
        const key = event.currentTarget.dataset.key;
        const line = this.lineItems.find((l) => l.key === key);
        if (line && line.Id) {
            this.deletedLineItemIds = [...this.deletedLineItemIds, line.Id];
        }
        this.lineItems = this.lineItems.filter((l) => l.key !== key);
    }

    handleLineFieldChange(event) {
        const key = event.currentTarget.dataset.key;
        const field = event.currentTarget.dataset.field;
        const value = fieldValueFromEvent(event);
        this.lineItems = this.lineItems.map((l) => {
            if (l.key !== key) {
                return l;
            }
            let updated = { ...l, [field]: value };
            if (field === 'Rate_Class__c' || field === 'SLA_Tier__c') {
                updated = this.applyRateClassDefaults(updated);
            }
            return recalcLine(updated);
        });
    }

    applyRateClassDefaults(line) {
        const rate = this.rates.find((r) => r.Rate_Class__c === line.Rate_Class__c);
        if (!rate) {
            return line;
        }
        const isMs = line.Line_Type__c === 'MS Tier';
        let price = isMs ? rate.Managed_Services_Price_Per_Hour__c : rate.Price_Per_Hour__c;
        if (line.Line_Type__c === 'T&M Line') {
            price = nz(price) * (SLA_MULTIPLIERS[line.SLA_Tier__c] || 1);
        }
        return { ...line, Cost_Per_Hour__c: rate.Cost_Per_Hour__c, Price_Per_Hour__c: price };
    }

    handleWeeklyHoursChange(event) {
        const { key, weeklyHoursJson } = event.detail;
        this.lineItems = this.lineItems.map((l) => {
            if (l.key !== key) {
                return l;
            }
            return recalcLine({
                ...l,
                Weekly_Hours_JSON__c: weeklyHoursJson,
                ...weeklyJsonToPhaseHours(weeklyHoursJson, this.header)
            });
        });
    }

    // --------------------------------------------------------------- KPIs
    get totalPrice() {
        return sumField(this.lineItems, 'Line_Price__c', true) + nz(this.header.Discovery_Fee__c);
    }
    get totalCost() {
        return sumField(this.lineItems, 'Line_Cost__c', true) + this.discoveryCostForTotals;
    }
    get discoveryCostForTotals() {
        return this.header.Discovery_Cost__c != null ? nz(this.header.Discovery_Cost__c) : this.discoveryCostPreview;
    }
    get totalHours() {
        return sumField(this.lineItems, 'Total_Hours__c', true) + nz(this.header.Discovery_Hours__c);
    }
    get totalMargin() {
        return marginPercent(this.totalPrice, this.totalCost);
    }

    get projectPrice() {
        return sumField([...this.teamLines, ...this.fixedLines], 'Line_Price__c', true);
    }
    get projectCost() {
        return sumField([...this.teamLines, ...this.fixedLines], 'Line_Cost__c', true);
    }
    get projectHours() {
        return sumField([...this.teamLines, ...this.fixedLines], 'Total_Hours__c', true);
    }
    get msPrice() {
        return sumField(this.msLines, 'Line_Price__c', true);
    }
    get msCost() {
        return sumField(this.msLines, 'Line_Cost__c', true);
    }
    get tmPrice() {
        return sumField(this.tmLines, 'Line_Price__c', true);
    }
    get tmCost() {
        return sumField(this.tmLines, 'Line_Cost__c', true);
    }

    // ------------------------------------------------------------ options
    get rateClassOptions() {
        return toOptions(RATE_CLASSES);
    }
    get phaseOptions() {
        return toOptions(DELIVERABLE_PHASES);
    }
    get slaTierOptions() {
        return toOptions(SLA_TIERS);
    }
    get trackOptions() {
        return toOptions(['Project', 'Managed Services', 'Ad-Hoc T&M']);
    }
    get discoveryStatusOptions() {
        return toOptions(['Not Started', 'Fee Collected', 'Sessions Complete', 'Report Delivered']);
    }
    get pricingModeOptions() {
        return toOptions(['Time and Materials', 'Fixed Bid']);
    }
    get hoursEntryModeOptions() {
        return toOptions(['By Phase', 'Weekly Grid']);
    }
    get msCadenceOptions() {
        return toOptions(['Retainer', 'Sprint']);
    }
    get msQbrOptions() {
        return toOptions(['Quarterly', 'Monthly', 'Semi-annual']);
    }
}
