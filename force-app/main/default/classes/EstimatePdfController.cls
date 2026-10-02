/**
 * @group Estimate
 *
 * @description Standard controller for the EstimatePdf Visualforce page. Reads the
 * `id` URL parameter and exposes the Estimate plus derived phase-timeline segments
 * used by the PDF/Word export.
 */
public with sharing class EstimatePdfController {
    public Estimate__c estimate { get; private set; }
    public List<Estimate_Rate__c> rates { get; private set; }
    public List<Estimate_Line_Item__c> teamLines { get; private set; }
    public List<Estimate_Line_Item__c> fixedLines { get; private set; }
    public List<Estimate_Line_Item__c> msLines { get; private set; }
    public List<Estimate_Line_Item__c> tmLines { get; private set; }
    public List<PhaseSegment> phaseSegments { get; private set; }

    // Total_Price__c/Total_Cost__c/Total_Hours__c are roll-up SUM fields (null, not 0,
    // when there are no child line items) and Total_Margin__c is a formula field - both
    // kinds are compiler-enforced read-only in Apex, so nulls can't be coalesced by
    // mutating estimate directly the way the other displayed fields are. These getters
    // do it without touching the SObject.
    public Decimal totalPrice {
        get {
            return nz(estimate.Total_Price__c);
        }
    }
    public Decimal totalCost {
        get {
            return nz(estimate.Total_Cost__c);
        }
    }
    public Decimal totalHours {
        get {
            return nz(estimate.Total_Hours__c);
        }
    }
    public Decimal totalMargin {
        get {
            return nz(estimate.Total_Margin__c);
        }
    }

    public EstimatePdfController() {
        teamLines = new List<Estimate_Line_Item__c>();
        fixedLines = new List<Estimate_Line_Item__c>();
        msLines = new List<Estimate_Line_Item__c>();
        tmLines = new List<Estimate_Line_Item__c>();
        phaseSegments = new List<PhaseSegment>();

        Id estimateId = ApexPages.currentPage().getParameters().get('id');
        if (estimateId == null) {
            return;
        }

        estimate = [
            SELECT
                Id,
                Name,
                Version_Number__c,
                Status__c,
                Project_Name__c,
                Sales_Owner__r.Name,
                Sales_Engineer__r.Name,
                Scope_Approver__r.Name,
                Financial_Approver__r.Name,
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
                Planning_Weeks__c,
                Discovery_Weeks__c,
                PB_Sprints__c,
                Sprint_Length_Weeks__c,
                Deploy_Weeks__c,
                Wrapup_Weeks__c,
                MS_Lead__c,
                MS_Cadence__c,
                MS_Contract_Months__c,
                MS_QBR_Cadence__c,
                TM_Requests_Per_Month__c,
                Total_Price__c,
                Total_Cost__c,
                Total_Hours__c,
                Total_Margin__c,
                Opportunity__r.Name,
                Opportunity__r.Account.Name,
                (
                    SELECT Id, Rate_Class__c, Cost_Per_Hour__c, Price_Per_Hour__c, Managed_Services_Price_Per_Hour__c
                    FROM Estimate_Rates__r
                    ORDER BY Sequence__c ASC
                ),
                (
                    SELECT
                        Id,
                        Name,
                        Line_Type__c,
                        Rate_Class__c,
                        Cost_Per_Hour__c,
                        Price_Per_Hour__c,
                        Planning_Hours__c,
                        Discovery_Hours__c,
                        PB_Hours__c,
                        Deploy_Hours__c,
                        Wrapup_Hours__c,
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

        zeroOutHeaderNulls();

        rates = estimate.Estimate_Rates__r;
        for (Estimate_Rate__c r : rates) {
            r.Cost_Per_Hour__c = nz(r.Cost_Per_Hour__c);
            r.Price_Per_Hour__c = nz(r.Price_Per_Hour__c);
            r.Managed_Services_Price_Per_Hour__c = nz(r.Managed_Services_Price_Per_Hour__c);
        }

        for (Estimate_Line_Item__c li : estimate.Estimate_Line_Items__r) {
            zeroOutLineNulls(li);
            if (li.Line_Type__c == 'Team Resource') {
                teamLines.add(li);
            } else if (li.Line_Type__c == 'Fixed Deliverable') {
                fixedLines.add(li);
            } else if (li.Line_Type__c == 'MS Tier') {
                msLines.add(li);
            } else if (li.Line_Type__c == 'T&M Line') {
                tmLines.add(li);
            }
        }

        buildPhaseSegments();
    }

    /**
     * @description A null value passed into a Visualforce {0,number,currency} pattern
     * renders as blank rather than "$0.00". Coalesce every displayed numeric field to 0
     * so the PDF/Word export always shows a real number instead of silently going blank.
     */
    private void zeroOutHeaderNulls() {
        estimate.Discovery_Fee__c = nz(estimate.Discovery_Fee__c);
        estimate.Discovery_Hours__c = nz(estimate.Discovery_Hours__c);
        estimate.Discovery_Cost__c = nz(estimate.Discovery_Cost__c);
        estimate.Discovery_Margin__c = nz(estimate.Discovery_Margin__c);
        estimate.TM_Requests_Per_Month__c = nz(estimate.TM_Requests_Per_Month__c);
    }

    private void zeroOutLineNulls(Estimate_Line_Item__c li) {
        li.Cost_Per_Hour__c = nz(li.Cost_Per_Hour__c);
        li.Price_Per_Hour__c = nz(li.Price_Per_Hour__c);
        li.Total_Hours__c = nz(li.Total_Hours__c);
        li.Line_Cost__c = nz(li.Line_Cost__c);
        li.Line_Price__c = nz(li.Line_Price__c);
        li.Margin__c = nz(li.Margin__c);
        li.Fixed_Price__c = nz(li.Fixed_Price__c);
        li.Hours_Per_Week__c = nz(li.Hours_Per_Week__c);
    }

    private void buildPhaseSegments() {
        List<Object[]> phases = new List<Object[]>{
            new Object[] { 'Planning', nz(estimate.Planning_Weeks__c), '#912121' },
            new Object[] { 'Discovery', nz(estimate.Discovery_Weeks__c), '#00B0F0' },
            new Object[] {
                'Plan & Build',
                nz(estimate.PB_Sprints__c) * nz(estimate.Sprint_Length_Weeks__c),
                '#002060'
            },
            new Object[] { 'Deploy', nz(estimate.Deploy_Weeks__c), '#595959' },
            new Object[] { 'Wrap-up', nz(estimate.Wrapup_Weeks__c), '#B0AEAC' }
        };

        Decimal totalWeeks = 0;
        for (Object[] p : phases) {
            totalWeeks += (Decimal) p[1];
        }
        if (totalWeeks == 0) {
            totalWeeks = 1;
        }

        for (Object[] p : phases) {
            Decimal weeks = (Decimal) p[1];
            PhaseSegment seg = new PhaseSegment();
            seg.phaseName = (String) p[0];
            seg.weeks = weeks;
            seg.color = (String) p[2];
            seg.widthPercent = (weeks / totalWeeks * 100).setScale(1);
            phaseSegments.add(seg);
        }
    }

    private Decimal nz(Decimal d) {
        return d == null ? 0 : d;
    }

    public class PhaseSegment {
        public String phaseName { get; set; }
        public Decimal weeks { get; set; }
        public String color { get; set; }
        public Decimal widthPercent { get; set; }
    }
}
