/******************************************************************************
* This can be scheduled, or run manually. 
*      Batch_PeriodPerformanceAccountPlan batchClass = new Batch_PeriodPerformanceAccountPlan(); 
*      Database.ExecuteBatch(batchClass, 200);
*
*  Batch_PeriodPerformanceAccountPlan
*      Query for account plans and groups them by Account, Practice, Year, Month
*
* 
* @Author:         Morgan Paradis / Sophia Murphy (Demand Chain)
* @Date:           06.04.2019
*
* @Updates
*                      
*/
global class Batch_PeriodPerformanceAccountPlan implements Database.Batchable<AggregateResult>, Database.Stateful   
{
    global Iterable<AggregateResult> start (Database.BatchableContext bc){
        return new AggregateResultIterable();
    }
    
    global void execute(Database.BatchableContext bc, List<sObject> scope){
        List<Period_Performance__c> ppList = new List<Period_Performance__c>();
        for(sObject objScope : scope){
            
            Id accId = ((Id)(objScope.get('Account__c')));
            Id practice = ((Id)(objScope.get('Practice1__c')));
            Integer year = ((Integer)(objScope.get('year')));
            Integer month = ((Integer)(objScope.get('month')));
            Decimal amt = ((Decimal)(objScope.get('amt')));
            if(month != null && year != null && amt != null){
                if(practice == null){
                    practice = [SELECT Id From pse__Practice__c Where Name = 'Corporate' Limit 1].Id;
                }
                Date periodEnd = date.newInstance(year, month+1, 1).addDays(-1);
                Date startDate = date.newInstance(year, month, 1); 
                Date endDate = date.newInstance(year, 12, 31);
                for(Integer i = 0; i < (startDate.monthsBetween(endDate)+1); i++){
                    Period_Performance__c pp = new Period_Performance__c();
                    pp.Account__c = accId;
                    pp.Account_Plan__c = (amt / (startDate.monthsBetween(endDate)+1));
                    pp.Period_Ending__c = periodEnd.addMonths(i);
                    pp.Practice1__c = practice;
                    pp.PP_Id__c = String.valueOf(accId) + '-' + String.valueOf(practice) + '-' +  String.valueOf(year) + '-' +  String.valueOf(month + i);
                    ppList.add(pp);
                }
            }
            
        }
        Schema.sObjectField f = Period_Performance__c.Fields.PP_Id__c;
        Database.upsertResult [] cr = Database.upsert(ppList, f, false);
    }
    
    global void finish(Database.BatchableContext BC) {
        Database.ExecuteBatch(new Batch_PeriodPerformanceAccounts(), 200);
    }
    
    global class AggregateResultIterable implements Iterable<AggregateResult> {
        global Iterator<AggregateResult> Iterator(){
            return new AggregateResultIterator('Batch_PeriodPerformanceAccountPlan');
        }
    }
    
}