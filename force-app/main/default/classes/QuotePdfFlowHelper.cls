public with sharing class QuotePdfFlowHelper {

    @InvocableMethod(label='Generate and Save Quote PDF')
    public static void generateAndSave(List<Id> quoteIds) {

        for (Id quoteId : quoteIds) {

            Quote q = [
                SELECT Id, Name
                FROM Quote
                WHERE Id = :quoteId
                LIMIT 1
            ];

            // Render your Visualforce page to PDF
            PageReference pdfPage = Page.SanuWave_Quote_PDF;
            pdfPage.getParameters().put('id', quoteId);
            Blob pdfBlob = pdfPage.getContentAsPDF();

            // Save as Salesforce File
            ContentVersion cv = new ContentVersion();
            cv.Title = q.Name + ' PDF';
            cv.PathOnClient = q.Name + '.pdf';
            cv.VersionData = pdfBlob;
            insert cv;

            // Get ContentDocumentId
            ContentVersion insertedVersion =
                [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

            // Attach to Quote
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = insertedVersion.ContentDocumentId;
            cdl.LinkedEntityId = quoteId;
            cdl.ShareType = 'V';
            insert cdl;
        }
    }
}