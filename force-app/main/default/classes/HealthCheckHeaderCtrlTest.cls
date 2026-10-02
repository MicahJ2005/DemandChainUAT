/**
 * Test class for the HealthCheckHeaderCtrl
 * @author  James Loghry
 * @date  8/22/2016
 */
@isTest
private class HealthCheckHeaderCtrlTest {
    
    /*static testmethod void testGetApiVersion(){
        Account acct = new Account(Name='Test');
        insert acct;

        Account_Org__c ao = new Account_Org__c(
            Name = 'Test'
            ,Account__c = acct.Id
            ,URL__c = 'http://test.salesforce.com'
            ,Username__c = 'username'
            ,Password__c = 'password'
            ,Security_Token__c = 'token'
            ,Client_Secret__c = 'secret'
            ,Consumer_Key__c = 'token'
        );
        insert ao;

        //First, fake the login response.
        RESTRequest.OAuth2Response fakeLoginResp = HealthCheckMockCallout.fakeLogin();

        RESTQueriesCtrl.ApiVersionResponse apiVersionResp = new RESTQueriesCtrl.ApiVersionResponse();
        apiVersionResp.version = '37.0';
        apiVersionResp.label = 'label';
        apiVersionResp.url = 'url';

        //Construct the list of responses the mock callout will "return"
        List<Object> responseObjects = new List<Object>{
            fakeLoginResp
            ,apiVersionResp
        };

        //Set the mock callout that will generate fake response for the unit tests.
        HealthCheckMockCallout callout = new HealthCheckMockCallout(responseObjects);
        Test.setMock(HttpCalloutMock.class,callout);

        Test.startTest();
        String result = HealthCheckHeaderCtrl.getOrganizationAPIVersion(ao.Id);
        Test.stopTest();

        System.assertEquals('37.0',result);
    }*/

    static testmethod void testGetAccessToken(){
        Healthcheck_oAuth_Settings__c settings = new Healthcheck_oAuth_Settings__c(
            Name='Custom'
            ,Access_Token_URL__c = 'https://url.com'
            ,Proxy_URL__c = 'https://url.com'
            ,Client_Secret__c = 'secret'
            ,Redirect_URI__c = 'redirectUri'
            ,Client_Id__c = 'clientId'
        );
        insert settings;

        HealthCheckHeaderCtrl.OAuth2LoginResponse tokenResponse = new HealthCheckHeaderCtrl.OAuth2LoginResponse();
        tokenResponse.url = 'http://url.com';
        tokenResponse.isSuccessful = true;
        tokenResponse.responseMessage = 'resp';
        tokenResponse.access_token = 'token';
        tokenResponse.instance_url = 'instanceUrl';
        tokenResponse.refresh_token = 'refreshToken';
        tokenResponse.id = 'https://domain.salesforce.com/id/123/456';

        RESTQueriesCtrl.ApiVersionResponse apiVersionResp = new RESTQueriesCtrl.ApiVersionResponse();
        apiVersionResp.version = '37.0';
        apiVersionResp.label = 'label';
        apiVersionResp.url = 'url';
        List<RESTQueriesCtrl.APIVersionResponse> apiVersionListResp = 
            new List<RESTQueriesCtrl.APIVersionResponse>{apiVersionResp};
                
        
        RESTRequestUtil.IdentityResponse ir = new RESTRequestUtil.IdentityResponse();
        ir.display_name = 'Test';
        
        HealthCheckHeaderCtrl.OrganizationResponse oresp = new HealthCheckHeaderCtrl.OrganizationResponse();
        oresp.records = new List<HealthCheckHeaderCtrl.OrganizationWrapper>();
        
        HealthCheckHeaderCtrl.OrganizationWrapper ow = new HealthCheckHeaderCtrl.OrganizationWrapper();
        ow.Name = 'DCS';
        ow.OrganizationType = 'Enterprise Edition';
        oresp.records.add(ow);
        

        //Construct the list of responses the mock callout will "return"
        List<Object> responseObjects = new List<Object>{
            tokenResponse
            ,apiVersionListResp
            ,ir
            ,oresp
        };

        //Set the mock callout that will generate fake response for the unit tests.
        HealthCheckMockCallout callout = new HealthCheckMockCallout(responseObjects);
        Test.setMock(HttpCalloutMock.class,callout);

        Test.startTest();
        String result = HealthCheckHeaderCtrl.getAccessToken('Custom','http://url.com','code');
        Test.stopTest();

        RESTRequestUtil rrResult = (RESTRequestUtil)JSON.deserialize(result,RESTRequestUtil.class);
        System.assertEquals('37.0',rrResult.apiVersion);
        System.assertEquals('DCS',rrResult.organizationName);
        System.assertEquals('Enterprise Edition',rrResult.organizationType);
        System.assertEquals('Test',rrResult.IdentityResponse.display_name);
    }

