//20220808 KDJ: Commenting trigger as trigger is creating duplicate Utilization records
//
//Name            : PseUtilizationDetailAiudClone
//Revision Log    : 2012-04-11 JT Lovell (FinacialForce)
//                : 
//                : 
//Use             : On Insert/Update
//                : 1. Create & Upsert a new Utilization__c record
//                :    Copy all fields.
//                :    Set the owner of the new record to Resource's SFDC User 
//                :    Note: does not create a record if there isn't a valid active user for the resource
//                : 
//                : On Delete 
//                : 3. Cascade the delete to delete the related Utilization__c records
//

trigger PseUtilizationDetailAiudClone on pse__Utilization_Detail__c (after delete, after insert, after update) {   
/* 
  // Before Insert/Update
  if(Trigger.isInsert || Trigger.isUpdate){
    Map<Id,PseUtilization__c> mapNewUtilizationsRecs = new Map<Id,PseUtilization__c>();
    
    PseUtilization__c recUtilization;
    
    Set<Id> setAffectedIds = new Set<Id>();
    for(pse__Utilization_Detail__c utilDetail : Trigger.New){
      setAffectedIds.add(utilDetail.Id);
    }
    
    List<pse__Utilization_Detail__c> lstUtilizationDetail = new List<pse__Utilization_Detail__c>([
      SELECT Id,
             pse__Group__c,
             pse__Historical_Billable_Hours__c,
             pse__Historical_Calendar_Hours__c,
             pse__Historical_Credited_Hours__c,
             pse__Historical_Excluded_Hours__c,
             pse__Historical_Start_Date__c,
             pse__Historical_End_Date__c,
             pse__Practice__c,
             pse__Region__c,
             pse__Resource__c,
             pse__Scheduled_Billable_Hours__c,
             pse__Scheduled_Calendar_Hours__c,
             pse__Scheduled_Credited_Hours__c,
             pse__Scheduled_Excluded_Hours__c,
             pse__Scheduled_Non_Billable_Hours__c,
             pse__Scheduled_Start_Date__c,
             pse__Scheduled_End_date__c,
             pse__Time_Period__c,
             pse__Resource__r.pse__Salesforce_User__c,
             pse__Resource__r.pse__Salesforce_User__r.IsActive,
             pse__Utilization_Calculation__c,
             pse__Historical_Utilization_Target_Hours__c,
             pse__Scheduled_Utilization_Target_Hours__c,
             pse__Utilization_Target_Hours__c,
             pse__Template_Key__c,
             pse__Time_Period_Type__c
        FROM pse__Utilization_Detail__c
       WHERE Id IN :setAffectedIds
      
    ]);
    
    for(pse__Utilization_Detail__c utilDetail : lstUtilizationDetail){
      
      //Cloning to Utilization__c
      recUtilization = new PseUtilization__c();   
      recUtilization.UtilizationDetailId__c                 = utilDetail.Id;
      recUtilization.Group__c                               = utilDetail.pse__Group__c ;
      recUtilization.Historical_Billable_Hours__c           = utilDetail.pse__Historical_Billable_Hours__c;
      recUtilization.Historical_Calendar_Hours__c           = utilDetail.pse__Historical_Calendar_Hours__c;  
      recUtilization.Historical_Credited_Hours__c           = utilDetail.pse__Historical_Credited_Hours__c;
      recUtilization.Historical_Excluded_Hours__c           = utilDetail.pse__Historical_Excluded_Hours__c;  
      recUtilization.Historical_Start_Date__c               = utilDetail.pse__Historical_Start_Date__c;  
      recUtilization.Historical_End_Date__c                 = utilDetail.pse__Historical_End_Date__c;  
      recUtilization.Practice__c                            = utilDetail.pse__Practice__c  ;
      recUtilization.Region__c                              = utilDetail.pse__Region__c;
      recUtilization.Resource__c                            = utilDetail.pse__Resource__c;
      recUtilization.Scheduled_Billable_Hours__c            = utilDetail.pse__Scheduled_Billable_Hours__c;  
      recUtilization.Scheduled_Calendar_Hours__c            = utilDetail.pse__Scheduled_Calendar_Hours__c  ;
      recUtilization.Scheduled_Credited_Hours__c            = utilDetail.pse__Scheduled_Credited_Hours__c  ;
      recUtilization.Scheduled_Excluded_Hours__c            = utilDetail.pse__Scheduled_Excluded_Hours__c;  
      recUtilization.Scheduled_Non_Billable_Hours__c        = utilDetail.pse__Scheduled_Non_Billable_Hours__c;  
      recUtilization.Scheduled_Start_Date__c                = utilDetail.pse__Scheduled_Start_Date__c;  
      recUtilization.Scheduled_End_Date__c                  = utilDetail.pse__Scheduled_End_Date__c;  
      recUtilization.Time_Period__c                         = utilDetail.pse__Time_Period__c;
      recUtilization.Utilization_Calculation__c             = utilDetail.pse__Utilization_Calculation__c;
      recUtilization.Historical_Utilization_Target_Hours__c = utilDetail.pse__Historical_Utilization_Target_Hours__c;
      recUtilization.Scheduled_Utilization_Target_Hours__c  = utilDetail.pse__Scheduled_Utilization_Target_Hours__c;
      recUtilization.Utilization_Target_Hours__c            = utilDetail.pse__Utilization_Target_Hours__c;
      recUtilization.Template_Key__c                        = utilDetail.pse__Template_Key__c;
      recUtilization.Time_Period_Type__c                    = utilDetail.pse__Time_Period_Type__c;
      
      // update utilization records setting owner id
      // only create the record if there's a user with that ID to retrieve it
      if(utilDetail.pse__Resource__c != null && 
         utilDetail.pse__Resource__r.pse__Salesforce_User__c != null &&
         utilDetail.pse__Resource__r.pse__Salesforce_User__r.IsActive == true) {
        recUtilization.OwnerId = utilDetail.pse__Resource__r.pse__Salesforce_User__c;
        mapNewUtilizationsRecs.put(utilDetail.id,recUtilization);
      }
      
      System.Debug('INSERTED_UTE_REC');
    }
    
    // insert records to database
    upsert mapNewUtilizationsRecs.values() UtilizationDetailId__c;
  }
  
  // Before Delete
  if(Trigger.isDelete){
    Set<Id> setAffectedIds = new Set<Id>();
    
    for(pse__Utilization_Detail__c rec :Trigger.old){
      setAffectedIds.add(rec.Id);
    }
    
    List<PseUtilization__c> lstUtilizationToDelete = new List<PseUtilization__c>([
      SELECT Id 
        FROM PseUtilization__c 
       WHERE UtilizationDetailId__c IN :setAffectedIds
    ]);
    
    delete lstUtilizationToDelete;
  }
*/
}