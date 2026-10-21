/**
 * @group BusinessHealth
 *
 * @description Einstein Models API implementation of the AI Advisor's LLM seam. Kept in
 * its own class because the aiplatform namespace only exists in orgs with Einstein
 * generative AI enabled; BusinessHealthAdvisor loads it by name, so the rest of the app
 * still deploys (with rule-based advice) where Einstein is off.
 */
public with sharing class BusinessHealthEinsteinLlm implements BusinessHealthAdvisor.Llm {
    public String generate(String model, String prompt) {
        return generatedText(new aiplatform.ModelsAPI().createGenerations(request(model, prompt)));
    }

    @TestVisible
    private static aiplatform.ModelsAPI.createGenerations_Request request(String model, String prompt) {
        aiplatform.ModelsAPI.createGenerations_Request req = new aiplatform.ModelsAPI.createGenerations_Request();
        req.modelName = model;
        aiplatform.ModelsAPI_GenerationRequest body = new aiplatform.ModelsAPI_GenerationRequest();
        body.prompt = prompt;
        req.body = body;
        return req;
    }

    @TestVisible
    private static String generatedText(aiplatform.ModelsAPI.createGenerations_Response resp) {
        if (resp == null || resp.Code200 == null || resp.Code200.generation == null) {
            throw new BusinessHealthAdvisor.AdvisorException('The Einstein Models API returned no generation.');
        }
        return resp.Code200.generation.generatedText;
    }
}