    static testmethod void testLoginViaOauthRedirect(){
        Healthcheck_oAuth_Settings__c settings = new Healthcheck_oAuth_Settings__c(
            Name='Custom'
            ,Access_Token_URL__c = 'https://url.com'
            ,Proxy_URL__c = 'https://url.com'
            ,Client_Secret__c = 'secret'
            ,Redirect_URI__c = 'redirectUri'
            ,Client_Id__c = 'clientId'
        );
        insert settings;

        //Construct the list of responses the mock callout will "return"
        List<Object> responseObjects = new List<Object>{
            'someResponse'
        };

        //Set the mock callout that will generate fake response for the unit tests.
        HealthCheckMockCallout callout = new HealthCheckMockCallout(responseObjects);
        callout.statusCode = 300;
        callout.locationHeader = 'locationHeader';
        Test.setMock(HttpCalloutMock.class,callout);

        Test.startTest();
        HealthCheckHeaderCtrl.OAuth2LoginResponse result = HealthCheckHeaderCtrl.loginViaOAuth('Custom','http://url');
        Test.stopTest();

        System.assertEquals('locationHeader',result.url);
    }

    static testmethod void testLoginViaOauth(){
        Healthcheck_oAuth_Settings__c settings = new Healthcheck_oAuth_Settings__c(
            Name='Custom'
            ,Access_Token_URL__c = 'https://url.com'
            ,Proxy_URL__c = 'https://url.com'
            ,Client_Secret__c = 'secret'
            ,Redirect_URI__c = 'redirectUri'
            ,Client_Id__c = 'clientId'
        );
        insert settings;

        //Construct the list of responses the mock callout will "return"
        List<Object> responseObjects = new List<Object>{
            'window.location.replace(\'someJavascriptUrl\');'
        };

        //Set the mock callout that will generate fake response for the unit tests.
        HealthCheckMockCallout callout = new HealthCheckMockCallout(responseObjects);
        callout.statusCode = 200;
        Test.setMock(HttpCalloutMock.class,callout);

        Test.startTest();
        HealthCheckHeaderCtrl.OAuth2LoginResponse result = HealthCheckHeaderCtrl.loginViaOAuth('Custom','http://url');
        Test.stopTest();

        System.assertEquals('someJavascriptUrl',result.url);
    }

