@isTest
private class ClientPortal_REST_UT{
	static Account TEST_ACCOUNT = new Account();
	static Contact TEST_CONTACT = new Contact();
	static Case TEST_CASE = new Case();
	static CLIENT_SFDC_Comment__c TEST_COMMENT = new CLIENT_SFDC_Comment__c();
	static CLIENT_SFDC_Instance__c TEST_ORG = new CLIENT_SFDC_Instance__c(); 
	
	static testMethod void Test_CreateData(){
		//Account TEST_ACCOUNT = new Account();
		TEST_ACCOUNT.Name = 'Test Account';
		insert TEST_ACCOUNT;
		
		TEST_ORG.Account__c = TEST_ACCOUNT.Id;
		TEST_ORG.Id__c = UserInfo.getOrganizationId();
		TEST_ORG.InstanceID__c = 'cs4';
		insert TEST_ORG;
		
		//Contact TEST_CONTACT = new Contact();
		TEST_CONTACT.AccountId = TEST_ACCOUNT.Id;
		TEST_CONTACT.Firstname = 'Test';
		TEST_CONTACT.Lastname = 'Contact';
		TEST_CONTACT.PortalID__c = UserInfo.getUserId();
		insert TEST_CONTACT;
		
		//Case TEST_CASE = new Case();
		TEST_CASE.AccountId = TEST_ACCOUNT.Id;
		TEST_CASE.ContactId = TEST_CONTACT.Id;
		TEST_CASE.Status = 'New';
		TEST_CASE.Subject = 'Test Subject';
		TEST_CASE.Description = 'Test Description';		
		insert TEST_CASE;
		
		//CLIENT_SFDC_Comment__c TEST_COMMENT = new CLIENT_SFDC_Comment__c();
		TEST_COMMENT.Account__c = TEST_ACCOUNT.Id;
		TEST_COMMENT.Case__c = TEST_CASE.Id;
		TEST_COMMENT.Comment__c = 'Test String';
		TEST_COMMENT.Contact__c = TEST_CONTACT.Id;
		TEST_COMMENT.External__c = TRUE;
		TEST_COMMENT.IsPublic__c = TRUE;
		insert TEST_COMMENT;
		
		ClientPortal_REST.DCS_Case TEST_DCSCASE = new ClientPortal_REST.DCS_Case(TEST_CASE);
				
	}

	static testMethod void Test_ClientPortalGET(){
		RestRequest req = new RestRequest();
		RestResponse res = new RestResponse();
		
		req.requestURI = 'https://cs4.salesforce.com/services/apexrest/ClientPortal';
		req.httpMethod = 'GET';
		req.addHeader('CLIENT-OrgID', UserInfo.getOrganizationId());
		req.addHeader('CLIENT-UserID', UserInfo.getUserId());
		req.addHeader('DCS-CaseList', 'Open');		
		RestContext.request = req;
		RestContext.response = res;
		ClientPortal_REST.DCS_Response TEST_RESPONSE = new ClientPortal_REST.DCS_Response();
		TEST_RESPONSE = ClientPortal_REST.doGet();
	}
	
	static testMethod void Test_ClientPortalPOST(){
		RestRequest req = new RestRequest();
		RestResponse res = new RestResponse();
		
		req.requestURI = 'https://cs4.salesforce.com/services/apexrest/ClientPortal';
		req.httpMethod = 'POST';
		req.addHeader('CLIENT-OrgID', UserInfo.getOrganizationId());
		req.addHeader('CLIENT-UserID', UserInfo.getUserId());
		req.addHeader('DCS-SubmitType','Case');		
		RestContext.request = req;
		RestContext.response = res;
		ClientPortal_REST.DCS_Response TEST_RESPONSE = new ClientPortal_REST.DCS_Response();
		TEST_RESPONSE = ClientPortal_REST.doGet();
	}
	
}