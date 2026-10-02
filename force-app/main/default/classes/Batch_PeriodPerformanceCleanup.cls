/******************************************************************************
 * This can be scheduled, or run manually. 
 *      Batch_PeriodPerformanceCleanup batchClass = new Batch_PeriodPerformanceCleanup(); 
 *      Database.ExecuteBatch(batchClass, 200);
 *
 *  Batch_PeriodPerformanceCleanup
 *      Query for period performance records with all 0s and delete them
 *
 * 
 * @Author:         Morgan Paradis / Sophia Murphy (Demand Chain)
 * @Date:           06.04.2019
 *
 * @Updates
 *                      
 */
global class Batch_PeriodPerformanceCleanup implements Database.Batchable<sObject>, Database.Stateful {
    global Database.QueryLocator start (Database.BatchableContext bc){
     	return Database.getQueryLocator('SELECT ID FROM Period_Performance__c WHERE Has_Data_In_Period__c = false');
    }
    
    global void execute(Database.BatchableContext bc, List<Period_Performance__c> scope){
        List<Period_Performance__c> deleteList = new List<Period_Performance__c>();
        for(Period_Performance__c pp : scope){
            deleteList.add(pp);
        }
        delete deleteList;
    }

    global void finish(Database.BatchableContext BC) {

    }
}