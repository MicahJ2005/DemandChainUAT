public class HealthCheckHeaderCtrl {
	@AuraEnabled
	public static String getOrganizationAPIVersion(Id recordId){
        Account_Org__c ao = [Select Id,Name,URL__c,Username__c,Password__c,Environment__c,Security_Token__c,Client_Secret__c,Consumer_Key__c From Account_Org__c Where Id = :recordId];
        RESTRequestUtil rr = new RESTRequestUtil(ao);
        return getAPIVersion(rr);
	}

    public static String getAPIVersion(RESTRequestUtil rr){
        String apiVersionResponse = rr.requestProxy(null,'GET','/services/data');
        //String apiVersionResponse = rr.request(null,'GET','/services/data');
        System.debug('JWL: apiVersionresponse: ' + apiVersioNresponse);
        List<RESTQueriesCtrl.ApiVersionResponse> versions = (List<RESTQueriesCtrl.ApiVersionResponse>)JSON.deserialize(apiVersionResponse,List<RESTQueriesCtrl.ApiVersionResponse>.class);
        return versions.get(versions.size()-1).version;
    }
    
    public static RESTRequestUtil.IdentityResponse getIdentity(RESTREquestUtil rr,String idUrl){
        String idSuffix = idUrl.substring(idUrl.indexOf('/',8));
        String idResponse = rr.requestProxy(null,'GET',idSuffix);
        RESTRequestUtil.IdentityResponse ir = (RESTRequestUtil.IdentityResponse)JSON.deserialize(idResponse,RESTRequestUtil.IdentityResponse.class);
        return ir;
    }

    public static OrganizationWrapper getOrganization(RESTRequestUtil rr){
    	String queryString = '/services/data/v' + rr.apiVersion + '/query?q=Select+OrganizationType,Name+From+Organization+Limit+1';
        String responseString = rr.requestProxy(null,'GET',queryString);
        System.debug('responseString: ' + responseString);
        OrganizationResponse orr = (OrganizationResponse)JSON.deserialize(responseString,OrganizationResponse.class);
  		return orr.records.get(0);      
    }    

    @AuraEnabled
    public static String getAccessToken(String environment,String customUrl,String code){
        Healthcheck_oAuth_Settings__c settings = Healthcheck_oAuth_Settings__c.getValues(environment);
        if('Custom' == environment && !String.isEmpty(customUrl)){
            settings.Authorization_URL__c = 'https://' + customUrl + settings.Access_Token_URL__c;
        }

        Httprequest request = new HttpRequest();
        request.setMethod('POST');
        request.setHeader('Content-Type','application/x-www-form-urlencoded');
        request.setHeader('SalesforceURL',settings.Access_Token_URL__c);
        request.setEndpoint(settings.Proxy_URL__c);

        //request.setEndpoint(settings.Access_Token_URL__c);
        List<String> requestParameters = new List<String>{
            'grant_type=authorization_code'
            ,'client_id=' + settings.Client_Id__c
            ,'client_secret=' + settings.Client_Secret__c
            ,'redirect_uri=' + settings.Redirect_URI__c
            ,'display=mobile'
            ,'response_type=code'
            ,'code='+code
        };
        request.setBody(String.join(requestParameters,'&'));
        System.debug('Request body: ' + request.getBody());

        RESTRequestUtil rr = null;
        try{
            Http http = new Http();
            HttpResponse response = http.send(request);
            Integer statusCode = response.getStatusCode();
            String responseBody = response.getBody();

            System.debug('Response body: ' + responseBody);
            OAuth2LoginResponse result = (OAuth2LoginResponse)JSON.deserialize(responseBody,OAuth2LoginResponse.class);

            rr = new RESTRequestUtil();
            rr.url = result.instance_url;
            rr.accessToken = result.access_token;
            rr.settings = settings;
            String apiVersion = getAPIVersion(rr);
            rr.apiVersion = apiVersion;
            
            RESTRequestUtil.IdentityResponse ir = getIdentity(rr,result.id);
            rr.identityResponse = ir;
            
           	OrganizationWrapper ow = getOrganization(rr);
            rr.organizationType = ow.organizationType;
            rr.organizationName = ow.Name;
           
            try{
            	List<Account_Org__c> matchingOrgs = [Select Id From Account_Org__c Where OrgId__c = :ir.organization_id];
                
                //if(matchingOrgs.isEmpty()){
                    //List<Contact> contacts = [Select Id From Contact Where Email = :ir.email];
                    
                    //if(contacts.isEmpty()){
           				//List<Lead> leads = [Select Id From Lead Where Email = :ir.email];
                    
                    	//if(leads.isEmpty()){
                            //Insert a new lead into DCS's org...
                            Lead l = new Lead(
                                Firstname = ir.first_name
                                ,Lastname = ir.last_name
                                ,Email = ir.email
                                ,MobilePhone = ir.mobile_phone
                                ,Title = ((ir.custom_attributes != null) ? ir.custom_attributes.title : '')
                                ,Company = ow.Name
                                ,Street = ir.addr_street
                                ,City = ir.addr_city
                                ,State = ir.addr_state
                                ,Country = ir.addr_country
                                ,PostalCode = ir.addr_zip
                                ,LeadSource = 'Health Check'
                                ,Health_Check_Organization_Type__c = ow.organizationtype
                                ,RecordTypeId = [Select Id From RecordType Where sObjectType = 'Lead' And DeveloperName='DCS_Health_Check_Lead'].Id
                            );
                            insert l;
                            rr.newLead = l;
                        //}
                    //}
                //}
            }catch(Exception e){
                System.debug('Exception encountered in HealthCheckHeaderCtrl: ' + e.getMessage());
                System.debug(e.getStackTraceString());
                //Oh well, I couldn't create a lead.
            }
        }catch(System.CalloutException e){
            rr = new RESTRequestUtil(e);
        }
        return JSON.serialize(rr);
    }

    @AuraEnabled
    public static OAuth2LoginResponse loginViaOAuth(String environment,String customUrl){
        Healthcheck_oAuth_Settings__c settings = Healthcheck_oAuth_Settings__c.getValues(environment);
        if('Custom' == environment && !String.isEmpty(customUrl)){
            settings.Authorization_URL__c = 'https://' + customUrl + settings.Authorization_URL__c;
        }

        Httprequest request = new HttpRequest();
        request.setMethod('POST');
        request.setHeader('Content-Type','application/x-www-form-urlencoded');
  		request.setHeader('SalesforceURL',settings.Authorization_URL__c);
        request.setEndpoint(settings.Proxy_URL__c);

        System.debug('headers: ' + request.getHeader('SalesforceURL'));
        System.debug('request endpoint: ' + request.getEndpoint());
        List<String> requestParameters = new List<String>{
            'grant_type=authorization_code'
            ,'client_id=' + settings.Client_Id__c
            ,'client_secret=' + settings.Client_Secret__c
            ,'redirect_uri=' + settings.Redirect_URI__c
            ,'display=mobile'
            ,'state='+environment
            ,'response_type=code'
        };
        request.setBody(String.join(requestParameters,'&'));

        System.debug('request body: ' +  request.getBody());

        OAuth2LoginResponse result = new OAuth2LoginResponse();
        try {
	        Http http = new Http();
    	    HttpResponse response = http.send(request);
            Integer statusCode = response.getStatusCode();
            String responseBody = response.getBody();
            String locationHeader = response.getHeader('Location');

            System.debug('responseBody: ' + responseBody);
            System.debug('Header Location: ' + locationHeader);

            if(statusCode >= 300 && statusCode <= 307){
                //Redirect.
                System.debug('Redirect detected.');
                result.url = locationHeader;
                result.isSuccessful = true;
                return result;
            }

            //result = (OAuth2LoginResponse)JSON.deserialize(response.getBody(),OAuth2LoginResponse.class);
            result.isSuccessful = true;
            Integer startIndex = responseBody.indexOf('window.location.replace(') + 25;
            Integer endIndex = responseBody.indexOf(');',startIndex)-1;
            result.url = responseBody.substring(startIndex,endIndex);
            System.debug('result url: ' + result.url);
        } catch (System.CalloutException e) {
            System.debug(e.getMessage());
            result.isSuccessful = false;
            result.responseMessage = e.getMessage();
            result.responseStackTrace = e.getStackTraceString();
        }
        return result;
    }

    @AuraEnabled
    public static String loginUsernamePasswordFlow(Id recordId){
        
        Account_Org__c ao = [Select Id,Environment__c,Name,URL__c,Username__c,Tokenized_Password__c,Password__c,Security_Token__c,Client_Secret__c,Consumer_Key__c From Account_Org__c Where Id = :recordId];

        if(String.isEmpty(ao.Environment__c)){
            return JSON.serialize(new RESTREquestUtil());
        }
        
        Healthcheck_oAuth_Settings__c settings = Healthcheck_oAuth_Settings__c.getValues(ao.Environment__c);
        
        OAuthUsernamePasswordFlow reqBody = new OAuthUsernamePasswordFlow(ao,settings);

        RESTRequestUtil rr = null;

        Httprequest request = new HttpRequest();
        request.setMethod('POST');
        request.setHeader('Content-Type','application/x-www-form-urlencoded');
        request.setEndpoint(ao.URL__c + '/services/oauth2/token');
        request.setBody(reqBody.getRequestString());

        OAuth2LoginResponse result = new OAuth2LoginResponse();
        try {
            Http http = new Http();
            System.debug('Request body: ' + request.getBody());
            System.debug('Request URL: ' + request.getEndpoint());

            HttpResponse response = http.send(request);
            Integer statusCode = response.getStatusCode();
            String responseBody = response.getBody();
            System.debug('responseBody: ' + responseBody);

            result = (OAuth2LoginResponse)JSON.deserialize(responseBody,OAuth2LoginResponse.class);
            rr = new RESTRequestUtil();
            //rr = new RESTRequest(ao);
            rr.ao = ao;
            rr.settings = settings;

            

            rr.url = result.instance_url;
            rr.accessToken = result.access_token;

            String apiVersion = getAPIVersion(rr);
            rr.apiVersion = apiVersion;
            rr.isSuccessful = true;
            
            RESTRequestUtil.IdentityResponse ir = getIdentity(rr,result.id);
            rr.identityResponse = ir;
            
           	OrganizationWrapper ow = getOrganization(rr);
            rr.organizationType = ow.organizationType;
            rr.organizationName = ow.Name;
        } catch (Exception e) {
            System.debug('An exception occurred: ' + e.getMessage());
            System.debug('Exception stack trace: ' + e.getStackTraceString());
            rr = new RESTRequestUtil(e);
        }
        return JSON.serialize(rr);
    }
    
    @future
    public static void updateLead(String newLead){
        update (Lead)JSON.deserialize(newLead,Lead.class);
    }
    
    public class OrganizationWrapper{
        @AuraEnabled
        public String OrganizationType {get;set;}
        @AuraEnabled
        public String Name {get;set;}
    }
    
    public class OrganizationResponse{
        @AuraEnabled
        public List<OrganizationWrapper> records {get;set;}
    }

	public class OAuth2LoginResponse{
        @AuraEnabled
        public String url {get;set;}
        @AuraEnabled
        public boolean isSuccessful {get; set;}
        @AuraEnabled
        public String responseMessage  {get; set;}
        @AuraEnabled
        public String responseStackTrace {get; set;}
        @AuraEnabled
        public String access_token {get;set;}
        @AuraEnabled
        public String instance_url {get;set;}
        @AuraEnabled
        public String id {get;set;}

        public String refresh_token {get; set;}
	}

    public class OAuthUsernamePasswordFlow{
        public String grant_type {get;set;}
        public String client_id {get;set;}
        public String client_secret {get;set;}
        public String password {get;set;}
        public String username {get;set;}

        public OAuthUsernamePasswordFlow(Account_Org__c ao,Healthcheck_oAuth_Settings__c settings){
            this.grant_type = 'password';
            this.client_id =  settings.Client_Id__c;
            this.client_secret = settings.Client_Secret__c;
            this.password = ao.Tokenized_Password__c;
            this.username = ao.Username__c;
        }

        public String getRequestString(){
            return 'grant_type='+grant_type+'&client_id='+client_id+'&client_secret='+client_secret+'&username='+username+'&password='+password;
        }
    }
}