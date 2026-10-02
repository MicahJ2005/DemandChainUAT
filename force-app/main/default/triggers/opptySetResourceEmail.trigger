trigger opptySetResourceEmail on Opportunity (before insert, before update) {

// COMMENTED OUT 20171215 AAB - WHAT THE HELL IS THIS CRAP?
	
//trigger performs lookup to custom object 'resources' based on id stored in respective oppty resource field
//returns and sets resource's email address to respective resource field
//email field referenced in workflow that sends out assigned QuickArrow project number to project resources 
	
	////1. Get resource IDs
	//Set<Id> resource1ID = new Set<Id>();
	//for (Opportunity oppty : Trigger.new) {
	//	resource1ID.add(oppty.Resource_One__c);
	//}
	
	//Set<Id> resource2ID = new Set<Id>();
	//for (Opportunity oppty : Trigger.new) {
	//	resource2ID.add(oppty.Resource_Two__c);
	//}
	
	//Set<Id> resource3ID = new Set<Id>();
	//for (Opportunity oppty : Trigger.new) {
	//	resource3ID.add(oppty.Resource_Three__c);
	//}
	
	//Set<Id> resource4ID = new Set<Id>();
	//for (Opportunity oppty : Trigger.new) {
	//	resource4ID.add(oppty.Resource_Four__c);
	//}
	
	//Set<Id> resource5ID = new Set<Id>();
	//for (Opportunity oppty : Trigger.new) {
	//	resource5ID.add(oppty.Resource_Five__c);
	//}
	
	//Set<Id> resource6ID = new Set<Id>();
	//for (Opportunity oppty : Trigger.new) {
	//	resource6ID.add(oppty.Resource_Six__c);
	//}
	
	////2. Get associated resource email address
	//Map<Id, Resource__c> resource1 = new Map<Id, Resource__c>
	//([select Email_Address__c from Resource__c where Id in :resource1ID]);
	
	//Map<Id, Resource__c> resource2 = new Map<Id, Resource__c>
	//([select Email_Address__c from Resource__c where Id in :resource2ID]);
	
	//Map<Id, Resource__c> resource3 = new Map<Id, Resource__c>
	//([select Email_Address__c from Resource__c where Id in :resource3ID]);
	
	//Map<Id, Resource__c> resource4 = new Map<Id, Resource__c>
	//([select Email_Address__c from Resource__c where Id in :resource4ID]);
	
	//Map<Id, Resource__c> resource5 = new Map<Id, Resource__c>
	//([select Email_Address__c from Resource__c where Id in :resource5ID]);
	
	//Map<Id, Resource__c> resource6 = new Map<Id, Resource__c>
	//([select Email_Address__c from Resource__c where Id in :resource6ID]);
       
	////3. Place resource assoicated email address in corresponding email field
	//for (Opportunity oppty : Trigger.new) {
	
	//	if(oppty.Resource_One__c != null) {
	//	// System.debug('ID: ' + resources1);
	//	oppty.Resource_One_Email__c = resource1.get(oppty.Resource_One__c).Email_Address__c;
	//	} else {oppty.Resource_One_Email__c = null;}
		
	//	if(oppty.Resource_Two__c != null) {
	//	oppty.Resource_Two_Email__c = resource2.get(oppty.Resource_Two__c).Email_Address__c;
	//	} else {oppty.Resource_Two_Email__c = null;}
		
	//	if(oppty.Resource_Three__c != null) {
	//	oppty.Resource_Three_Email__c = resource3.get(oppty.Resource_Three__c).Email_Address__c;
	//	} else {oppty.Resource_Three_Email__c = null;}
		
	//	if(oppty.Resource_Four__c != null) {
	//	oppty.Resource_Four_Email__c = resource4.get(oppty.Resource_Four__c).Email_Address__c;
	//	} else {oppty.Resource_Four_Email__c = null;}
		
	//	if(oppty.Resource_Five__c != null) {
	//	oppty.Resource_Five_Email__c = resource5.get(oppty.Resource_Five__c).Email_Address__c;
	//	} else {oppty.Resource_Five_Email__c = null;}
		
	//	if(oppty.Resource_Six__c != null) {
	//	oppty.Resource_Six_Email__c = resource6.get(oppty.Resource_Six__c).Email_Address__c;
	//	} else {oppty.Resource_Six_Email__c = null;}
	//}
}