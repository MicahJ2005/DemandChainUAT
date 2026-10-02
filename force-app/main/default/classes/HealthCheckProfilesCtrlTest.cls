/**
 * Test class for the HealthCheckProfilesCtrl
 * @author  James Loghry
 * @date  8/22/2016
 */
@isTest
private class HealthCheckProfilesCtrlTest {

    static testmethod void testGetProfiles() {
        HealthCheckProfilesCtrl.PermissionSetResponse psr = new HealthCheckProfilesCtrl.PermissionSetResponse();
        psr.records = new List<HealthCheckProfilesCtrl.PermissionSetWrapper>();
        
        HealthCheckProfilesCtrl.ProfileWrapper pw1 = new HealthCheckProfilesCtrl.ProfileWrapper();
        pw1.Name = 'Test1';

        HealthCheckProfilesCtrl.ProfileWrapper pw2 = new HealthCheckProfilesCtrl.ProfileWrapper();
        pw2.Name = 'Test2';

        HealthCheckProfilesCtrl.ProfileWrapper pw3 = new HealthCheckProfilesCtrl.ProfileWrapper();
        pw3.Name = 'Test3';

        HealthCheckProfilesCtrl.ProfileWrapper pw4 = new HealthCheckProfilesCtrl.ProfileWrapper();
        pw4.Name = 'Test4';

        HealthCheckProfilesCtrl.ProfileWrapper pw5 = new HealthCheckProfilesCtrl.ProfileWrapper();
        pw5.Name = 'Test5';

        List<Profile> pl = [Select Id From Profile Limit 5];
        HealthCheckProfilesCtrl.PermissionSetWrapper psw1 = new HealthCheckProfilesCtrl.PermissionSetWrapper();
        psw1.PermissionsModifyAllData = true;
        psw1.PermissionsViewAllData = true;
        psw1.ProfileId = pl.get(0).Id;
        psw1.Profile = pw1;
        psr.records.add(psw1);
        

        HealthCheckProfilesCtrl.PermissionSetWrapper psw2 = new HealthCheckProfilesCtrl.PermissionSetWrapper();
        psw2.PermissionsModifyAllData = true;
        psw2.PermissionsViewAllData = true;
        psw2.Profile = pw2;
        psw2.ProfileId = pl.get(1).Id;
        psr.records.add(psw2);

        HealthCheckProfilesCtrl.PermissionSetWrapper psw3 = new HealthCheckProfilesCtrl.PermissionSetWrapper();
        psw3.PermissionsModifyAllData = true;
        psw3.PermissionsViewAllData = false;
        psw3.Profile = pw3;
        psw3.ProfileId = pl.get(2).Id;
        psr.records.add(psw3);

        HealthCheckProfilesCtrl.PermissionSetWrapper psw4 = new HealthCheckProfilesCtrl.PermissionSetWrapper();
        psw4.PermissionsModifyAllData = false;
        psw4.PermissionsViewAllData = false;
        psw4.Profile = pw4;
        psw4.ProfileId = pl.get(3).Id;
        psr.records.add(psw4);

        HealthCheckProfilesCtrl.PermissionSetWrapper psw5 = new HealthCheckProfilesCtrl.PermissionSetWrapper();
        psw5.PermissionsModifyAllData = false;
        psw5.PermissionsViewAllData = false;
        psw5.Profile = pw5;
        psw5.ProfileId = pl.get(4).Id;
        psr.records.add(psw5);
        
        HealthCheckProfilesCtrl.UserCountRecord ucrr1 = new HealthCheckProfilesCtrl.UserCountRecord();
        ucrr1.ProfileId = pl.get(0).Id;
        ucrr1.userCount = 10;
        
        HealthCheckProfilesCtrl.UserCountRecord ucrr2 = new HealthCheckProfilesCtrl.UserCountRecord();
        ucrr2.ProfileId = pl.get(1).Id;
        ucrr2.userCount = 10;
        
        HealthCheckProfilesCtrl.UserCountRecord ucrr3 = new HealthCheckProfilesCtrl.UserCountRecord();
        ucrr3.ProfileId = pl.get(2).Id;
        ucrr3.userCount = 10;
        
        HealthCheckProfilesCtrl.UserCountRecord ucrr4 = new HealthCheckProfilesCtrl.UserCountRecord();
        ucrr4.ProfileId = pl.get(3).Id;
        ucrr4.userCount = 10;
        
        HealthCheckProfilesCtrl.UserCountRecord ucrr5 = new HealthCheckProfilesCtrl.UserCountRecord();
        ucrr5.ProfileId = pl.get(4).Id;
        ucrr5.userCount = 10;
        
        
        HealthCheckProfilesCtrl.UserCountResponse ucr = new HealthCheckProfilesCtrl.UserCountResponse();
        ucr.records = new List<HealthCheckProfilesCtrl.UserCountRecord>();
        ucr.records.add(ucrr1);
        ucr.records.add(ucrr2);
        ucr.records.add(ucrr3);
        ucr.records.add(ucrr4);
        ucr.records.add(ucrr5);
        

        //Construct the list of responses the mock callout will "return"
        List<Object> responseObjects = new List<Object>{
            psr
            ,ucr
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
        String rrString = JSON.serialize(rr);

        Test.startTest();
        List<HealthCheckProfilesCtrl.PermissionSetWrapper> result = HealthCheckProfilesCtrl.getProfiles(rrString);
        Test.stopTest();

        System.assertNotEquals(null,result);
        System.assertEquals(5,result.size());
        System.assertEquals('Test1',result.get(0).Profile.Name);
        System.assertEquals(10,result.get(0).userCount);
        System.assertEquals('Test2',result.get(1).Profile.Name);
        System.assertEquals(10,result.get(1).userCount);
        System.assertEquals('Test3',result.get(2).Profile.Name);
        System.assertEquals(10,result.get(2).userCount);
        System.assertEquals('Test4',result.get(3).Profile.Name);
        System.assertEquals(10,result.get(3).userCount);
        System.assertEquals('Test5',result.get(4).Profile.Name);
        System.assertEquals(10,result.get(4).userCount);
        //System.assertEquals(2,result.records.size());
    }
}