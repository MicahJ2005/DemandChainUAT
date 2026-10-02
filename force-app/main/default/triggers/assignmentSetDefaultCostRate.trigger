trigger assignmentSetDefaultCostRate on pse__Assignment__c (before insert, before update) {

    /////////////////////////////////////////////////////////////////////////// 
    ///
    /// Name:		assignmentSetDefaultCostRate
    /// Author: 	Chris Dahlberg
    /// Date: 		8/8/2012
    ///	Purpose: 	When a new FForce assignment is created, populate the default cost 
    ///				from the assignments related contact record
    ///
    /////////////////////////////////////////////////////////////////////////// 
    
    List<Id> contactIds = new List<Id>();
    List<Id> assignmentIds = new List<Id>();
    
    for (pse__Assignment__c assgn : Trigger.new) { 
        contactIds.add(assgn.pse__Resource__c);
        assignmentIds.add(assgn.Id);
    }
System.debug('rcd: assignmentIds.count: ' + assignmentIds.size());

	Map<Id,Contact> allContacts = new Map<Id,Contact> ([select Id, FirstName, LastName, pse__Default_Cost_Rate__c from Contact where Id in :contactIds ]); 	  

System.debug('rcd: allContacts.count: ' + allContacts.size());

	for (pse__Assignment__c assgn : Trigger.new) {
System.debug('rcd: working on assigment: ' + assgn.Id + ' and setting the resource ' + assgn.pse__Resource__c + ' rate to ' +  allContacts.get(assgn.pse__Resource__c).pse__Default_Cost_Rate__c);	
		assgn.pse__Cost_Rate_Amount__c = allContacts.get(assgn.pse__Resource__c).pse__Default_Cost_Rate__c;
System.debug('rcd: pse__Cost_Rate_Amount__c: ' + assgn.pse__Cost_Rate_Amount__c);
	}
}