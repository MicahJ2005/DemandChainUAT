@isTest
private class EventSignIn_Cntrl_Test {
	
	@isTest static void test_EventSignIn_Cntrl() {
		Contact c = new Contact();
			c.FirstName = 'First';
			c.LastName = 'LastName';
		insert c;

		Campaign camp = new Campaign();
			camp.IsActive = true;
			camp.Name = 'Test';
			camp.Active_Sign_in__c = true;
		insert camp;

		CampaignMember cm = new CampaignMember();
			cm.ContactId = c.Id;
			cm.CampaignId = camp.Id;
		insert cm;

		Test.startTest();
			EventSignIn_Cntrl.getCMData();
			EventSignIn_Cntrl.signinCM(cm.Id);
			EventSignIn_Cntrl.createNew('FirstName', 'LastName', 'Company', 'test@test.com', 'Owner');
		Test.stopTest();
	}
}