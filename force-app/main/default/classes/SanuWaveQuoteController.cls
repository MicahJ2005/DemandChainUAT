public class SanuWaveQuoteController {

    public Quote quote { get; private set; }

    public SanuWaveQuoteController() {

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
                     	TotalPrice,
                        Description,
                        LineNumber,
                        PricebookEntry.Product2.Name,
                        PricebookEntry.Product2.Description
                    FROM QuoteLineItems
                    ORDER BY LineNumber ASC)
                FROM Quote
                WHERE Id = :quoteId
            ];
        }
        catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Unable to load Quote details. Error: ' + e.getMessage()
            ));
        }
    }


    /* Record Type Helper */
    public String getRecordTypeName() {
        if (quote == null || quote.RecordType == null) return '';
        return quote.RecordType.Name != null ? quote.RecordType.Name.trim() : '';
    }

    /* Shipping getters with fallback */
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

    /* Tax amount */
    public Decimal getTaxAmount() {
        if (quote == null || quote.TotalPrice == null || quote.Subtotal == null) return 0;
        return quote.TotalPrice - quote.Subtotal;
    }

    /* Pricing logic */

    // Your Price = ListPrice – Discount
    public Decimal getYourPrice(QuoteLineItem li) {
        Decimal listPrice = (li.ListPrice == null) ? 0 : li.ListPrice;
        Decimal discount = (li.Discount == null) ? 0 : li.Discount;
        return listPrice - discount;
    }

    // Total Price = Your Price × Quantity
    public Decimal getRecalcTotal(QuoteLineItem li) {
        Decimal qty = (li.Quantity == null) ? 1 : li.Quantity;
        return getYourPrice(li) * qty;
    }
}