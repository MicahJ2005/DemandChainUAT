/**
 * @group Assignments
 *
 * @description Jira DCIP-94
 * Handles the integration between Salesforce and 1Password.
 * 1Password vaults are created for each account, and users are added to the
 * vaults based on their assignments. Vault access is determined based on a
 * user having an active assignment on a given account.
 */
public without sharing class PasswordVaultService {
    private static final String ENDPOINT = 'callout:DC1PasswordAPI/api/';
    private static final Date END_DATE_OFFSET = System.today() - 14;

    /**
     * @description Given a list of Assignments, process them based on whether they are active
     * @param  assignments List of Assignment records
     */
    public static void processNewAssignments(List<pse__Assignment__c> assignments) {
        if (!isEnabled) {
            return;
        }

        List<pse__Assignment__c> assignmentsToProcess = [
            SELECT
                Id,
                pse__Project__c,
                pse__Project__r.pse__Account__c,
                pse__Resource__c,
                pse__Start_Date__c,
                pse__End_Date__c
            FROM pse__Assignment__c
            WHERE Id IN :assignments AND pse__Project__r.pse__Account__r.Name != 'Demand Chain'
        ];

        Set<Id> newAssignments = new Set<Id>();
        Set<pse__Assignment__c> expiredAssignments = new Set<pse__Assignment__c>();
        Date today = Date.today();
        for (pse__Assignment__c a : assignmentsToProcess) {
            if (a.pse__Start_Date__c <= today && a.pse__End_Date__c > END_DATE_OFFSET) {
                newAssignments.add(a.Id);
            } else {
                expiredAssignments.add(a);
            }
        }

        if (newAssignments.size() > 0) {
            addUsersToVault(new List<Id>(newAssignments));
        }
        if (expiredAssignments.size() > 0) {
            processExpiredAssignments(new List<pse__Assignment__c>(expiredAssignments));
        }
    }

    /**
     * @description for each assignment, get other active assignments for the resource with the same account
     * if there are no other active assignments, remove the user from the vault
     * @param  triggeringAssignments List of deleted or expired assignments
     */
    public static void processExpiredAssignments(List<pse__Assignment__c> triggeringAssignments) {
        if (!isEnabled) {
            return;
        }

        Set<Id> resources = new Set<Id>();
        Set<Id> accounts = new Set<Id>();
        Set<Id> projects = new Set<Id>();
        Map<Id, Contact> resourceMap = new Map<Id, Contact>();
        Map<Id, pse__Proj__c> projectMap = new Map<Id, pse__Proj__c>();

        for (pse__Assignment__c a : triggeringAssignments) {
            resources.add(a.pse__Resource__c);
            projects.add(a.pse__Project__c);
        }
        for (pse__Proj__c p : [
            SELECT Id, pse__Account__c, pse__Account__r.CredentialVaultId__c
            FROM pse__Proj__c
            WHERE Id IN :projects
        ]) {
            accounts.add(p.pse__Account__c);
            projectMap.put(p.Id, p);
        }

        for (Contact c : [
            SELECT Id, Email
            FROM Contact
            WHERE Id IN :resources
        ]) {
            resourceMap.put(c.Id, c);
        }

        Map<Id, Map<Id, List<pse__Assignment__c>>> resourceToAcctToAssignments = new Map<Id, Map<Id, List<pse__Assignment__c>>>();

        // build a map of resource to account to assignments
        // these are assignments that are active today
        // should not include the triggering assignments (as they are either deleted or expired)
        for (pse__Assignment__c assign : [
            SELECT Id, pse__Project__r.pse__Account__c, pse__Resource__c
            FROM pse__Assignment__c
            WHERE
                pse__Start_Date__c <= TODAY
                AND pse__End_Date__c > :END_DATE_OFFSET
                AND pse__Project__r.pse__Account__c IN :accounts
                AND pse__Resource__c IN :resources
        ]) {
            Map<Id, List<pse__Assignment__c>> tmpMap1 = resourceToAcctToAssignments.get(
                assign.pse__Resource__c
            );
            if (tmpMap1 == null) {
                tmpMap1 = new Map<Id, List<pse__Assignment__c>>();
            }
            List<pse__Assignment__c> tmpList = tmpMap1.get(assign.pse__Project__r.pse__Account__c);
            if (tmpList == null) {
                tmpList = new List<pse__Assignment__c>();
            }
            tmpList.add(assign);
            tmpMap1.put(assign.pse__Project__r.pse__Account__c, tmpList);
            resourceToAcctToAssignments.put(assign.pse__Resource__c, tmpMap1);
        } //END loop

        for (pse__Assignment__c curAssign : triggeringAssignments) {
            // get all assignments for given resource with the same account as the deleted/expired assignment
            List<pse__Assignment__c> allAssignments = resourceToAcctToAssignments
                ?.get(curAssign.pse__Resource__c)
                ?.get(projectMap.get(curAssign.pse__Project__c).pse__Account__c);

            // if there are other active assignments, do nothing
            if (allAssignments != null && allAssignments.size() > 0) {
                continue;
            }

            System.debug(
                '### removing user from vault: ' +
                    resourceMap.get(curAssign.pse__Resource__c).Email +
                    ' ' +
                    projectMap.get(curAssign.pse__Project__c).pse__Account__r.CredentialVaultId__c
            );
            removeUserFromVault(
                resourceMap.get(curAssign.pse__Resource__c).Email,
                projectMap.get(curAssign.pse__Project__c).pse__Account__r.CredentialVaultId__c
            );
        }
    }

    /**
     * @description callout to the 1Password integration to check if a vault exists
     * @param  vaultId The vault id to check, from Account.CredentialVaultId__c
     * @return         true if the vault exists, false if it does not
     */
    public static Boolean vaultExists(String vaultId) {
        if (String.isBlank(vaultId)) {
            return false;
        }

        Http http = new Http();
        HttpRequest req = new HttpRequest();

        req.setTimeout(120000);
        req.setEndpoint(ENDPOINT + 'vaults/' + vaultId);
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/json');

        HttpResponse res = http.send(req);
        // get response code

        if (res.getStatusCode() == 200) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @description create a vault for a given account
     * @param  account An account record with the Id, Name, and (optionally) Account_Name_Short__c fields populated
     * @return         the vault id of the newly created vault
     */
    public static String createVault(Account account) {
        String vaultName = getVaultName(account);
        String vaultId = createVault(vaultName);
        if (String.isBlank(vaultId)) {
            Logger.error('No vault ID returned for account: ' + account.Name).setRecord(account);
            return null;
        }
        Logger.debug('Vault ' + vaultId + ' created for account: ' + account.Name)
            .setRecord(account);
        return vaultId;
    }

    /**
     * @description create a vault for a given account
     * @param  vaultName The name to give the new vault
     * @return           the vault id of the newly created vault
     */
    public static String createVault(String vaultName) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();

        req.setTimeout(120000);
        req.setEndpoint(ENDPOINT + 'vaults');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody('{"name": "' + vaultName + '"}');

        HttpResponse res = http.send(req);

        Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String id = (String) resMap.get('id');
        // TODO null check or deserialize into class
        if (String.isBlank(id)) {
            return null;
        }
        // check response too
        return id;
    }

    /**
     * @description Create a vault for a given account. Updates the account with the vault id.
     * @param  accountId The Id of the account to create a vault for
     */
    @future(callout=true)
    public static void createVaultAsync(String accountId) {
        Account account = [
            SELECT Id, Name, Account_Name_Short__c
            FROM Account
            WHERE Id = :accountId
        ][0];
        String vaultName = getVaultName(account);
        account.CredentialVaultId__c = createVault(vaultName);
        update account;
    }

    /**
     * @description Create a vault for a given account. Updates the account with the vault id.
     * @param  accountId The Id of the account to create a vault for
     * @param  vaultName The name to give the new vault
     */
    @AuraEnabled
    @future(callout=true)
    public static void createVaultAsync(String accountId, String vaultName) {
        Account account;

        if (String.isBlank(vaultName)) {
            account = [
                SELECT Id, Name, Account_Name_Short__c
                FROM Account
                WHERE Id = :accountId
            ][0];
            vaultName = getVaultName(account);
        } else {
            account = new Account(Id = accountId);
        }
        account.CredentialVaultId__c = createVault(vaultName);
        update account;
    }

    /**
     * @description Given an account, determine the name to give the vault
     * @param  account Account record with the Name and (optionally) Account_Name_Short__c fields populated
     * @return         The name to give the vault
     */
    private static String getVaultName(Account account) {
        String vaultName = String.isNotBlank(account.Account_Name_Short__c)
            ? account.Account_Name_Short__c
            : account.Name;

        return vaultName;
    }

    /**
     * @description Given an email address and a vault id, remove the user from the vault
     * @param  email   email address of the user to remove
     * @param  vaultId vault id to remove the user from
     */
    @future(callout=true)
    public static void removeUserFromVault(String email, String vaultId) {
        // if vault doesn't exist, exit, no need to remove user
        if (!vaultExists(vaultId)) {
            return;
        }

        Http http = new Http();
        HttpRequest req = new HttpRequest();

        req.setTimeout(120000);
        req.setEndpoint(ENDPOINT + 'vaults/' + vaultId + '/users');
        req.setMethod('DELETE');
        req.setHeader('Content-Type', 'application/json');
        req.setBody('{"email": "' + email + '"}');

        HttpResponse res = http.send(req);
    }

    /**
     * @description Given a list of assignment ids, add the users to the vaults
     * @param  assignmentIds List of assignment ids to add users from
     */
    @future(callout=true)
    private static void addUsersToVault(List<Id> assignmentIds) {
        Logger.debug('Entering addUsersToVault');
        List<pse__Assignment__c> assignments = new List<pse__Assignment__c>(
            [
                SELECT
                    Id,
                    pse__Resource__r.Email,
                    pse__Resource__r.Name,
                    pse__Project__r.pse__Account__c,
                    pse__Project__r.pse__Account__r.Name,
                    pse__Project__r.pse__Account__r.Account_Name_Short__c,
                    pse__Project__r.pse__Account__r.CredentialVaultId__c
                FROM pse__Assignment__c
                WHERE Id IN :assignmentIds
            ]
        );

        // build a map of all accounts related to the assignments
        Set<Account> accountsToUpdate = new Set<Account>();
        Map<Id, Account> accountMap = new Map<Id, Account>();
        for (pse__Assignment__c a : assignments) {
            Logger.debug('Assignment for: ' + a.pse__Resource__r.Name).setRecord(a);
            accountMap.put(
                a.pse__Project__r.pse__Account__c,
                new Account(
                    Id = a.pse__Project__r.pse__Account__c,
                    Name = a.pse__Project__r.pse__Account__r.Name,
                    Account_Name_Short__c = a.pse__Project__r.pse__Account__r.Account_Name_Short__c,
                    CredentialVaultId__c = a.pse__Project__r.pse__Account__r.CredentialVaultId__c
                )
            );
        }

        // for each account, check if vault exists
        // if not, pass it to createVault, then place in set to update
        for (Account a : accountMap.values()) {
            Logger.debug('Checking vault for account: ' + a.Name).setRecord(a);
            if (String.isBlank(a.CredentialVaultId__c)) {
                Logger.debug('Creating vault for account: ' + a.Name).setRecord(a);
                a.CredentialVaultId__c = createVault(a);
                accountsToUpdate.add(a);
            }
            Logger.debug('Vault exists for account: ' + a.Name).setRecord(a);
        }

        for (pse__Assignment__c a : assignments) {
            Http http = new Http();
            HttpRequest req = new HttpRequest();

            String vaultId = accountMap.get(a.pse__Project__r.pse__Account__c).CredentialVaultId__c;

            req.setTimeout(120000);
            req.setEndpoint(ENDPOINT + 'vaults/' + vaultId + '/users');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody('{"email": "' + a.pse__Resource__r.Email + '"}');

            HttpResponse res = http.send(req);
            System.debug('### response: ' + res.getBody());
        }

        update new List<Account>(accountsToUpdate);
        Logger.saveLog();
    }

    /**
     * @description Check whether the PasswordVaultAssignments feature flag is enabled
     */
    private static Boolean isEnabled {
        get {
            FeatureFlag__mdt flag = [
                SELECT Id, Enabled__c
                FROM FeatureFlag__mdt
                WHERE DeveloperName = 'PasswordVaultAssignments'
            ][0];
            return flag.Enabled__c;
        }
        private set;
    }
}