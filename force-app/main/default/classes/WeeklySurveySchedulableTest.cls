@isTest
private class WeeklySurveySchedulableTest {
    static testMethod void testExecute(){
        WeeklySurveySchedulable s = new WeeklySurveySchedulable();
        Test.startTest();
        s.execute(null);
        Test.stopTest();
        
        Weekly_Survey__c survey = [Select Survey_Date__c,Survey_Date_Formatted__c From Weekly_Survey__c];
        System.assertNotEquals(null,survey.Survey_Date__c);
        System.assert(!String.isEmpty(survey.Survey_Date_Formatted__c));
    }
}