trigger Timecard_Trigger on pse__Timecard_Header__c (after insert, after update) {
    system.debug('Timecards processed: ' + trigger.new.size());
	PtoBalanceMethods.updatePTOTaken(trigger.new);
}