    static testmethod void testLoginUsernamePasswordFlowSuccess(){
        Healthcheck_oAuth_Settings__c settings = new Healthcheck_oAuth_Settings__c(
            Name='Custom'
            ,Access_Token_URL__c = 'https://url.com'
            ,Proxy_URL__c = 'https://url.com'
            ,Client_Secret__c = 'secret'
            ,Redirect_URI__c = 'redirectUri'
            ,Client_Id__c = 'clientId'
        );
        insert settings;

        Account acct = new Account(Name='Test');
        insert acct;

        Account_Org__c ao = new Account_Org__c(
            Account__c = acct.Id
            ,URL__c = 'http://url.com'
            ,Username__c = 'user'
            ,Password__c = 'password'
            ,Security_Token__c = 'token'
        );
        insert ao;

        HealthCheckHeaderCtrl.OAuth2LoginResponse loginResponse = new HealthCheckHeaderCtrl.OAuth2LoginResponse();
        loginResponse.url = 'url';
        loginResponse.isSuccessful = true;
        loginResponse.responseMessage = 'test';
        loginResponse.access_token = 'token';
        loginResponse.instance_url = 'url';
        loginResponse.id = 'https://domain.salesforce.com/id1/id2';

        RESTQueriesCtrl.ApiVersionResponse apiVersionResp = new RESTQueriesCtrl.ApiVersionResponse();
        apiVersionResp.version = '37.0';
        apiVersionResp.label = 'label';
        apiVersionResp.url = 'url';
        List<RESTQueriesCtrl.APIVersionResponse> apiVersionListResp = 
            new List<RESTQueriesCtrl.APIVersionResponse>{apiVersionResp};
                
                
        RESTRequestUtil.IdentityResponse ir = new RESTRequestUtil.IdentityResponse();
        ir.display_name = 'Test';
        
        HealthCheckHeaderCtrl.OrganizationResponse oresp = new HealthCheckHeaderCtrl.OrganizationResponse();
        oresp.records = new List<HealthCheckHeaderCtrl.OrganizationWrapper>();
        
        HealthCheckHeaderCtrl.OrganizationWrapper ow = new HealthCheckHeaderCtrl.OrganizationWrapper();
        ow.Name = 'DCS';
        ow.OrganizationType = 'Enterprise Edition';
        oresp.records.add(ow);       
        

        //Construct the list of responses the mock callout will "return"
        List<Object> responseObjects = new List<Object>{
            loginResponse
            ,apiVersionListResp
            ,ir
            ,oresp
        };

        //Set the mock callout that will generate fake response for the unit tests.
        HealthCheckMockCallout callout = new HealthCheckMockCallout(responseObjects);

        Test.setMock(HttpCalloutMock.class,callout);
        Test.startTest();
        String result = HealthCheckHeaderCtrl.loginUsernamePasswordFlow(ao.Id);
        Test.stopTest();

        RESTRequestUtil rr = (RESTRequestUtil)JSON.deserialize(result,RESTRequestUtil.class);
        //System.assertEquals(true,rr.isSuccessful);
        System.assertEquals('DCS',rr.organizationName);
        System.assertEquals('Enterprise Edition',rr.organizationType);
        System.assertEquals('Test',rr.IdentityResponse.display_name);
    }

    static testmethod void testLoginUsernamePasswordFlowException(){
        Healthcheck_oAuth_Settings__c settings = new Healthcheck_oAuth_Settings__c(
            Name='Custom'
            ,Access_Token_URL__c = 'https://url.com'
            ,Proxy_URL__c = 'https://url.com'
            ,Client_Secret__c = 'secret'
            ,Redirect_URI__c = 'redirectUri'
            ,Client_Id__c = 'clientId'
        );
        insert settings;

        Account acct = new Account(Name='Test');
        insert acct;

        Account_Org__c ao = new Account_Org__c(
            Account__c = acct.Id
            ,URL__c = 'http://url.com'
            ,Username__c = 'user'
            ,Password__c = 'password'
            ,Security_Token__c = 'token'
        );
        insert ao;

        HealthCheckHeaderCtrl.OAuth2LoginResponse loginResponse = new HealthCheckHeaderCtrl.OAuth2LoginResponse();
        loginResponse.url = 'url';
        loginResponse.isSuccessful = true;
        loginResponse.responseMessage = 'test';
        loginResponse.access_token = 'token';
        loginResponse.instance_url = 'url';

        //Construct the list of responses the mock callout will "return"
        List<Object> responseObjects = new List<Object>{
            loginResponse
        };

        //Set the mock callout that will generate fake response for the unit tests.
        HealthCheckMockCallout callout = new HealthCheckMockCallout(responseObjects);

        //Cause an exception to occur.
        callout.exceptionThrownIndex = 0;

        Test.setMock(HttpCalloutMock.class,callout);
        Test.startTest();
        String result = HealthCheckHeaderCtrl.loginUsernamePasswordFlow(ao.Id);
        Test.stopTest();

        RESTRequestUtil rr = (RESTRequestUtil)JSON.deserialize(result,RESTRequestUtil.class);
        System.assertEquals(false,rr.isSuccessful);
        System.assertEquals('TEST',rr.errorMessage);
    }
}