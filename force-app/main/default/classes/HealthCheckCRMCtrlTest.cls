/**
 * Test class for the HealthCheckCRMCtrl
 * @author  James Loghry
 * @date  8/22/2016
 */
@isTest
private class HealthCheckCRMCtrlTest {

    static testmethod void testGetCRM() {
        //First, fake the login response.
        RESTRequestUtil.OAuth2Response fakeLoginResp = HealthCheckMockCallout.fakeLogin();

        //All of the callouts in the GetCRM method return a query response.
        //So we're going to use the same object for each response :)
        HealthCheckCRMCtrl.QueryResponse qr1 = new HealthCheckCRMCtrl.QueryResponse();
        qr1.totalSize = 5;

        List<Object> responseObjects = new List<Object>{
            fakeLoginResp
            ,qr1
            ,qr1
            ,qr1
            ,qr1
            ,qr1
            ,qr1
            ,qr1
        };

        //Set the mock callout that will generate fake response for the unit tests.
        HealthCheckMockCallout callout = new HealthCheckMockCallout(responseObjects);
        Test.setMock(HttpCalloutMock.class,callout);

        //Generate the object that we need to pass in for the method we are testing.
        RestRequestUtil rr = HealthCheckMockCallout.getRestRequest();
        rr.apiVersion = '37.0';

        Test.startTest();
        HealthCheckCRMCtrl.CRMWrapper result = HealthCheckCRMCtrl.getCRM(JSON.serialize(rr));
        Test.stopTest();

        //Assert all the things, yo!
        System.assertEquals(5,result.contacts);
        System.assertEquals(5,result.leads);
        System.assertEquals(5,result.opportunities);
        System.assertEquals(5,result.campaigns);
        System.assertEquals(5,result.cases);
        System.assertEquals(5,result.products);
        System.assert(result.displayOpportunities);
        System.assert(result.displayCampaigns);
        System.assert(result.displayCases);
        System.assert(result.displayProducts);
    }
}