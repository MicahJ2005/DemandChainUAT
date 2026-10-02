trigger Assignment_Trigger on pse__Assignment__c(after delete, after insert, after update) {
    AssignmentTriggerHandler handler = new AssignmentTriggerHandler();

    if (Trigger.isInsert) {
        if (Trigger.isAfter) {
            handler.onAfterInsert(Trigger.new);
        }
    } else if (Trigger.isUpdate) {
        if (Trigger.isAfter) {
            handler.onAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isDelete) {
        if (Trigger.isAfter) {
            handler.onAfterDelete(Trigger.old);
        }
    }

}