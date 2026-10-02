global class Batch_PeriodPerformanceSchedule implements Schedulable{
    global void execute (SchedulableContext SC){
     Batch_PeriodPerformanceOpps batchClass = new Batch_PeriodPerformanceOpps(); 
		Database.ExecuteBatch(batchClass, 200); 
    }
}