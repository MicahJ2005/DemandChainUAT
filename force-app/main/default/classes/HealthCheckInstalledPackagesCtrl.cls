public class HealthCheckInstalledPackagesCtrl {
	@AuraEnabled
	public static InstalledPackagesWrapper getInstalledPackages(String restRequestJson){
        InstalledPackagesWrapper ans = new InstalledPackagesWrapper();
        
		RESTRequestUtil rr = (RESTRequestUtil)JSON.deserialize(restRequestJson,RESTRequestUtil.class);

        MetadataService.MetadataPort port = new MetadataService.MetadataPort();
        ToolingAPIWSDL.SforceService toolingService = new ToolingAPIWSDL.SforceService();
        MetadataService.SessionHeader_element sessionHeader = new MetadataService.SessionHeader_element();
        sessionHeader.sessionId = rr.accessToken;
        port.SessionHeader = sessionHeader;

        Map<String,String> headers = port.inputHttpHeaders_x;
        if(headers == null){
            headers = new Map<String,String>();
            port.inputHttpHeaders_x = headers;
        }
        headers.put('SalesforceURL',rr.url + '/services/Soap/m/37.0');
        port.endpoint_x = rr.settings.Proxy_URL__c;
        //port.endpoint_x = rr.url + '/services/Soap/m/37.0';

        List<MetadataService.ListMetadataQuery> lmql = new List<MetadataService.ListMetaDataQuery>();
        MetadataService.ListMetaDataQuery lmq = new MetadataService.ListMetaDataQuery();
        lmq.type_x = 'InstalledPackage';
        lmql.add(lmq);
        Set<String> packages = new Set<String>();
        for(MetadataService.FileProperties fp : port.listMetadata(lmql,37)){
            packages.add(fp.fullName);
        }
        
        if(rr.newLead != null){
        	rr.newLead.Health_Check_Number_Of_Packages__c = packages.size();
            ans.newLead = JSON.serialize(rr.newLead);
        }
        
        ans.records = new List<String>(packages);
        
        return ans;
	}
    
    @AuraEnabled
    public static void updateLead(String newLead){
        if(!String.isEmpty(newLead)){
        	update (Lead)JSON.deserialize(newLead,Lead.class);
        }
    }
    
    public class InstalledPackagesWrapper{
        @AuraEnabled
        public String newLead {get;set;}
        @AuraEnabled
        public List<String> records {get;set;}
    }
}