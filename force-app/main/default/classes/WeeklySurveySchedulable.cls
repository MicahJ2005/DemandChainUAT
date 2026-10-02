public class WeeklySurveySchedulable implements Schedulable {
   public void execute(SchedulableContext ctx) {
      insert new Weekly_Survey__c(Survey_Date__c=Date.today());
   }   
}