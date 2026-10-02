public class Invocable_PasswordVaultAssignments {
    @InvocableMethod(
        label='Process assignments for password vault access'
        description='Assigns password vault access to users based on assignment records. If the assignment is active, or inactive, access is granted or revoked respectively.'
        category='Assignment'
    )
    public static void processAssignments(List<Id> assignmentIds) {
        List<pse__Assignment__c> assignments = new List<pse__Assignment__c>();
        for (Id assignmentId : assignmentIds) {
            assignments.add(new pse__Assignment__c(Id = assignmentId));
        }
        System.debug('### Assignments: ' + assignments);
        PasswordVaultService.processNewAssignments(assignments);
    }
}