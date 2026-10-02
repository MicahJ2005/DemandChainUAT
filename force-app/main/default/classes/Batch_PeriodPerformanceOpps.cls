/******************************************************************************
* This can be scheduled, or run manually. 
*      Batch_PeriodPerformanceOpps batchClass = new Batch_PeriodPerformanceOpps(); 
*      Database.ExecuteBatch(batchClass, 200);
*
*  Batch_PeriodPerformanceOpps
*      Query for opps and groups them by Account, Practice, Year, Month
*
*  Calls Batch_PeriodPerformanceTimecard from the FINISH METHOD
* 
* @Author:         Morgan Paradis / Sophia Murphy (Demand Chain)
* @Date:           06.04.2019
*
* @Updates
*                      
*/
global class Batch_PeriodPerformanceOpps implements Database.Batchable<AggregateResult>, Database.Stateful   
{
    global Iterable<AggregateResult> start (Database.BatchableContext bc){
        return new AggregateResultIterable();
    }
    
    global void execute(Database.BatchableContext bc, List<sObject> scope){
        List<Period_Performance__c> ppList = new List<Period_Performance__c>();
        for(sObject objScope : scope){
            Id accId = ((Id)(objScope.get('AccountId')));
            Id practice = ((Id)(objScope.get('pse__Practice__c')));
            Integer year = ((Integer)(objScope.get('year')));
            Integer month = ((Integer)(objScope.get('month')));
            if(month != null && year != null){
                if(practice == null){
                    practice = [SELECT Id From pse__Practice__c Where Name = 'Corporate' Limit 1].Id;
                }
                Date periodEnd = date.newInstance(year, month+1, 1).addDays(-1);
                
                Period_Performance__c pp = new Period_Performance__c();
                pp.Opportunity_Closed_Won__c = ((Decimal)objScope.get('amt'));
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
    
    global void finish(Database.BatchableContext BC) 
    {
        Database.ExecuteBatch(new Batch_PeriodPerformanceTimecard(), 200);
    }
    
    global class AggregateResultIterable implements Iterable<AggregateResult> {
        global Iterator<AggregateResult> Iterator(){
            return new AggregateResultIterator('Batch_PeriodPerformanceOpps');
        }
    }
    
}