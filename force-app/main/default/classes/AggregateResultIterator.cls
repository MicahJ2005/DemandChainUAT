/******************************************************************************
 * Called from the Batch_PeriodPerformance* jobs
 * We need to run aggregate queries, and can't do those directly in Batch jobs
 * 
 * @Author:         Morgan Paradis (Demand Chain)
 * @Date:           06.04.2019
 *
 * @Updates
 *                      
 */
 global class AggregateResultIterator implements Iterator<AggregateResult> {
    AggregateResult [] results {get;set;}
    // tracks which result item is returned
    Integer index {get; set;} 
    
    global AggregateResultIterator(String batchJob) {
        String query;
        index = 0;
        PeriodPerformanceSettings__c cs = PeriodPerformanceSettings__c.getOrgDefaults();

        Date startDate = cs.PP_Start_Date__c;
        Date endDate = cs.PP_End_Date__c;
        
        if(PeriodPerformanceSettings__c.getOrgDefaults().Id == null){
            startDate = Date.today().addMonths(-2);
            endDate = Date.today();
        }
        system.debug(startDate);
        system.debug(endDate);
        // Fire query here to load the results
        String accPlanQuery = 'SELECT Account__c, Practice1__c, SUM(Planned_Revenue__c) amt, calendar_year(Plan_Start_Date__c) year, calendar_month(Plan_Start_Date__c) month FROM Account_Plan__c WHERE Plan_Start_Date__c >= :startDate AND Plan_End_Date__c <= :endDate GROUP BY Account__c, Practice1__c, calendar_year(Plan_Start_Date__c), calendar_month(Plan_Start_Date__c)';
        String oppsQuery = 'SELECT SUM(Amount) amt, AccountId, pse__Practice__c, calendar_year(CloseDate) year, calendar_month(CloseDate) month FROM Opportunity WHERE StageName = \'A. Closed/Won\' AND CloseDate > :startDate AND CloseDate < :endDate GROUP BY AccountId, pse__Practice__c, calendar_year(CloseDate), calendar_month(CloseDate)';       
        String timecardQuery = 'SELECT SUM(pse__Total_Billable_Amount__c) amt, pse__Project__r.pse__Account__c acc, pse__Project__r.pse__Practice__c practice, calendar_Year(pse__Start_Date__c) year, calendar_Month(pse__Start_Date__c) month FROM pse__Timecard__c WHERE pse__Status__c = \'Approved\'AND pse__Start_Date__c > :startDate AND pse__Start_Date__c < :endDate GROUP BY pse__Project__r.pse__Account__c, pse__Project__r.pse__Practice__c, calendar_Year(pse__Start_Date__c), calendar_Month(pse__Start_Date__c)';
        String billingEventQuery = 'SELECT SUM(pse__Summary_Amount__c) amt, pse__Project__r.pse__Account__c acc, pse__Project__r.pse__Practice__c practice, calendar_Year(pse__Invoice_Date__c) year, calendar_Month(pse__Invoice_Date__c) month FROM pse__Billing_Event__c WHERE pse__Invoice_Date__c > :startDate AND pse__Invoice_Date__c < :endDate GROUP BY pse__Project__r.pse__Account__c, pse__Project__r.pse__Practice__c, calendar_Year(pse__Invoice_Date__c), calendar_Month(pse__Invoice_Date__c)';
        if(batchJob == 'Batch_PeriodPerformanceOpps') {
            query = oppsQuery;
        }
        if(batchJob == 'Batch_PeriodPerformanceTimecard'){
            query = timecardQuery;
        }
        if(batchJob == 'Batch_PeriodPerformanceBillingEvent'){
            query = billingEventQuery;
        }
        if(batchJob == 'Batch_PeriodPerformanceAccountPlan'){
            query = accPlanQuery;
        }
        
        results = Database.query(query);            
    } 
    
    global boolean hasNext(){ 
        return results != null && !results.isEmpty() && index < results.size(); 
    }    
    
    global AggregateResult next(){        
        return results[index++];            
    }       
}