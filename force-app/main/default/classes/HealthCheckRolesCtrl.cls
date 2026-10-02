public class HealthCheckRolesCtrl {
 	@AuraEnabled
    public static UserRoleResponse getUserRoles(String restRequestJson){
        RESTRequestUtil rr = (RESTRequestUtil)JSON.deserialize(restRequestJson,RESTRequestUtil.class);
        String queryString = '/services/data/v' + rr.apiVersion + '/query?q=Select+Id,ParentRoleId,Name+From+UserRole';
        String responseString = rr.requestProxy(null,'GET',queryString);
        UserRoleResponse urr = (UserRoleResponse)JSON.deserialize(responseString,UserRoleResponse.class);
        
        queryString = '/services/data/v' + rr.apiVersion + '/query?q=Select+UserRoleId,count(Id)+roleCount+From+User+Where+UserRoleId+!=+null+Group+By+UserRoleId';
		responseString = rr.requestProxy(null,'GET',queryString);
        UserResponse ur = (UserResponse)JSON.deserialize(responseString,UserResponse.class);
        
        Map<Id,UserRoleWrapper> roleWrapperMap = new Map<Id,UserRoleWrapper>();
        for(UserRoleWrapper urw : urr.records){
            urw.childrenCount = 0;
            urw.hierarchyCount = 0;
            roleWrapperMap.put(urw.Id,urw);
            urw.childrenRoles = new Set<Id>();
        }
        
        for(UserRoleWrapper urw : urr.records){
            
            for(UserWrapper uw : ur.records){
                if(urw.Id == uw.UserRoleId){
                    urw.childrenCount = uw.roleCount;
                }
            }
            
            Id parentId = urw.ParentRoleId;
            while(parentId != null){
                UserRoleWrapper parent = roleWrapperMap.get(parentId);
                if(parent != null){
                	parent.hierarchyCount += urw.childrenCount;
                	parent.childrenRoles.add(urw.Id);
                	parentId = parent.ParentRoleId;
                }
            }
        }
        
        for(UserRoleWrapper urw : urr.records){
            urw.childrenRoleCount = urw.childrenRoles.size();
            urw.hierarchyCount = urw.childrenCount + urw.hierarchyCount;
        }
        
        urr.records.sort();
        
        if(!urr.records.isEmpty() && rr.newLead != null){
        	rr.newLead.Health_Check_Role_Hierarchy_Depth__c = urr.records.get(0).childrenRoleCount;
            urr.newLead = JSON.serialize(rr.newLead);
        }
        
        return urr;
    }
    
    @AuraEnabled
    public static void updateLead(String newLead){
    	if(!String.isEmpty(newLead)){
        	update (Lead)JSON.deserialize(newLead,Lead.class);
        }
    }
    
    public class UserResponse{
        @AuraEnabled
        public List<UserWrapper> records {get;set;}
    }
    
    public class UserWrapper{
        @AuraEnabled
        public Id UserRoleId {get;set;}
        @AuraEnabled
        public Integer roleCount {get;set;}
    }
   		
    public class UserRoleResponse{
        @AuraEnabled
        public String newLead {get;set;}
        @AuraEnabled
        public List<UserRoleWrapper> records {get;set;}
    }
    
    public class UserRoleWrapper implements Comparable{
        @AuraEnabled
        public Id Id {get;set;}
        @AuraEnabled
        public Id ParentRoleId {get;set;}
        @AuraEnabled
        public String Name {get;set;}
        @AuraEnabled
        public Integer childrenCount {get;set;}
        @AuraEnabled
        public Integer hierarchyCount {get;set;}
        @AuraEnabled
        public Integer childrenRoleCount {get;set;}
        
        public Set<Id> childrenRoles {get; set;}
        
        public Integer compareTo(Object compareTo) {
            UserRoleWrapper compareToWrapper = (UserRoleWrapper)compareTo;
            
            if(childrenRoleCount > compareToWRapper.childrenRoleCount){
                return -1;
            }else if(childrenRoleCount < compareToWRapper.childrenRoleCount){
                return 1;
            }else{
                return 0;
            }
        }
    }
}