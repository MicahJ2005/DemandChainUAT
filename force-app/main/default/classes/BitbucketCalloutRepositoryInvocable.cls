/**
 * @description       : 
 * @author            : James Loghry (Demand Chain)
 * @group             : 
 * @last modified on  : 05-12-2021
 * @last modified by  : James Loghry (Demand Chain)
 * Modifications Log 
 * Ver   Date         Author                        Modification
 * 1.0   05-06-2021   James Loghry (Demand Chain)   Initial Version
**/
public with sharing class BitbucketCalloutRepositoryInvocable {

    @InvocableMethod(label='Create Bitbucket Repository' description='Generate repository for Account Org')
    public static void generateRepository(List<Id> accountOrgId){
        generateRepository(accountOrgId.get(0));
    }

    @future(callout=true)
    private static void generateRepository(Id accountOrgId){
        Account_Org__c accountOrg = [Select Id,Name,RepositoryName__c,BackupCronSchedule__c From Account_Org__c Where Id = :accountOrgId And RepositoryName__c != null];
        BitbucketCallout bbc = new BitbucketCallout();
        bbc.createFork(accountOrg.RepositoryName__c);

        for(Metadata_Repository_Secret__mdt gs : [Select QualifiedApiName,Value__c From Metadata_Repository_Secret__mdt]){
            bbc.createPipelineVariable(accountOrg.RepositoryName__c, gs.QualifiedApiName, gs.Value__c);
        }
        bbc.createPipelineVariable(accountOrg.RepositoryName__c, 'ACCOUNT_ORG_ID', accountOrg.Id);

        String cron = '0 6 0 ? * TUE-SAT *';
        if(!String.isEmpty(accountOrg.BackupCronSchedule__c)){
            cron = accountOrg.BackupCronSchedule__c;
        }

        bbc.createSchedule(accountOrg.RepositoryName__c, cron);

        bbc.enablePipeline(accountOrg.RepositoryName__c, true);
    }
}