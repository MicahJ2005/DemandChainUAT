public class HealthCheckProfilesCtrl {
	
    @AuraEnabled
    public static List<PermissionSetWrapper> getProfiles(String restRequestJson){
        RESTRequestUtil rr = (RESTRequestUtil)JSON.deserialize(restRequestJson,RESTRequestUtil.class);
        String queryString = '/services/data/v' + rr.apiVersion + '/query?q=Select+PermissionsModifyAllData,PermissionsViewAllData,ProfileId,Profile.Name+FROM+PermissionSet+WHERE+ProfileId+!=+null';
        String responseString = rr.requestProxy(null,'GET',queryString);
        PermissionSetResponse psr = (PermissionSetResponse)JSON.deserialize(responseString,PermissionSetResponse.class);
        psr.records.sort();
        
        UserCountResponse ucr = getUserCountResponse(restRequestJson);
        for(PermissionSetWrapper psw : psr.records){
            psw.userCount = 0;
            for(UserCountRecord ucrr : ucr.records){
                if(psw.ProfileId == ucrr.ProfileId){
                    psw.userCount = ucrr.userCount;
                }
            }
        }
        return psr.records;
    }
    
    private static UserCountResponse getUserCountResponse(String restRequestJson){
        RESTRequestUtil rr = (RESTRequestUtil)JSON.deserialize(restRequestJson,RESTRequestUtil.class);
        String queryString = '/services/data/v' + rr.apiVersion + '/query?q=select+profileid,count(id)+userCount+from+user+where+IsActive=true+group+by+profileid';
        String responseString = rr.requestProxy(null,'GET',queryString);
        return (UserCountResponse)JSON.deserialize(responseString,UserCountResponse.class);
    }
    
    public class PermissionSetResponse{
        public List<PermissionSetWrapper> records {get; set;}
    }
    
    public class UserCountResponse{
        public List<UserCountRecord> records {get;set;}
    }
    
    public class UserCountRecord{
        public Integer userCount {get;set;}
        public Id ProfileId {get;set;}
    }
    
    public class PermissionSetWrapper implements Comparable{
        @AuraEnabled
        public boolean PermissionsModifyAllData {get;set;}
        @AuraEnabled
        public boolean PermissionsViewAllData {get;set;}
        @AuraEnabled
        public ProfileWrapper Profile {get;set;}
        @AuraEnabled
        public Id ProfileId {get;set;}
		@AuraEnabled
        public Integer userCount {get;set;}
        
        public Integer compareTo(Object compareTo) {
            PermissionSetWrapper compareToPSW= (PermissionSetWrapper)compareTo;
            if (PermissionsModifyAllData && !compareToPSW.PermissionsModifyAllData){
                return -1;
            }

            if (!PermissionsModifyAllData && compareToPSW.PermissionsModifyAllData){
                return 1;
            }

            if (PermissionsViewAllData && !compareToPSW.PermissionsViewAllData){
                return -1;
            }

            if (!PermissionsViewAllData && compareToPSW.PermissionsViewAllData){
                return 1;
            }

            if(Profile.Name > compareToPSW.Profile.Name) return 1;
            if(Profile.Name == compareToPSW.Profile.Name) return 0;
            return -1;
    	}
    }
    
    public class ProfileWrapper{
        @AuraEnabled
        public String Name {get;set;}
    }
}