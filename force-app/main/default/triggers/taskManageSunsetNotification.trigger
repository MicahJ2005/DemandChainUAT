trigger taskManageSunsetNotification on Task (after delete, after update) {

// COMMENTED OUT 20171215 AAB - WHAT THE HELL IS THIS CRAP?

//// Get related Oppty ID
//Set<Id> opptyId = new Set<Id>();
//for (Task t : Trigger.old) {
//    opptyId.add(t.WhatID);
//}

////Array to hold all Task WhatIDs to be deleted
//List<Opportunity> opptysToUpdate = new List<Opportunity>();

//if(Trigger.isDelete) {  
////ON DELETE OF SUNSET NOTIFICATION TASK
////	Update related oppty fields if related sunset task is deleted
////		1) Set 'Sunset Notification Created' = FALSE
////		2) Clear out sunset task comments
			
//	//Loop through trigger
//	for (Integer i = 0; i < Trigger.old.size(); i++) {  
		
//    	for (Opportunity o : [Select Sunset_Meeting_Review_Items__c, Sunset_Notification_Created__c From Opportunity Where Id in :opptyId]) {
//			o.Sunset_Meeting_Review_Items__c = '';
//			o.Sunset_Notification_Created__c = false;
	                                
//	  	    opptysToUpdate.add(o);                            
//   		}
		
//		if(opptysToUpdate.size() > 0) update opptysToUpdate;
		
//	}
//}


//if(trigger.isUpdate){
////ON UPDATE OF A SUNSET TASK DESCRIPTION UPDATE RELATED OPPTY 'SUNSET MEETING REVIEW ITEMS' FIELD

//	//Loop through trigger
//	for (Integer i = 0; i < Trigger.new.size(); i++) {  
		
//		Task taskUpdatedSunsetItem = Trigger.new[i];
		
//		if(taskUpdatedSunsetItem.Sunset_Notification_Task__c == TRUE){
//	    	for (Opportunity o : [Select Sunset_Meeting_Review_Items__c From Opportunity Where Id in :opptyId]) {
//				o.Sunset_Meeting_Review_Items__c = taskUpdatedSunsetItem.Description;
		                                
//		  	    opptysToUpdate.add(o);                            
//	   		}
//		}
		
//		if(opptysToUpdate.size() > 0) update opptysToUpdate;
		
//	}
	
//}

}