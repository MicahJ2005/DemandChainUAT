@isTest
public class HealthCheckMockCallout implements HttpCalloutMock {

    public List<Object> typedResponses {get; set;}
    public Integer statusCode {get;set;}
    public String locationHeader {get;set;}
    public Integer exceptionThrownIndex {get;set;}

    public HealthCheckMockCallout(List<Object> typedResponses){
        this.typedResponses = typedResponses;
        this.statusCode = 200;
        this.locationHeader = 'locationHeader';
    }

    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse resp = null;
        if(typedResponses != null && !typedResponses.isEmpty()){
            Object obj = typedResponses.get(0);

            if(0 == exceptionThrownIndex){
                exceptionThrownIndex--;
                typedResponses.remove(0);
                throw new HealthCheckException('TEST');
            }

            resp = new HttpResponse();
            resp.setHeader('Content-Type','application/json');
            resp.setBody(JSON.serialize(obj));
            resp.setStatusCode(statusCode);
            resp.setHeader('Location',locationHeader);

            typedResponses.remove(0);

            if(exceptionThrownIndex != null){
                exceptionThrownIndex--;
            }
        }

        System.debug('JWL: resp: ' + resp);
        return resp;
    }

    public static RESTRequestUtil.Oauth2Response fakeLogin(){
        RESTRequestUtil.OAuth2Response oAuth = new RESTRequestUtil.OAuth2Response();
        oAuth.issued_at = Date.today().format();
        oAuth.instance_url = 'http://url.com';
        oAuth.signature = 'signature';
        oAuth.access_token = '123';
        return oAuth;
    }

    public static RESTRequestUtil getRESTRequest(){
        RESTRequestUtil rr = new RESTRequestUtil(
            new Account_Org__c(
                Consumer_Key__c = 'key'
                ,Client_Secret__c = 'secret'
                ,Username__c = 'username'
                ,Password__c = 'password'
                ,Security_Token__c = 'token'

            )
        );
        rr.newLead = new Lead(
            Firstname='First'
            ,Lastname='Last'
            ,Email='test@test.com'
            ,MobilePhone='111-111-1111'
        	,Company='Company');
        //insert rr.newLead;
        
        rr.url = 'http://url.com';
        rr.accessToken = 'token';
        rr.apiVersion = '37.0';
        rr.settings = new Healthcheck_oAuth_Settings__c(Name='Blah',Proxy_URL__c='http://proxy.com');
        return rr;
    }
}