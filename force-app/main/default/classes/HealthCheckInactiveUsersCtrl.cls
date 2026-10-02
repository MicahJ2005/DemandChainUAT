public class HealthCheckInactiveUsersCtrl {
	@AuraEnabled
    public static InactiveUsersWrapper getInactiveUsers(String restRequestJson){
        RESTRequestUtil rr = (RESTRequestUtil)JSON.deserialize(restRequestJson,RESTRequestUtil.class);
        String queryString = '/services/data/v' + rr.apiVersion + '/query?q=Select+count(Id)+inactiveCount+From+User+Where+LastLoginDate+%3C+LAST_N_DAYS:7+And+IsActive=true';
        String responseString = rr.requestProxy(null,'GET',queryString);
        System.debug('JWL: responseString: ' + responseString);
        UserResponse ur = (UserResponse)JSON.deserialize(responseString,UserResponse.class);
        
        InactiveUsersWrapper wrapper = new InactiveUsersWrapper();
        wrapper.recordCount = ur.records.get(0).inactiveCount;
        if(rr.newLead != null){
        	rr.newLead.Health_Check_Users_No_Logins_7_Days__c = ur.records.get(0).inactiveCount;
            wrapper.newLead = JSON.serialize(rr.newLead);
        }
        
        return wrapper;
    }
    
    @AuraEnabled
    public static void updateLead(String newLead){
        if(!String.isEmpty(newLead)){
        	update (Lead)JSON.deserialize(newLead,Lead.class);
        }
    }
    
    public class InactiveUsersWrapper{
        @AuraEnabled
        public Integer recordCount {get;set;}
        @AuraEnabled
        public String newLead {get;set;}
    }
    
    public class UserResponse{
        public List<UserWrapper> records {get;set;}
    }
    
    public class UserWrapper{
        public Integer inactiveCount {get;set;}
    }
}