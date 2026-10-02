/**
 * @group Estimate
 *
 * @description Generates PDF and Word exports of an Estimate, saved as a ContentVersion
 * on the Estimate record. PDF uses EstimatePdf.page (renderAs="PDF") via
 * getContentAsPDF(), following the same pattern already used by QuotePdfSaver for the
 * standard Quote object. Word uses a SEPARATE plain-HTML page, EstimateWord.page, via
 * getContent() - renderAs="PDF" is a page-level directive that forces EVERY retrieval
 * method (including getContent()) to return PDF-rendered bytes, so a single page can't
 * serve both formats; saving those PDF bytes with a .doc extension is what produced
 * unreadable output before this was split into two pages.
 *
 * Not directly unit tested: PageReference.getContentAsPDF()/.getContent() throw
 * "Methods defined as TestMethod do not support getContent call" in test context -
 * a platform limitation, not something a test can work around. QuotePdfSaver has the
 * same gap for the same reason. EstimatePdfController (the data underneath the page)
 * is covered by EstimatePdfControllerTest instead.
 */
public with sharing class EstimateExportController {
    /**
     * @description Render the estimate as a PDF and attach it to the Estimate record.
     * @param  estimateId estimate to export
     * @return            the Id of the generated ContentVersion, for building a download link
     */
    @AuraEnabled
    public static Id generatePdf(Id estimateId) {
        return generateAndSave(estimateId, false);
    }

    /**
     * @description Render the estimate as a Word-openable document (HTML saved with a
     * .doc extension - Salesforce has no native docx renderer) and attach it to the
     * Estimate record.
     * @param  estimateId estimate to export
     * @return            the Id of the generated ContentVersion, for building a download link
     */
    @AuraEnabled
    public static Id generateWord(Id estimateId) {
        return generateAndSave(estimateId, true);
    }

    private static Id generateAndSave(Id estimateId, Boolean asWord) {
        try {
            Blob fileBlob = renderPage(estimateId, asWord);
            String fileName = buildFileName(estimateId, asWord);
            return saveAsContentVersion(estimateId, fileName, fileBlob);
        } catch (Exception e) {
            Logger.error('Failed to generate estimate export for ' + estimateId, e);
            Logger.saveLog();
            String message = 'Unable to generate export: ' + e.getMessage();
            AuraHandledException ex = new AuraHandledException(message);
            ex.setMessage(message);
            throw ex;
        }
    }

    /**
     * @description The one line of this class that cannot be unit tested -
     * PageReference.getContent()/.getContentAsPDF() are unsupported in test context.
     * Kept as small and isolated as possible so everything else here stays covered.
     */
    @TestVisible
    private static Blob renderPage(Id estimateId, Boolean asWord) {
        PageReference exportPage = asWord ? Page.EstimateWord : Page.EstimatePdf;
        exportPage.getParameters().put('id', estimateId);
        return asWord ? exportPage.getContent() : exportPage.getContentAsPDF();
    }

    @TestVisible
    private static String buildFileName(Id estimateId, Boolean asWord) {
        return 'Estimate_' + estimateId + (asWord ? '.doc' : '.pdf');
    }

    @TestVisible
    private static Id saveAsContentVersion(Id estimateId, String fileName, Blob fileBlob) {
        ContentVersion cv = new ContentVersion();
        cv.Title = fileName;
        cv.PathOnClient = fileName;
        cv.VersionData = fileBlob;
        insert cv;

        // ContentDocumentId isn't reliably populated on the in-memory record immediately
        // after insert (notably in test context), so requery for it explicitly.
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.LinkedEntityId = estimateId;
        cdl.ContentDocumentId = cv.ContentDocumentId;
        cdl.ShareType = 'V';
        insert cdl;

        return cv.Id;
    }
}
