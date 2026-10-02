trigger PtoAccrualSetup_Trigger on PTO_Accrual_Setup__c (before delete, after insert, after update, before insert, before update) {
    if (trigger.isDelete) {
        PtoBalanceMethods.deletePtoBalance(trigger.oldmap);
    }
    
    if (trigger.isBefore && (trigger.isInsert || trigger.isUpdate)) {
        for (PTO_Accrual_Setup__c oAccrualSetup : trigger.new) {
        	PtoBalanceMethods.checkForOverlappingAccruals(oAccrualSetup);
        }
    }
    
    if (trigger.isAfter && (trigger.isInsert || trigger.isUpdate)) {
        //upsert missing PTO Balance records
        for (PTO_Accrual_Setup__c oAccrualSetup : trigger.new) {
        	PtoBalanceMethods.generatePTOBalances(oAccrualSetup);
        }
    }
}