public with sharing class EventSignIn_Cntrl {
	@AuraEnabled
	public static List<CampaignMember> getCMData() {
		return [SELECT Id
						,Contact.FirstName
						,Contact.LastName
						,Contact.Account.Name 
					FROM CampaignMember 
					WHERE Campaign.Active_Sign_in__c = true 
						AND SignedIn__c = false
					ORDER BY Contact.LastName];
	}
	@AuraEnabled
	public static void signinCM(String cmid){
		CampaignMember cm = new CampaignMember();
			cm.Id = cmid;
			cm.SignedIn__c = true;
		update cm;
	}
	@AuraEnabled
	public static void createNew(String fname, String lname, String comp, String cEmail, String cTitle){
		Lead l = new Lead();
			l.FirstName = fname;
			l.LastName = lname;
			l.Company = comp;
			l.Email = cEmail;
			l.Title = cTitle;
		insert l;
		CampaignMember cm = new CampaignMember();
			cm.LeadId = l.Id;
			cm.CampaignId = [SELECT Id FROM Campaign WHERE Active_Sign_in__c = true LIMIT 1].Id;
			cm.SignedIn__c = true;
		insert cm;
	}
}