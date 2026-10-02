@RestResource(urlMapping='/external/case')
global with sharing class ConnectedAppCaseSubmission {

    // This method handles POST requests to /services/apexrest/external/case
    @HttpPost
    global static String createCaseFromExternal() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        System.debug('IN ConnectedAppCaseSubmission');
        try {
            // Parse the incoming JSON
            String requestBody = req.requestBody.toString();
            Map<String, Object> caseData = (Map<String, Object>) JSON.deserializeUntyped(requestBody);

            Case newCase = new Case();

            // Basic field mappings (expand as needed)
            newCase.Subject = (String) caseData.get('Subject');
            newCase.Description = (String) caseData.get('Description');
            newCase.SuppliedEmail = (String) caseData.get('SuppliedEmail');
            newCase.Origin = 'Web'; // You can override or pass from external data

            insert newCase;

            Case newCaseToReturn = [SELECT Id, CaseNumber FROM Case WHERE Id = :newCase.Id];
            // Return success response
            res.statusCode = 201;
            return JSON.serialize(new Map<String, Object>{
                'success' => true,
                'caseId' => newCaseToReturn.Id,
                'caseNumber' => newCaseToReturn.CaseNumber
            });

        } catch (Exception ex) {
            res.statusCode = 400;
            return JSON.serialize(new Map<String, Object>{
                'success' => false,
                'message' => ex.getMessage()
            });
        }
    }
}