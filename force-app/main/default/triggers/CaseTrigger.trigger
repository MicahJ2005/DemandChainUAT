//created to help automate some of the PC cases.
trigger CaseTrigger on Case (after insert) {
    if(Trigger.isAfter && Trigger.isInsert) {
        //It's all wrapped in a try catch - because no matter what
        // - I don't want anything to keep this case from being created
        try {
        	CaseTriggerHandler.setPCProject(Trigger.new);
            CaseTriggerHandler.catchDCSentCases(Trigger.new);
        } catch (Exception e) {}
    }
}