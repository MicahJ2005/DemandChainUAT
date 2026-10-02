public with sharing class AssignmentTriggerHandler {
    private static Boolean hasProcessedVaults = false;

    public void onAfterInsert(List<pse__Assignment__c> newAssignments) {
        Logger.debug('trigger context: Insert');
        if (PtoBalanceMethods.calculatePtoBalance) {
            //prevent recursion when recalculating balances
            PtoBalanceMethods.calculatePtoBalance = false;
            PtoBalanceMethods.updatePTORequested(newAssignments);
        }

        if (!hasProcessedVaults) {
            PasswordVaultService.processNewAssignments(newAssignments);
            hasProcessedVaults = true;
        }

        Logger.saveLog();
    }

    public void onAfterUpdate(
        List<pse__Assignment__c> newAssignments,
        Map<Id, pse__Assignment__c> oldAssignments
    ) {
        Logger.debug('trigger context: Update');
        if (PtoBalanceMethods.calculatePtoBalance) {
            //prevent recursion when recalculating balances
            PtoBalanceMethods.calculatePtoBalance = false;
            PtoBalanceMethods.updatePTORequested(newAssignments);
        }

        if (!hasProcessedVaults) {
            PasswordVaultService.processNewAssignments(newAssignments);
            hasProcessedVaults = true;
        }

        Logger.saveLog();
    }

    public void onAfterDelete(List<pse__Assignment__c> deletedAssignments) {
        PasswordVaultService.processExpiredAssignments(deletedAssignments);
    }
}