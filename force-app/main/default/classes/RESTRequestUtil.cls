/**b
 * RESTRequestUtil
 * @description Provides mechanism for issuing RESTful request to an external Salesforce organization.
 * Borrowing from Mohit's example here: http://salesforce.stackexchange.com/questions/25021/how-can-i-integrate-one-sfdc-org-to-another-sfdc-using-rest-api
 * @author  James Loghry
 * @date  4/13/2016
 */
public with sharing class RESTRequestUtil{

	public String url {get; set;}
    public String accessToken {get; set;}
	public Account_Org__c ao {get; set;}
    public String apiVersion {get; set;}
    public Healthcheck_oAuth_Settings__c settings {get;set;}
    public boolean isSuccessful {get;set;}
    public String errorMessage {get;set;}
    public String errorStackTrace {get;set;}
    public IdentityResponse identityResponse {get;set;}
    public String organizationType {get; set;}
    public String organizationName {get; set;}
    public Lead newLead {get; set;}

	public RESTRequestUtil(Account_Org__c ao){
		this.url = ao.URL__c;
		this.ao = ao;

		if(ao != null && !String.isEmpty(ao.Environment__c)){
			Healthcheck_oAuth_Settings__c settings = Healthcheck_oAuth_Settings__c.getValues(ao.Environment__c);
	        this.settings = settings;
		}

		authorize();
	}

	public RESTREquestUtil(Exception e){
		this.errorMessage = e.getMessage();
		this.errorStackTrace = e.getStackTraceString();
		this.isSuccessful = false;
		System.debug('Constructing new RESTRequestUtil with error: ' + this.errorMessage);
		System.debug('RESTRequest error occurred at: ' + this.errorStackTrace);
	}

	public RESTRequestUtil(){}

	public String request(String body,String method,String uri){
		HttpResponse resp = sendRequest(body,method,uri,true);
		return resp.getBody();
	}

    public String requestProxy(String body,String method,String uri){
		HttpResponse resp = sendRequestProxy(body,method,uri,true);
		return resp.getBody();
	}

	public void authorize(){
		String requestString =
				'grant_type=password&client_id='
				+ this.ao.Consumer_Key__c
				+ '&client_secret='
				+ this.ao.Client_Secret__c +
				+ '&username='
				+ this.ao.Username__c +
				+ '&password='
				+ this.ao.Password__c +
				+ this.ao.Security_Token__c;

		System.debug('Request String: ' + requestString);
		HttpResponse httpResp = sendRequest(
			requestString
			,'POST'
			,'/services/oauth2/token'
			,false
		);
        System.debug('JWL: OAuth2Response: ' + httpResp.getBody());
		OAuth2Response resp = (OAuth2Response)JSON.deserialize(httpResp.getBody(),Oauth2Response.class);


		this.url = resp.instance_url;
		this.accessToken = resp.access_token;
	}

    private HttpResponse sendRequestProxy(String body, String method, String httpQuery, boolean includeContentType){
		Http h = new Http();
		HttpRequest req = new HttpRequest();

		if(includeContentType){
			req.setHeader('Content-Type','application/json');
		}

		if(!String.isEmpty(this.accessToken)){
			req.setHeader('Authorization','Bearer ' + this.accessToken);
		}

        req.setHeader('SalesforceURL',this.url + httpQuery);

        System.debug('JWL: sf url: ' + this.url + httpQuery);
        System.debug('JWL: body: ' + body);
		if(!String.isEmpty(body)){
			req.setBody(body);
		}
		req.setMethod(method);
		//req.setEndpoint(this.url + httpQuery);
		req.setEndpoint(settings.Proxy_URL__c);

        return h.send(req);
	}

	private HttpResponse sendRequest(String body, String method, String httpQuery, boolean includeContentType){
		Http h = new Http();
		HttpRequest req = new HttpRequest();

		if(includeContentType){
			req.setHeader('Content-Type','application/json');
		}

		if(!String.isEmpty(this.accessToken)){
			req.setHeader('Authorization','Bearer ' + this.accessToken);
		}

		if(!String.isEmpty(body)){
			req.setBody(body);
		}
		req.setMethod(method);
		req.setEndpoint(this.url + httpQuery);
		return h.send(req);
	}

	public class OAuth2Response{
		public String id{get;set;}
		public String issued_at{get;set;}
		public String instance_url{get;set;}
		public String signature{get;set;}
		public String access_token{get;set;}
	}
    
    public class IdentityResponse{
        @AuraEnabled
        public String organization_id {get; set;}
        @AuraEnabled
        public String username {get;set;}
        @AuraEnabled 
        public String display_name {get;set;}
        @AuraEnabled
        public PhotoResponse photos {get;set;}
        @AuraEnabled
        public String email {get;set;}
        @AuraEnabled
        public String first_name {get;set;}
        @AuraEnabled
        public String last_name {get;set;}
        @AuraEnabled
        public String mobile_phone {get;set;}
        @AuraEnabled
        public String phone {get;set;}
        
        @AuraEnabled
        public String addr_street {get;set;}
        @AuraEnabled
        public String addr_city {get;set;}
        @AuraEnabled
        public String addr_country {get;set;}
        @AuraEnabled
        public String addr_zip {get;set;}
        @AuraEnabled
        public String addr_state {get;set;}
        
        @AuraEnabled
        public CustomAttributeResponse custom_attributes {get;set;}
    }
    
    public class PhotoResponse{
        @AuraEnabled
        public String picture {get;set;}
        @AuraEnabled
        public String thumbnail {get;set;}
    }
    
    public class CustomAttributeResponse{
        @AuraEnabled
        public String title {get;set;}
    }
}