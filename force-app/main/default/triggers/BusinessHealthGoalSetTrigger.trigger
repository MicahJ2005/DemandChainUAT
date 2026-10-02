trigger BusinessHealthGoalSetTrigger on Business_Health_Goal_Set__c(before insert, before update) {
    BusinessHealthGoalSetHandler.validate(Trigger.new);
}
