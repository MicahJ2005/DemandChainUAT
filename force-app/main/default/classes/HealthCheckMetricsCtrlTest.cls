/**
 * Test class for the HealthCheckMetricsCtrl
 * @author  James Loghry
 * @date  8/22/2016
 */
@isTest
private class HealthCheckMetricsCtrlTest {

	static testmethod void testGetMetrics(){

		HealthCheckMetricsCtrl.QueryResponse qr = new HealthCheckMetricsCtrl.QueryResponse();
		qr.totalSize = 5;

    	HealthCheckMetricsCtrl.CustomObjectWrapper cow = new HealthCheckMetricsCtrl.CustomObjectWrapper();
    	cow.custom = true;
    	cow.name = 'Test__Test__c';

		HealthCheckMetricsCtrl.DescribeResponse dr = new HealthCheckMetricsCtrl.DescribeResponse();
		dr.sobjects = new List<HealthCheckMetricsCtrl.CustomObjectWrapper>();
		dr.sobjects.add(cow);

		//Construct the list of responses the mock callout will "return"
		List<Object> responseObjects = new List<Object>{
			HealthCheckMockCallout.fakeLogin()
			,qr
			,qr
			,qr
			,qr
			,qr
			,dr
            ,qr
            ,qr
		};

		//Set the mock callout that will generate fake response for the unit tests.
		HealthCheckMockCallout callout = new HealthCheckMockCallout(responseObjects);
		Test.setMock(HttpCalloutMock.class,callout);

		Test.startTest();
		RESTRequestUtil rr = HealthCheckMockCallout.getRESTRequest();
		String rrString = JSON.serialize(rr);

		HealthCheckMetricsCtrl.MetricsWrapper result = HealthCheckMetricsCtrl.getMetrics(rrString);
        Lead l = (Lead)JSON.deserialize(result.newLead,Lead.class);
        insert l;
        HealthCheckMetricsCtrl.updateLead(JSON.serialize(l));
		Test.stopTest();

		System.assertEquals(5,result.classes);
		System.assertEquals(5,result.managedClasses);
		System.assertEquals(5,result.profiles);
		System.assertEquals(5,result.permissionSets);
		System.assertEquals(1,result.managedCustomObjects);
		System.assertEquals(1,result.customObjects);
		System.assertEquals(5,result.roles);
        System.assertEquals(5,result.pages);
        System.assertEquals(5,result.triggers);
	}
}