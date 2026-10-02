public class SanuwaveQuoteController2 {

    public Quote quote { get; set; }

    public SanuWaveQuoteController2() {
        Id quoteId = ApexPages.currentPage().getParameters().get('id');

        if (quoteId == null) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR, 
                'No Quote ID was provided.'
            ));
            return;
        }

        try {
            quote = [
                SELECT 
                    Id, Name, QuoteNumber, CreatedDate, ExpirationDate,
                    Subtotal, TotalPrice, Discount, Tax, Status, GrandTotal,
                    OwnerId, Owner.Name,
                    RecordTypeId, RecordType.Name,
                    BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                    ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry, ShippingName,

                    Account.Id, Account.Name,
                    Account.BillingStreet, Account.BillingCity, Account.BillingState,
                    Account.BillingPostalCode, Account.BillingCountry,
                    Account.ShippingStreet, Account.ShippingCity, Account.ShippingState,
                    Account.ShippingPostalCode, Account.ShippingCountry,

                    (SELECT 
                        Id,
                        Quantity,
                        ListPrice,
                        Discount,
                        UnitPrice,
                        Description,
                        LineNumber,
                        PricebookEntry.Product2.Name,
                        PricebookEntry.Product2.Description
                    FROM QuoteLineItems 
                    ORDER BY LineNumber ASC)
                FROM Quote 
                WHERE Id = :quoteId
            ];
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Unable to load Quote details. Error: ' + e.getMessage()
            ));
        }
    }

    /* -----------------------------
       Derived Values for the PDF
       ----------------------------- */

    public String getOwnerName() {
        return quote != null && quote.Owner != null ? quote.Owner.Name : '';
    }

    public String getRecordTypeName() {
        return quote != null && quote.RecordType != null ? quote.RecordType.Name.trim() : '';
    }

    /* Shipping fallbacks */

    public String getShippingStreet() {
        return (quote.ShippingStreet != null && quote.ShippingStreet != '') 
            ? quote.ShippingStreet 
            : quote.Account.ShippingStreet;
    }

    public String getShippingCity() {
        return (quote.ShippingCity != null && quote.ShippingCity != '') 
            ? quote.ShippingCity 
            : quote.Account.ShippingCity;
    }

    public String getShippingState() {
        return (quote.ShippingState != null && quote.ShippingState != '') 
            ? quote.ShippingState 
            : quote.Account.ShippingState;
    }

    public String getShippingPostalCode() {
        return (quote.ShippingPostalCode != null && quote.ShippingPostalCode != '') 
            ? quote.ShippingPostalCode 
            : quote.Account.ShippingPostalCode;
    }

    /* Tax Calculation (only if needed) */
    public Decimal getTaxAmount() {
        if (quote == null || quote.TotalPrice == null || quote.Subtotal == null) return 0;
        return quote.TotalPrice - quote.Subtotal;
    }

    /* Recalculate "Your Price" */
    public Decimal getYourPrice(QuoteLineItem li) {
        Decimal listPrice = li.ListPrice == null ? 0 : li.ListPrice;
        Decimal discount = li.Discount == null ? 0 : li.Discount;
        return listPrice - discount;
    }

    /* Recalculate Total Price */
    public Decimal getRecalcTotal(QuoteLineItem li) {
        return getYourPrice(li) * (li.Quantity == null ? 1 : li.Quantity);
    }
}