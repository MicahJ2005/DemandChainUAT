public class HealthCheckMetricsCtrl {

    @AuraEnabled
    public static MetricsWrapper getMetrics(String restRequestJson){
        MetricsWrapper mw = new MetricsWrapper();

        RESTRequestUtil rr = (RESTRequestUtil)JSON.deserialize(restRequestJson,RESTRequestUtil.class);

        //Grabbing managed package class.
    	String queryString = '/services/data/v' + rr.apiVersion + '/query?q=Select+count()+From+ApexClass+Where+NamespacePrefix+!=+null';
        String responseString = rr.requestProxy(null,'GET',queryString);
        QueryResponse qr = (QueryResponse)JSON.deserialize(responseString,QueryResponse.class);
        mw.managedClasses = qr.totalSize;

        //Grabbing unmanaged apex class count.
        queryString = '/services/data/v' + rr.apiVersion + '/query?q=Select+count()+From+ApexClass';
        responseString = rr.requestProxy(null,'GET',queryString);
        qr = (QueryResponse)JSON.deserialize(responseString,QueryResponse.class);
        mw.classes = qr.totalSize;

        //Grabbing permission set count.
        queryString = '/services/data/v' + rr.apiVersion + '/query?q=Select+count()+From+PermissionSet+Where+Not+Name+Like+%27X00%25%27';
        responseString = rr.requestProxy(null,'GET',queryString);
        qr = (QueryResponse)JSON.deserialize(responseString,QueryResponse.class);
        mw.permissionSets= qr.totalSize;

        queryString = '/services/data/v' + rr.apiVersion + '/query?q=Select+count()+From+Profile';
        responseString = rr.requestProxy(null,'GET',queryString);
        qr = (QueryResponse)JSON.deserialize(responseString,QueryResponse.class);
        mw.profiles = qr.totalSize;

        queryString = '/services/data/v' + rr.apiVersion + '/query?q=Select+count()+From+UserRole';
        responseString = rr.requestProxy(null,'GET',queryString);
        qr = (QueryResponse)JSON.deserialize(responseString,QueryResponse.class);
        mw.roles = qr.totalSize;

        queryString = '/services/data/v' + rr.apiVersion + '/sobjects';
        responseString = rr.requestProxy(null,'GET',queryString);
        DescribeResponse dr = (DescribeResponse)JSON.deserialize(responseString,DescribeResponse.class);
        
        queryString = '/services/data/v' + rr.apiVersion + '/query?q=Select+count()+From+ApexPage+Where+NamespacePrefix=null';
        responseString = rr.requestProxy(null,'GET',queryString);
        qr = (QueryResponse)JSON.deserialize(responseString,QueryResponse.class);
        mw.pages = qr.totalSize;
        
        queryString = '/services/data/v' + rr.apiVersion + '/query?q=Select+count()+From+ApexTrigger+Where+NamespacePrefix=null';
        responseString = rr.requestProxy(null,'GET',queryString);
        qr = (QueryResponse)JSON.deserialize(responseString,QueryResponse.class);
        mw.triggers = qr.totalSize;

        mw.customObjects = 0;
        mw.managedCustomObjects = 0;
        for(CustomObjectWrapper cow : dr.sobjects){
            //Could be a sharing rule if it's custom and does NOT end with __c.
            if(cow.name.endsWith('__c')){
                if(cow.name.countMatches('__') == 2){
                	mw.managedCustomObjects++;
                }
                mw.customObjects++;
            }
        }
        
        if(rr.newLead != null){
            rr.newLead.Health_Check_Number_of_Profiles__c = mw.profiles;
            rr.newLead.Health_Check_Number_of_Roles__c = mw.roles;
            rr.newLead.Health_Check_Number_of_Apex_Classes__c = mw.classes;
            rr.newLead.Health_Check_Number_of_Managed_Classes__c = mw.managedClasses;
            rr.newLead.Health_Check_Number_of_Permission_Sets__c = mw.permissionSets;
            rr.newLead.Health_Check_Number_of_Custom_Objects__c = mw.customObjects;
            rr.newLead.Health_Check_Number_of_Managed_Objects__c = mw.managedCustomObjects;
            rr.newLead.Health_Check_Number_of_Triggers__c = mw.triggers;
            rr.newLead.Health_Check_Number_of_Pages__c = mw.pages;
            mw.newLead = JSON.serialize(rr.newLead);
        }
        
        return mw;
    }
    
    @AuraEnabled
    public static void updateLead(String newLead){
        if(!String.isEmpty(newLead)){
        	update (Lead)JSON.deserialize(newLead,Lead.class);
        }
    }

    public class MetricsWrapper{
        @AuraEnabled
        public Integer classes {get;set;}
        @AuraEnabled
        public Integer managedClasses {get; set;}
        @AuraEnabled
        public Integer profiles {get;set;}
        @AuraEnabled
        public Integer permissionSets {get; set;}
        @AuraEnabled
        public Integer customObjects {get; set;}
        @AuraEnabled
        public Integer managedCustomObjects {get; set;}
        @AuraEnabled
        public Integer roles {get; set;}
        @AuraEnabled
        public Integer pages {get;set;}
        @AuraEnabled
        public Integer triggers {get;set;}
        @AuraEnabled
        public String newLead {get;set;}
    }

    public class DescribeResponse{
        public List<CustomObjectWrapper> sobjects {get;set;}
    }

    public class CustomObjectWrapper{
        public boolean custom {get;set;}
        public String name {get;set;}
    }

    public class QueryResponse{
        public Integer totalSize {get;set;}
    }
}