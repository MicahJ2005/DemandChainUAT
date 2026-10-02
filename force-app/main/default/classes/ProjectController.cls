// File: ProjectController.cls
public without sharing class ProjectController {
    @AuraEnabled(cacheable=true)
    public static List<pse__Proj__c> getProjects() {
        return [SELECT Id, Name, pse__Account__c, pse__Is_Active__c, Budget_Variance__c FROM pse__Proj__c LIMIT 10];
    }
}