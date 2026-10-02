public with sharing class QuotePdfSaver {

    @AuraEnabled
    public static String generateAndSave(Id quoteId) {

        PageReference pdfPage = Page.SanuWave_Quote_PDF;
        pdfPage.getParameters().put('id', quoteId);
        Blob pdfBlob = pdfPage.getContentAsPDF();

        String fileName = 'Quote_' + quoteId + '.pdf';

        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = fileName;
        cv.VersionData = pdfBlob;
        insert cv;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.LinkedEntityId = quoteId;
        cdl.ContentDocumentId = cv.ContentDocumentId;
        cdl.ShareType = 'V';
        insert cdl;

        return fileName;
    }
}