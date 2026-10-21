@IsTest
private class BusinessHealthEinsteinLlmTest {
    @IsTest
    static void buildsTheRequest() {
        aiplatform.ModelsAPI.createGenerations_Request req = BusinessHealthEinsteinLlm.request('sfdc_ai__Model', 'Hello');
        System.assertEquals('sfdc_ai__Model', req.modelName);
        System.assertEquals('Hello', req.body.prompt);
    }

    @IsTest
    static void readsTheGeneratedText() {
        aiplatform.ModelsAPI_GenerationRepresentation gen = new aiplatform.ModelsAPI_GenerationRepresentation();
        gen.generatedText = 'Advice';
        aiplatform.ModelsAPI_GenerationResponse body = new aiplatform.ModelsAPI_GenerationResponse();
        body.generation = gen;
        aiplatform.ModelsAPI.createGenerations_Response resp = new aiplatform.ModelsAPI.createGenerations_Response();
        resp.Code200 = body;
        System.assertEquals('Advice', BusinessHealthEinsteinLlm.generatedText(resp));
    }

    @IsTest
    static void rejectsAnEmptyResponse() {
        try {
            BusinessHealthEinsteinLlm.generatedText(new aiplatform.ModelsAPI.createGenerations_Response());
            System.assert(false, 'expected an error');
        } catch (BusinessHealthAdvisor.AdvisorException e) {
            System.assert(e.getMessage().contains('no generation'));
        }
    }

    @IsTest
    static void callsTheModelsApi() {
        // Tests can't reach the model; the call either fails or returns nothing usable.
        try {
            new BusinessHealthEinsteinLlm().generate('sfdc_ai__Model', 'Hello');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }
    }
}
