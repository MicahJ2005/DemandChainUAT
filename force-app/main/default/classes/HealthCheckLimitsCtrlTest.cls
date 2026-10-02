/**
 * Test class for the HealthCheckLimitsCtrl
 * @author  James Loghry
 * @date  8/22/2016
 */
@isTest
private class HealthCheckLimitsCtrlTest {

	static testmethod void testGetLimitReport(){
		HealthCheckLimitsCtrl.LimitWrapper lw = new HealthCheckLimitsCtrl.LimitWrapper();
		lw.Max = 100;
		lw.Remaining = 100;

		HealthCheckLimitsCtrl.LimitResponse lr = new HealthCheckLimitsCtrl.LimitResponse();
		lr.ConcurrentSyncReportRuns = lw;
		lr.DailyApiRequests = lw;
		lr.DailyAsyncApexExecutions= lw;
		lr.DailyBulkApiRequests= lw;
		lr.DailyDurableGenericStreamingApiEvents= lw;
		lr.DailyGenericStreamingApiEvents= lw;
		lr.DailyStreamingApiEvents= lw;
		lr.DailyWorkflowEmails= lw;
		lr.DataStorageMB= lw;
		lr.DurableStreamingApiConcurrentClients= lw;
		lr.FileStorageMB= lw;
		lr.HourlyAsyncReportRuns= lw;
		lr.HourlyDashboardRefreshes= lw;
		lr.HourlyDashboardResults= lw;
		lr.HourlyDashboardStatuses= lw;
		lr.HourlySyncReportRuns= lw;
		lr.HourlyTimeBasedWorkflow= lw;
		lr.MassEmail= lw;
		lr.SingleEmail= lw;
		lr.StreamingApiConcurrentClients= lw;

		//Construct the list of responses the mock callout will "return"
		List<Object> responseObjects = new List<Object>{
			HealthCheckMockCallout.fakeLogin()
			,lr
		};

		//Set the mock callout that will generate fake response for the unit tests.
		HealthCheckMockCallout callout = new HealthCheckMockCallout(responseObjects);
		Test.setMock(HttpCalloutMock.class,callout);

		Test.startTest();
		RESTRequestUtil rr = HealthCheckMockCallout.getRESTRequest();
		String rrString = JSON.serialize(rr);

		HealthCheckLimitsCtrl.LimitReport result = HealthCheckLimitsCtrl.getLimitReport(rrString);
        Lead l = (Lead)JSON.deserialize(result.newLead,Lead.class);
        insert l;
        HealthCheckLimitsCtrl.updateLead(JSON.serialize(l));
		Test.stopTest();

		System.assertEquals(100,result.totalDataSize);
		System.assertEquals(100,result.remainingDataSize);
		System.assertEquals(100,result.percentDataSizeRemaining);
		System.assertEquals(100,result.totalFileSize);
		System.assertEquals(100,result.remainingFileSize);
		System.assertEquals(100,result.percentFileSizeRemaining);
		System.assertEquals(100,result.totalApiRequests);
		System.assertEquals(100,result.remainingApiRequests);
		System.assertEquals(100,result.percentApiRequestsRemaining);
	}
}