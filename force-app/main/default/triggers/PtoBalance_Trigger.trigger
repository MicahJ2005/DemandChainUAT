trigger PtoBalance_Trigger on PTO_Balance__c (after insert, after update) {
    //when a PTO Balance record is updated, reset the starting balance on all subsequent records
    system.debug('Inside PtoBalance_Trigger\n' + trigger.new + '\nPtoBalanceMethods.calculatePtoBalance: ' + PtoBalanceMethods.calculatePtoBalance);
    if (trigger.isAfter && trigger.isUpdate) {
        if (PtoBalanceMethods.calculatePtoBalance) {
            //prevent recursion when recalculating balances
            PtoBalanceMethods.calculatePtoBalance = false;
    		PtoBalanceMethods.ptoBalanceAdjusted(trigger.new, trigger.oldMap);
        }
    }
}