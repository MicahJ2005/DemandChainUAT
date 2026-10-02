/**
 * @group Estimate
 *
 * @description Backs the estimateBuilder LWC. Reads and writes Estimate__c records
 * and their Estimate_Rate__c / Estimate_Line_Item__c children, and manages
 * estimate versioning (new version / activate).
 */
public with sharing class EstimateController {
    /**
     * @description Load one estimate with its rate card and line items in a single round trip.
     * Deliberately NOT cacheable: it's only ever called imperatively (never via @wire), and
     * saveEstimate()'s plain DML is invisible to Lightning Data Service's cache invalidation,
     * so marking this cacheable risked returning a stale pre-save snapshot right after saving.
     * @param  estimateId Id of the Estimate__c to load
     * @return            the Estimate__c with Estimate_Rates__r / Estimate_Line_Items__r populated
     */
    @AuraEnabled
    public static Estimate__c getEstimate(Id estimateId) {
        try {
            return [
                SELECT
                    Id,
                    Name,
                    Opportunity__c,
                    Version_Number__c,
                    Status__c,
                    Project_Name__c,
                    Sales_Owner__c,
                    Sales_Owner__r.Name,
                    Sales_Engineer__c,
                    Sales_Engineer__r.Name,
                    Scope_Approver__c,
                    Scope_Approver__r.Name,
                    Financial_Approver__c,
                    Financial_Approver__r.Name,
                    Legal_Approver__c,
                    Legal_Approver__r.Name,
                    Anticipated_Start_Date__c,
                    Recommended_Track__c,
                    Discovery_Fee__c,
                    Discovery_Sessions__c,
                    Discovery_Status__c,
                    Discovery_Hours__c,
                    Discovery_Rate_Class__c,
                    Discovery_Cost__c,
                    Discovery_Margin__c,
                    Pricing_Mode__c,
                    Hours_Entry_Mode__c,
                    Planning_Weeks__c,
                    Discovery_Weeks__c,
                    PB_Sprints__c,
                    Sprint_Length_Weeks__c,
                    Deploy_Weeks__c,
                    Wrapup_Weeks__c,
                    Range_Cost_Low__c,
                    Range_Cost_High__c,
                    Range_Hours_Low__c,
                    Range_Hours_High__c,
                    MS_Lead__c,
                    MS_Cadence__c,
                    MS_Contract_Months__c,
                    MS_QBR_Cadence__c,
                    TM_Requests_Per_Month__c,
                    TM_Approval__c,
                    Total_Price__c,
                    Total_Cost__c,
                    Total_Hours__c,
                    Total_Margin__c,
                    Opportunity__r.Name,
                    Opportunity__r.Account.Name,
                    (
                        SELECT
                            Id,
                            Name,
                            Rate_Class__c,
                            Cost_Per_Hour__c,
                            Price_Per_Hour__c,
                            Managed_Services_Price_Per_Hour__c,
                            Is_Locked_Cost__c,
                            Sequence__c
                        FROM Estimate_Rates__r
                        ORDER BY Sequence__c ASC
                    ),
                    (
                        SELECT
                            Id,
                            Name,
                            Line_Type__c,
                            Sequence__c,
                            Include_In_Rollup__c,
                            Rate_Class__c,
                            Cost_Per_Hour__c,
                            Price_Per_Hour__c,
                            Planning_Hours__c,
                            Discovery_Hours__c,
                            PB_Hours__c,
                            Deploy_Hours__c,
                            Wrapup_Hours__c,
                            Weekly_Hours_JSON__c,
                            Deliverable__c,
                            Phase__c,
                            Fixed_Price__c,
                            Delivery_Tier__c,
                            Hours_Per_Week__c,
                            SLA_Tier__c,
                            Total_Hours__c,
                            Line_Cost__c,
                            Line_Price__c,
                            Margin__c
                        FROM Estimate_Line_Items__r
                        ORDER BY Sequence__c ASC
                    )
                FROM Estimate__c
                WHERE Id = :estimateId
            ];
        } catch (Exception e) {
            Logger.error('Failed to load estimate ' + estimateId, e);
            Logger.saveLog();
            throw friendlyException('Unable to load estimate: ' + e.getMessage());
        }
    }

    /**
     * @description Lightweight version list for an Opportunity, used by the version picker.
     * @param  opportunityId Id of the parent Opportunity
     * @return               Estimate__c records for that Opportunity, newest version first
     */
    @AuraEnabled(cacheable=true)
    public static List<Estimate__c> getEstimateVersions(Id opportunityId) {
        return [
            SELECT Id, Name, Version_Number__c, Status__c, Project_Name__c, Total_Price__c, Total_Margin__c,
                CreatedDate, LastModifiedDate
            FROM Estimate__c
            WHERE Opportunity__c = :opportunityId
            ORDER BY Version_Number__c DESC
        ];
    }

    /**
     * @description Org-wide default rate card, used to pre-populate a new estimate
     * and to power "Restore default rate card".
     */
    @AuraEnabled(cacheable=true)
    public static List<Default_Rate_Card__mdt> getDefaultRateCard() {
        return [
            SELECT
                Label,
                DeveloperName,
                Cost_Per_Hour__c,
                Price_Per_Hour__c,
                Managed_Services_Price_Per_Hour__c,
                Is_Locked_Cost__c,
                Sequence__c
            FROM Default_Rate_Card__mdt
            ORDER BY Sequence__c ASC
        ];
    }

    /**
     * @description Upsert an estimate header and its rate/line item children in one transaction.
     * Calculated fields are recomputed server-side rather than trusting client math.
     * @param  estimateHeader     the Estimate__c to upsert (Opportunity__c must already be set)
     * @param  rates              rate card rows to upsert
     * @param  lineItems          line items to upsert
     * @param  deletedRateIds     rate row Ids removed on the client since last save
     * @param  deletedLineItemIds line item Ids removed on the client since last save
     * @return                    the Id of the saved Estimate__c
     */
    @AuraEnabled
    public static Id saveEstimate(
        Estimate__c estimateHeader,
        List<Estimate_Rate__c> rates,
        List<Estimate_Line_Item__c> lineItems,
        List<Id> deletedRateIds,
        List<Id> deletedLineItemIds
    ) {
        try {
            if (rates == null) {
                rates = new List<Estimate_Rate__c>();
            }
            if (lineItems == null) {
                lineItems = new List<Estimate_Line_Item__c>();
            }

            recalculateLineItems(lineItems);
            recalculateDiscovery(estimateHeader, rates);

            upsert estimateHeader;

            // Master-detail fields are only settable at insert - reassigning them on an
            // existing (already-parented) row throws "Field is not writeable", so only
            // set it for rows that are new.
            for (Estimate_Rate__c r : rates) {
                if (r.Id == null) {
                    r.Estimate__c = estimateHeader.Id;
                }
            }
            for (Estimate_Line_Item__c li : lineItems) {
                if (li.Id == null) {
                    li.Estimate__c = estimateHeader.Id;
                }
            }

            if (deletedRateIds != null && !deletedRateIds.isEmpty()) {
                delete [SELECT Id FROM Estimate_Rate__c WHERE Id IN :deletedRateIds];
            }
            if (deletedLineItemIds != null && !deletedLineItemIds.isEmpty()) {
                delete [SELECT Id FROM Estimate_Line_Item__c WHERE Id IN :deletedLineItemIds];
            }
            if (!rates.isEmpty()) {
                upsert rates;
            }
            if (!lineItems.isEmpty()) {
                upsert lineItems;
            }

            return estimateHeader.Id;
        } catch (Exception e) {
            Logger.error('Failed to save estimate', e).setRecord(estimateHeader);
            Logger.saveLog();
            throw friendlyException('Unable to save estimate: ' + e.getMessage());
        }
    }

    /**
     * @description Clone an estimate (header + rates + line items) into a new Draft version,
     * numbered one higher than the source.
     * @param  currentEstimateId estimate to clone from
     * @return                   the Id of the newly created Estimate__c
     */
    @AuraEnabled
    public static Id createNewVersion(Id currentEstimateId) {
        try {
            Estimate__c source = getEstimate(currentEstimateId);

            Estimate__c clonedHeader = source.clone(false, false, false, false);
            clonedHeader.Version_Number__c = nz(source.Version_Number__c) + 1;
            clonedHeader.Status__c = 'Draft';
            insert clonedHeader;

            List<Estimate_Rate__c> newRates = new List<Estimate_Rate__c>();
            for (Estimate_Rate__c r : source.Estimate_Rates__r) {
                Estimate_Rate__c c = r.clone(false, false, false, false);
                c.Estimate__c = clonedHeader.Id;
                newRates.add(c);
            }
            if (!newRates.isEmpty()) {
                insert newRates;
            }

            List<Estimate_Line_Item__c> newLines = new List<Estimate_Line_Item__c>();
            for (Estimate_Line_Item__c li : source.Estimate_Line_Items__r) {
                Estimate_Line_Item__c c = li.clone(false, false, false, false);
                c.Estimate__c = clonedHeader.Id;
                newLines.add(c);
            }
            if (!newLines.isEmpty()) {
                insert newLines;
            }

            return clonedHeader.Id;
        } catch (Exception e) {
            Logger.error('Failed to create new estimate version from ' + currentEstimateId, e);
            Logger.saveLog();
            throw friendlyException('Unable to create new version: ' + e.getMessage());
        }
    }

    /**
     * @description Activate an estimate version. Any other Active version under the
     * same Opportunity becomes Superseded. Activating - not saving a Draft - is what
     * pushes this estimate's totals onto the parent Opportunity, so an in-progress edit
     * never overwrites the Opportunity with half-finished numbers.
     * @param  estimateId estimate to activate
     */
    @AuraEnabled
    public static void activateVersion(Id estimateId) {
        try {
            Estimate__c target = [
                SELECT
                    Id,
                    Opportunity__c,
                    Discovery_Fee__c,
                    Discovery_Cost__c,
                    Discovery_Hours__c,
                    (SELECT Id, Include_In_Rollup__c, Line_Price__c, Line_Cost__c, Total_Hours__c FROM Estimate_Line_Items__r)
                FROM Estimate__c
                WHERE Id = :estimateId
            ];

            List<Estimate__c> activeSiblings = [
                SELECT Id, Status__c
                FROM Estimate__c
                WHERE Opportunity__c = :target.Opportunity__c AND Status__c = 'Active' AND Id != :estimateId
            ];
            for (Estimate__c sibling : activeSiblings) {
                sibling.Status__c = 'Superseded';
            }
            if (!activeSiblings.isEmpty()) {
                update activeSiblings;
            }

            target.Status__c = 'Active';
            update target;

            syncOpportunityRollup(target, target.Estimate_Line_Items__r);
        } catch (Exception e) {
            Logger.error('Failed to activate estimate ' + estimateId, e);
            Logger.saveLog();
            throw friendlyException('Unable to activate version: ' + e.getMessage());
        }
    }

    /**
     * @description Delete a Draft estimate (and its children, via cascade). Active/Superseded/
     * Archived versions cannot be deleted through this method.
     * @param  estimateId Draft estimate to delete
     */
    @AuraEnabled
    public static void deleteEstimate(Id estimateId) {
        try {
            delete [SELECT Id FROM Estimate__c WHERE Id = :estimateId AND Status__c = 'Draft'];
        } catch (Exception e) {
            Logger.error('Failed to delete estimate ' + estimateId, e);
            Logger.saveLog();
            throw friendlyException('Unable to delete estimate: ' + e.getMessage());
        }
    }

    /**
     * @description AuraHandledException.getMessage() returns the generic "Script-thrown
     * exception" unless setMessage() is called explicitly - this builds one that actually
     * carries the message through to the client.
     */
    private static AuraHandledException friendlyException(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }

    private static void recalculateLineItems(List<Estimate_Line_Item__c> lineItems) {
        for (Estimate_Line_Item__c li : lineItems) {
            Decimal hours;
            if (li.Line_Type__c == 'Team Resource') {
                hours =
                    nz(li.Planning_Hours__c) +
                    nz(li.Discovery_Hours__c) +
                    nz(li.PB_Hours__c) +
                    nz(li.Deploy_Hours__c) +
                    nz(li.Wrapup_Hours__c);
            } else if (li.Line_Type__c == 'MS Tier') {
                hours = nz(li.Hours_Per_Week__c);
            } else {
                hours = nz(li.Total_Hours__c);
            }
            li.Total_Hours__c = hours;

            Decimal cost = hours * nz(li.Cost_Per_Hour__c);
            Decimal price = (li.Line_Type__c == 'Fixed Deliverable' && li.Fixed_Price__c != null)
                ? li.Fixed_Price__c
                : hours * nz(li.Price_Per_Hour__c);

            li.Line_Cost__c = cost;
            li.Line_Price__c = price;
            li.Margin__c = price == 0 ? 0 : ((price - cost) / price) * 100;
        }
    }

    private static void recalculateDiscovery(Estimate__c header, List<Estimate_Rate__c> rates) {
        if (header.Discovery_Hours__c == null || header.Discovery_Rate_Class__c == null) {
            return;
        }
        Decimal discoveryCostPerHour = 0;
        for (Estimate_Rate__c r : rates) {
            if (r.Rate_Class__c == header.Discovery_Rate_Class__c) {
                discoveryCostPerHour = nz(r.Cost_Per_Hour__c);
                break;
            }
        }
        Decimal discoveryCost = nz(header.Discovery_Hours__c) * discoveryCostPerHour;
        header.Discovery_Cost__c = discoveryCost;
        Decimal fee = nz(header.Discovery_Fee__c);
        header.Discovery_Margin__c = fee == 0 ? 0 : ((fee - discoveryCost) / fee) * 100;
    }

    /**
     * @description Push this estimate's headline totals onto the parent Opportunity. Called
     * only from activateVersion() - not saveEstimate() - so Amount/Margin/Total Hours only
     * change when a version is actually activated, never while a Draft is still being edited.
     * Mirrors exactly what the LWC's Summary tab shows: line items with Include_In_Rollup__c
     * unchecked are excluded, and paid discovery's fee/cost/hours are always included.
     */
    private static void syncOpportunityRollup(Estimate__c header, List<Estimate_Line_Item__c> lineItems) {
        if (header.Opportunity__c == null) {
            return;
        }

        Decimal totalPrice = nz(header.Discovery_Fee__c);
        Decimal totalCost = nz(header.Discovery_Cost__c);
        Decimal totalHours = nz(header.Discovery_Hours__c);

        for (Estimate_Line_Item__c li : lineItems) {
            if (li.Include_In_Rollup__c == false) {
                continue;
            }
            totalPrice += nz(li.Line_Price__c);
            totalCost += nz(li.Line_Cost__c);
            totalHours += nz(li.Total_Hours__c);
        }

        Decimal totalMargin = totalPrice == 0 ? 0 : ((totalPrice - totalCost) / totalPrice) * 100;

        update new Opportunity(
            Id = header.Opportunity__c,
            Amount = totalPrice,
            Margin__c = totalMargin.setScale(2, System.RoundingMode.HALF_UP),
            Total_Hours__c = totalHours
        );
    }

    private static Decimal nz(Decimal d) {
        return d == null ? 0 : d;
    }
}
