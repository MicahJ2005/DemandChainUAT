public class HealthCheckLimitsCtrl {
	@AuraEnabled
	public static LimitReport getLimitReport(String restRequestJson){
        RESTRequestUtil rest = (RESTRequestUtil)JSON.deserialize(restRequestJson,RESTRequestUtil.class);
        String queryString = '/services/data/v' + rest.apiVersion + '/limits';
		String response = rest.requestProxy(null,'GET',queryString);
		LimitResponse lresp = (LimitResponse)JSON.deserialize(response,LimitResponse.class);

		LimitReport lr = new LimitReport();
		lr.totalDataSize = lresp.DataStorageMB.Max;
		lr.remainingDataSize = lresp.DataStorageMB.Remaining;
		lr.percentDataSizeRemaining = Integer.valueOf(Math.floor(100 * (Decimal.valueOf(lr.remainingDataSize) / Decimal.valueOf(lr.totalDataSize))));
		lr.totalFileSize = lresp.FileStorageMB.Max;
		lr.remainingFileSize = lresp.FileStorageMB.Remaining;
		lr.percentFileSizeRemaining = Integer.valueOf(Math.floor(100 * (Decimal.valueOf(lr.remainingFileSize) / Decimal.valueOf(lr.totalFileSize))));
		lr.totalApiRequests = lresp.DailyAPIRequests.Max;
		lr.remainingApiRequests = lresp.DailyAPIRequests.Remaining;
		lr.percentApiRequestsRemaining = Integer.valueOf(Math.floor(100 * (Decimal.valueOf(lr.remainingApiRequests) / Decimal.valueOf(lr.totalApiRequests))));
		
        if(rest.newLead != null){
            rest.newLead.Health_Check_Total_Data_Size__c = lr.totalDataSize;
            rest.newLead.Health_Check_Remaining_Data_Size__c = lr.remainingDataSize;
            rest.newLead.Health_Check_Remaining_File_Size__c = lr.remainingFileSize;
            rest.newLead.Health_Check_Total_File_Size__c = lr.totalFileSize;
            rest.newLead.Health_Check_Remaining_API_Requests__c = lr.remainingAPIRequests;
            rest.newLead.Health_Check_Total_API_Requests__c = lr.totalApiRequests;
            lr.newLead = JSON.serialize(rest.newLead);
            //HealthCheckHeaderCtrl.updateLead(JSON.serialize(rest.newLead));//update rest.newLead;
        }
        return lr;
	}
    
    @AuraEnabled
    public static void updateLead(String newLead){
        if(!String.isEmpty(newLead)){
        	update (Lead)JSON.deserialize(newLead,Lead.class);
        }
    }

    public class LimitWrapper{
		public Integer Max {get; set;}
		public Integer Remaining {get; set;}
	}

    public class LimitResponse{
		//public LimitWrapper LimitWrapper {get; set;}
		public LimitWrapper ConcurrentSyncReportRuns {get; set;}
		public LimitWrapper DailyApiRequests {get; set;}
		public LimitWrapper DailyAsyncApexExecutions {get; set;}
		public LimitWrapper DailyBulkApiRequests {get; set;}
		public LimitWrapper DailyDurableGenericStreamingApiEvents {get; set;}
		public LimitWrapper DailyGenericStreamingApiEvents {get; set;}
		public LimitWrapper DailyStreamingApiEvents {get; set;}
		public LimitWrapper DailyWorkflowEmails {get; set;}
		public LimitWrapper DataStorageMB {get; set;}
		public LimitWrapper DurableStreamingApiConcurrentClients {get; set;}
		public LimitWrapper FileStorageMB {get; set;}
		public LimitWrapper HourlyAsyncReportRuns {get; set;}
		public LimitWrapper HourlyDashboardRefreshes {get; set;}
		public LimitWrapper HourlyDashboardResults {get; set;}
		public LimitWrapper HourlyDashboardStatuses {get; set;}
		public LimitWrapper HourlySyncReportRuns {get; set;}
		public LimitWrapper HourlyTimeBasedWorkflow {get; set;}
		public LimitWrapper MassEmail {get; set;}
		public LimitWrapper SingleEmail {get; set;}
		public LimitWrapper StreamingApiConcurrentClients {get; set;}
	}

    public class LimitReport{
        @AuraEnabled
        public String newLead {get;set;}
		@AuraEnabled
		public Integer totalDataSize {get;set;}
		@AuraEnabled
		public Integer remainingDataSize {get;set;}
		@AuraEnabled
		public Integer percentDataSizeRemaining {get;set;}
		@AuraEnabled
		public Integer totalFileSize {get;set;}
		@AuraEnabled
		public Integer remainingFileSize {get;set;}
		@AuraEnabled
		public Integer percentFileSizeRemaining {get;set;}
		@AuraEnabled
		public Integer totalApiRequests {get;set;}
		@AuraEnabled
		public Integer remainingApiRequests {get; set;}
		@AuraEnabled
		public Integer percentApiRequestsRemaining {get; set;}
	}
}