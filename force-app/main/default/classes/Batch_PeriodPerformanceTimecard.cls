/******************************************************************************
* This can be scheduled, or run manually. 
*      Batch_PeriodPerformanceTimecard batchClass = new Batch_PeriodPerformanceTimecard(); 
*      Database.ExecuteBatch(batchClass, 200);
*
*  Batch_PeriodPerformanceTimecard
*      Query for timecards and groups them by Account, Practice, Year, Month
*
*  Calls Batch_PeriodPerformanceBillingEvent from the FINISH METHOD
* 
* @Author:         Morgan Paradis / Sophia Murphy (Demand Chain)
* @Date:           06.04.2019
*
* @Updates
*                      
*/
global class Batch_PeriodPerformanceTimecard implements Database.Batchable<AggregateResult>, Database.Stateful   
{
    global Iterable<AggregateResult> start (Database.BatchableContext bc){
        return new AggregateResultIterable();
    }
    
    global void execute(Database.BatchableContext bc, List<sObject> scope){
        List<Period_Performance__c> ppList = new List<Period_Performance__c>();
        for(sObject objScope : scope){
            Id accId = ((Id)(objScope.get('acc')));
            Id practice = ((Id)(objScope.get('practice')));
            Integer year = ((Integer)(objScope.get('year')));
            Integer month = ((Integer)(objScope.get('month')));
            if(month != null && year != null){
                if(practice == null){
                    practice = [SELECT Id From pse__Practice__c Where Name = 'Corporate' Limit 1].Id;
                }
                Date periodEnd = date.newInstance(year, month+1, 1).addDays(-1);
                
                Period_Performance__c pp = new Period_Performance__c();
                pp.Timecard_Revenue__c = ((Decimal)objScope.get('amt'));
                pp.Account__c = accId;
                pp.Practice1__c = practice;
                pp.Period_Ending__c = periodEnd;
                pp.PP_Id__c = String.valueOf(accId) + '-' + String.valueOf(practice) + '-' +  String.valueOf(year) + '-' +  String.valueOf(month);
                ppList.add(pp);
            }
        }
        Schema.sObjectField f = Period_Performance__c.Fields.PP_Id__c;
        Database.upsertResult [] cr = Database.upsert(ppList, f, false);
    }
    
    global void finish(Database.BatchableContext BC) {
        Database.ExecuteBatch(new Batch_PeriodPerformanceBillingEvent(), 200);
    }
    
    global class AggregateResultIterable implements Iterable<AggregateResult> {
        global Iterator<AggregateResult> Iterator(){
            return new AggregateResultIterator('Batch_PeriodPerformanceTimecard');
        }
    }
    
}