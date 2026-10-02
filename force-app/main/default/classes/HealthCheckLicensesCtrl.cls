public class HealthCheckLicensesCtrl {
    
    public static Set<String> portalLoginLicenses = new Set<String>{
        'PID_Customer_Community_Login'
        ,'PID_Partner_Community_Login'
        ,'PID_Customer_Community_Plus_Login'
    };
    
    public static Set<String> portalLicenses = new Set<String>{
        'PID_Customer_Portal_Basic'
        ,'PID_Customer_Portal_Standard'
        ,'High Volume Customer Portal_User'
        ,'PID_Customer_Community'
        ,'PID_Partner_Community'
        ,'PID_Limited_Customer_Portal_Basic'
        ,'PID_Limited_Customer_Portal_Standard'
        ,'PID_Overage_Customer_Portal_Basic'
        ,'PID_Overage_High Volume Customer Portal'
        ,'POWER_SSP'
        ,'PID_Customer_Community_Plus'
        ,'PID_Partner_Community_Plus'
    };
    
    @AuraEnabled
    public static UserLicenseResponse getUserLicenses(String restRequestJson){
        RESTRequestUtil rr = (RESTRequestUtil)JSON.deserialize(restRequestJson,RESTRequestUtil.class);
        String queryString = '/services/data/v' + rr.apiVersion + '/query?q=Select+Id,Name,LicenseDefinitionKey+From+UserLicense';
        String responseString = rr.requestProxy(null,'GET',queryString);
        UserLicenseResponse ulResponse = (UserLicenseResponse)JSON.deserialize(responseString,UserLicenseResponse.class);

        queryString = '/services/data/v37.0/query?q=Select+permissionset.userlicenseid,count(Id)+numLicenses+from+permissionsetassignment+where+permissionset.profileid+!=+null+group+by+permissionset.userlicenseid';
        responseString = rr.requestProxy(null,'GET',queryString);
        UserLicenseCountResponse ulCountResponse = (UserLicenseCountResponse)JSON.deserialize(responseString,UserLicenseCountResponse.class);

        Integer numCommunityLicenses = 0;
        Integer numCommunityLoginLicenses = 0;
        
        List<UserLicenseWrapper> ans = new List<UserLicenseWrapper>();
        for(UserLicenseWrapper ulw : ulResponse.records){
            ulw.numLicenses = 0;
            
            for(UserLicenseCountWrapper ulcw : ulCountResponse.records){
                if(ulw.Id == ulcw.UserLicenseId){
                    ulw.numLicenses = ulcw.numLicenses;
                    
                    System.debug('JWL: LicenseDefinitionKey: ' + ulw.LicenseDefinitionKey);
                    
                    if(portalLoginLicenses.contains(ulw.LicenseDefinitionKey)){
                		numCommunityLoginLicenses += ulw.numLicenses;
                        System.debug('JWL: numCommunityLoginLicenses: ' + numCommunityLoginLicenses);
            		}
                    
                    if(portalLicenses.contains(ulw.LicenseDefinitionKey)){
                		numCommunityLicenses += ulw.numLicenses;
                        System.debug('JWL: numCommunityLicenses: ' + numCommunityLicenses);
            		}
                }
            }
            ans.add(ulw);
        }
        ans.sort();
        
        UserLicenseResponse resp = new UserLicenseResponse();
        resp.records = ans;
        
        System.debug('JWL: numCommunityLoginLicenses: ' + numCommunityLoginLicenses);
         System.debug('JWL: numCommunityLicenses: ' + numCommunityLicenses);
        System.debug('JWL: newLead: ' + rr.newLead);
        if(rr.newLead != null){
            rr.newLead.Health_Check_Community_Licenses_Used__c = numCommunityLicenses;
            rr.newLead.Health_Check_Comm_Login_Licenses_Used__c = numCommunityLoginLicenses;
            resp.newLead = JSON.serialize(rr.newLead);
        }
        System.debug('JWL: newLead after: ' + resp.newLead);
        return resp;
    }
    
    @AuraEnabled
    public static void updateLead(String newLead){
        if(!String.isEmpty(newLead)){
        	update (Lead)JSON.deserialize(newLead,Lead.class);
        }
    }

    public class UserLicenseCountResponse{
        public List<UserLicenseCountWrapper> records {get;set;}
    }

    public class UserLicenseCountWrapper{
        public Integer numLicenses {get;set;}
        public String UserLicenseId {get;set;}
    }

    public class UserLicenseWrapper implements Comparable{
        @AuraEnabled
        public String Id {get;set;}
		@AuraEnabled
        public String Name {get;set;}
        @AuraEnabled
        public String LicenseDefinitionKey {get; set;}
        @AuraEnabled
        public Integer numLicenses {get; set;}

        public Integer compareTo(Object compareTo) {
            UserLicenseWrapper compareToUL= (UserLicenseWrapper)compareTo;
            if (numLicenses == compareToUL.numLicenses){
                if(Name == compareToUL.Name) return 0;
                if(Name > compareToUL.Name) return 1;
                return -1;
            }
            if (numLicenses < compareToUL.numLicenses) return 1;
            return -1;
    	}
    }

    public class UserLicenseResponse{
        @AuraEnabled
        public String newLead {get;set;}
        @AuraEnabled
        public List<UserLicenseWrapper> records {get; set;}
    }
}