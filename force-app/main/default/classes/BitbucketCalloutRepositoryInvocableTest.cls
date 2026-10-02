/**
 * @description       : 
 * @author            : James Loghry (Demand Chain)
 * @group             : 
 * @last modified on  : 05-12-2021
 * @last modified by  : James Loghry (Demand Chain)
 * Modifications Log 
 * Ver   Date         Author                        Modification
 * 1.0   05-07-2021   James Loghry (Demand Chain)   Initial Version
**/
@istest
public with sharing class BitbucketCalloutRepositoryInvocableTest{

    static testmethod void testCreateSchedule(){
        Account acct = new Account(Name='Test');
        insert acct;

        Test.setMock(
            HttpCalloutMock.class,
            new CalloutMock(
                new List<CalloutMock.MockResponse>{
                    new CalloutMock.MockResponse(200,''),
                    new CalloutMock.MockResponse(200,''),
                    new CalloutMock.MockResponse(200,''),
                    new CalloutMock.MockResponse(200,''),
                    new CalloutMock.MockResponse(200,''),
                    new CalloutMock.MockResponse(200,''),
                    new CalloutMock.MockResponse(200,'')
                }
            )
        );

        Test.startTest();
        Account_Org__c ao = new Account_Org__c(Account__c = acct.Id, Name='Test', RepositoryName__c='repo');
        insert ao;

        try{
            FlowDefinitionView fdv = [SELECT Id FROM FlowDefinitionView Where ApiName = 'Account_Org_After_Save_Flow' And IsActive=true];
        }catch(QueryException qe){
            BitbucketCalloutRepositoryInvocable.generateRepository(new List<Id>{ao.Id});
        }
        Test.stopTest();
    }
}