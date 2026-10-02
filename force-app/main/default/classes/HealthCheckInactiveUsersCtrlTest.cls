/**
 * Test class for the HealthCheckInactiveUsersCtrl
 * @author  James Loghry
 * @date  11/7/2016
 */
@isTest
private class HealthCheckInactiveUsersCtrlTest {

    static testmethod void testGetInactiveUsers() {
        HealthCheckInactiveUsersCtrl.UserResponse ur = new HealthCheckInactiveUsersCtrl.UserResponse();
        ur.records = new List<HealthCheckInactiveUsersCtrl.UserWrapper>();
        
        HealthCheckInactiveUsersCtrl.UserWrapper uw = new HealthCHeckInactiveUsersCtrl.UserWrapper();
        uw.inactiveCount = 10;
        ur.records.add(uw);
        
        

        //Construct the list of responses the mock callout will "return"
        List<Object> responseObjects = new List<Object>{
            ur
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
            ,MobilePhone='111-111-1111'
        	,Company='Company');
        //insert rr.newLead;
        String rrString = JSON.serialize(rr);

        Test.startTest();
        HealthCheckInactiveUsersCtrl.InactiveUsersWrapper result = HealthCheckInactiveUsersCtrl.getInactiveUsers(rrString);
        Lead l = (Lead)JSON.deserialize(result.newLead,Lead.class);
        insert l;
        
        HealthCheckInactiveUsersCtrl.updateLead(JSON.serialize(l));
        Test.stopTest();

        System.assertEquals(10,result.recordCount);
    }
}