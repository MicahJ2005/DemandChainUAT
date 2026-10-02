/**
 * Test class for the HealthCheckRolesCtrl
 * @author  James Loghry
 * @date  11/7/2016
 */
@isTest
private class HealthCheckRolesCtrlTest {

	static testmethod void testGetUserRoles() {
        HealthCheckRolesCtrl.UserRoleResponse urr = new HealthCheckRolesCtrl.UserRoleResponse();
        urr.records = new List<HealthCheckRolesCtrl.UserRoleWrapper>();
        
        Id fakeRoleId = [Select Id From User Limit 1].Id;
        HealthCheckRolesCtrl.UserRoleWrapper urw = new HealthCheckRolesCtrl.UserRoleWrapper();
        urw.Id = fakeRoleId;
        urw.Name = 'Fake Role';
        urr.records.add(urw);
        
        HealthCheckRolesCtrl.UserResponse ur = new HealthCheckRolesCtrl.UserResponse();
        ur.records = new List<HealthCheckRolesCtrl.UserWrapper>();
        
        HealthCheckRolesCtrl.UserWrapper uw = new HealthCheckRolesCtrl.UserWrapper();
        uw.roleCount = 10;
        uw.UserRoleId = fakeRoleId;
        ur.records.add(uw);

		//Construct the list of responses the mock callout will "return"
		List<Object> responseObjects = new List<Object>{
			urr
            ,ur
		};

		//Set the mock callout that will generate fake response for the unit tests.
		HealthCheckMockCallout callout = new HealthCheckMockCallout(responseObjects);
		Test.setMock(HttpCalloutMock.class,callout);

		Healthcheck_oAuth_Settings__c settings = new Healthcheck_oAuth_Settings__c(
			Name='Custom'
			,Access_Token_URL__c = 'https://url.com'
			,Proxy_URL__c = 'https://url.com'
			,Client_Secret__c = 'secret'
			,Redirect_URI__c = 'redirectUri'
			,Client_Id__c = 'clientId'
		);
		RESTRequestUtil rr = new RESTRequestUtil();
		rr.settings = settings;
        rr.newLead = new Lead(
        	Firstname='First'
            ,Lastname='Last'
            ,Email='test@test.com'
            ,Company='Company'
            ,MobilePhone='111-111-1111'
        );
		String rrString = JSON.serialize(rr);

		Test.startTest();
		HealthCheckRolesCtrl.UserRoleResponse result = HealthCheckRolesCtrl.getUserRoles(rrString);
        Lead l = (Lead)JSON.deserialize(result.newLead,Lead.class);
        insert l;
        HealthCheckRolesCtrl.updateLead(JSON.serialize(l));
		Test.stopTest();

		System.assertNotEquals(null,result);
		System.assertEquals(1,result.records.size());
		System.assertEquals(10,result.records.get(0).childrenCount);
	}
}