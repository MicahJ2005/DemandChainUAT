trigger opptySunsetNotification on Opportunity (after update) {

// COMMENTED OUT 20171215 AAB - WHAT THE HELL IS THIS CRAP?

	////Get Oppty ID
 //   Set<Id> opptyId = new Set<Id>();
 //   for (Opportunity o : Trigger.new) {
 //       opptyId.add(o.Id);
 //   }

	////build list of opptys that have sunset tasks
	//List<Task> sunsetTaskCount = [select WhatId from Task where WhatID in :opptyID and Subject like 'Sunset Meeting%'];
	
	//Set<String> sunsetTaskIdSet = new Set<String>();
	
	//for (Integer i = 0; i <sunsetTaskCount.size(); i++) { 
   		
 // 		String taskId = String.valueOf(sunsetTaskCount[i].WhatId);
 //  		System.debug('sunset Task ID: ' + taskId); 
 //  		sunsetTaskIdSet.add(taskId);
 //  	}   

	//for (Integer i = 0; i < Trigger.old.size(); i++) {

	//    Opportunity sourceOpptyCurrentState = Trigger.new[i];
	//    System.debug('sunset meeting task created?: ' + sourceOpptyCurrentState.Sunset_Notification_Created__c);     
	    
	//    String thisOpptyId = String.ValueOf(sourceOpptyCurrentState.Id); 
	                
	//    if(!sunsetTaskIdSet.contains(thisOpptyId) && sourceOpptyCurrentState.Sunset_Notification_Created__c == true){ //if no sunset task exists and field 'sunset notification created' = true (set by 'project close' button) create sunset task
		   
	//	    Task sunsetTask = new Task(
	//	        Subject = 'Sunset Meeting: ' + sourceOpptyCurrentState.Name,
	//	        // Changed AAB 20120106 - Tina's account is not active any longer.
	//	        //OwnerID = '00500000006pAFkAAM',  //assign to tina
	//	        OwnerId = '00500000005CNYC', //assign to Chris (AAB)
	//	        Priority = 'Normal',
	//	        Status = 'Not Started',
	//	        WhatID = sourceOpptyCurrentState.Id,
	//	        ActivityDate = sourceOpptyCurrentState.Target_End_Date__c,
	//	        Description = sourceOpptyCurrentState.Sunset_Meeting_Review_Items__c,
	//	        Sunset_Notification_Task__c = true);
		    
	//	    insert sunsetTask;
	//    }
	//}
}