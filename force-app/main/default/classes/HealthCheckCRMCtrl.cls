public class HealthCheckCRMCtrl {

    @AuraEnabled
    public static CRMWrapper getCRM(String restRequestJson){
        CRMWrapper crmw = new CRMWrapper();
        crmw.displayOpportunities = false;

        RESTRequestUtil rr = (RESTRequestUtil)JSON.deserialize(restRequestJson,RESTRequestUtil.class);

        //Grabbing managed package class.
    	String queryString = '/services/data/v' + rr.apiVersion + '/query?q=Select+count()+From+Account';
        String responseString = rr.requestProxy(null,'GET',queryString);
        QueryResponse qr = (QueryResponse)JSON.deserialize(responseString,QueryResponse.class);
        crmw.accounts = qr.totalSize;

        //Grabbing managed package class.
    	queryString = '/services/data/v' + rr.apiVersion + '/query?q=Select+count()+From+Contact';
        responseString = rr.requestProxy(null,'GET',queryString);
        qr = (QueryResponse)JSON.deserialize(responseString,QueryResponse.class);
        crmw.contacts = qr.totalSize;

        //Grabbing managed package class.
    	queryString = '/services/data/v' + rr.apiVersion + '/query?q=Select+count()+From+Lead';
        responseString = rr.requestProxy(null,'GET',queryString);
        qr = (QueryResponse)JSON.deserialize(responseString,QueryResponse.class);
        crmw.leads = qr.totalSize;

        try{
            queryString = '/services/data/v' + rr.apiVersion + '/query?q=Select+count()+From+Opportunity';
        	responseString = rr.requestProxy(null,'GET',queryString);
        	qr = (QueryResponse)JSON.deserialize(responseString,QueryResponse.class);
        	crmw.opportunities = qr.totalSize;
            crmw.displayOpportunities = true;
        }catch(Exception e){
        	crmw.displayOpportunities = false;
        }
        
        try{
            queryString = '/services/data/v' + rr.apiVersion + '/query?q=Select+count()+From+Campaign';
        	responseString = rr.requestProxy(null,'GET',queryString);
        	qr = (QueryResponse)JSON.deserialize(responseString,QueryResponse.class);
        	crmw.campaigns = qr.totalSize;
            crmw.displayCampaigns = true;
        }catch(Exception e){
        	crmw.displayCampaigns = false;
        }
        
        try{
            queryString = '/services/data/v' + rr.apiVersion + '/query?q=Select+count()+From+Product2';
        	responseString = rr.requestProxy(null,'GET',queryString);
        	qr = (QueryResponse)JSON.deserialize(responseString,QueryResponse.class);
        	crmw.products = qr.totalSize;
            crmw.displayProducts = true;
        }catch(Exception e){
        	crmw.displayProducts = false;
        }
        
        try{
            queryString = '/services/data/v' + rr.apiVersion + '/query?q=Select+count()+From+Case';
        	responseString = rr.requestProxy(null,'GET',queryString);
        	qr = (QueryResponse)JSON.deserialize(responseString,QueryResponse.class);
        	crmw.cases = qr.totalSize;
            crmw.displayCases = true;
        }catch(Exception e){
        	crmw.displayCases = false;
        }
        
        return crmw;
    }

    public class CRMWrapper{
        @AuraEnabled
        public Integer accounts {get;set;}
		@AuraEnabled
        public Integer contacts {get;set;}
        @AuraEnabled
        public Integer leads {get;set;}
        @AuraEnabled
        public Integer opportunities {get;set;}
        @AuraEnabled
        public Integer campaigns {get;set;}
        @AuraEnabled
        public Integer cases {get;set;}
        @AuraEnabled
        public Integer products {get;set;}
        @AuraEnabled
        public boolean displayOpportunities{get;set;}
        @AuraEnabled
        public boolean displayCampaigns{get;set;}
        @AuraEnabled
        public boolean displayCases{get;set;}
        @AuraEnabled
        public boolean displayProducts{get;set;}
    }

    public class QueryResponse{
        public Integer totalSize {get;set;}
    }
}