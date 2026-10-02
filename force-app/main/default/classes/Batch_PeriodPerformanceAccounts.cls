/******************************************************************************
* This can be scheduled, or run manually. 
*      Batch_PeriodPerformanceAccount batchClass = new Batch_PeriodPerformanceAccount(); 
*      Database.ExecuteBatch(batchClass, 200);
*
*  Batch_PeriodPerformanceAccounts
*      Query for Active Accounts with no timecard/opportunity/account plan data
*
*  Calls Batch_PeriodPerformanceCleanup from the FINISH METHOD
* 
* @Author:         Morgan Paradis / Sophia Murphy (Demand Chain)
* @Date:           06.04.2019
*
* @Updates
* 07.04.2019	Sophia Murphy (Demand Chain)
*				Removed code that filtered out accounts, we need every month, every account
*                      
*/
global class Batch_PeriodPerformanceAccounts implements Database.Batchable<sObject>, Database.Stateful {
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        Id activeRecordType = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Active Account').getRecordTypeId();
        return Database.getQueryLocator('SELECT Id, RecordTypeId From Account Where RecordTypeId = :activeRecordType');
    }
    
    global void execute(Database.BatchableContext bc, List<Account> scope){
        List<Period_Performance__c> ppList = new List<Period_Performance__c>();
        
        PeriodPerformanceSettings__c cs = PeriodPerformanceSettings__c.getOrgDefaults();
        Date startDate = cs.PP_Start_Date__c;
        Date endDate = cs.PP_End_Date__c;
   
        if(PeriodPerformanceSettings__c.getOrgDefaults().Id == null){
            startDate = Date.today().addMonths(-2);
            endDate = Date.today();
        }
        
        Id practice = [Select Id From pse__practice__c Where Name = 'Corporate' Limit 1].Id;
        
        List<Id> accIds = new List<Id>();
        //for(Period_Performance__c p : [Select Account__c From Period_Performance__c Where (Opportunity_Closed_Won__c != 0 Or Invoiced_Revenue__c != 0 Or Account_Plan__c != 0 Or Timecard_Revenue__c != 0) And Period_Ending__c > :startDate And Period_Ending__c < :endDate]){
        //    accIds.add(p.Account__c);
        //}
        for(Account a : scope){
            //if(!accIds.contains(a.Id)){
                for(Integer i = 0; i < (startDate.monthsBetween(endDate)+1); i++){
                    Period_Performance__c pp = new Period_Performance__c(Practice1__c = practice, Account__c = a.Id,
                                                                         Period_Ending__c = startDate.addMonths(i+1).toStartofMonth().addDays(-1),
                                                                         PP_Id__c = String.valueOf(a.Id) + '-' + String.valueOf(practice) + '-' +  String.valueOf(startDate.addMonths(i).year()) + '-' +  String.valueOf(startDate.addMonths(i).month()));
                    ppList.add(pp);
                }  
            //}      
        }
        Schema.sObjectField f = Period_Performance__c.Fields.PP_Id__c;
        Database.upsertResult [] cr = Database.upsert(ppList, f, false);
        
    }
    
    global void finish(Database.BatchableContext bc){
        Database.ExecuteBatch(new Batch_PeriodPerformanceCleanup(), 200);
    }
}