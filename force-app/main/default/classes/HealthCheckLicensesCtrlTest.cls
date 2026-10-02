/**
 * Test class for the HealthCheckLicensesCtrl
 * @author  James Loghry
 * @date  8/23/2016
 */
@isTest
private class HealthCheckLicensesCtrlTest {

	static testmethod void testGetLicenses(){
		HealthCheckLicensesCtrl.UserLicenseResponse licenseNameResponse = new HealthCheckLicensesCtrl.UserLicenseResponse();
		licenseNameResponse.records = new List<HealthCheckLicensesCtrl.UserLicenseWrapper>();

		HealthCheckLicensesCtrl.UserLicenseWrapper ulw1 = new HealthCheckLicensesCtrl.UserLicenseWrapper();
		ulw1.Id = 'blah1';
		ulw1.Name = 'Test1';
		licenseNameResponse.records.add(ulw1);

		HealthCheckLicensesCtrl.UserLicenseWrapper ulw2 = new HealthCheckLicensesCtrl.UserLicenseWrapper();
		ulw2.Id = 'blah2';
		ulw2.Name = 'Test2';
		licenseNameResponse.records.add(ulw2);

		HealthCheckLicensesCtrl.UserLicenseWrapper ulw3 = new HealthCheckLicensesCtrl.UserLicenseWrapper();
		ulw3.Id = 'blah3';
		ulw3.Name = 'Test3';
		licenseNameResponse.records.add(ulw3);

		HealthCheckLicensesCtrl.UserLicenseWrapper ulw4 = new HealthCheckLicensesCtrl.UserLicenseWrapper();
		ulw4.Id = 'blah4';
		ulw4.Name = 'Test4';
		licenseNameResponse.records.add(ulw4);

		HealthCheckLicensesCtrl.UserLicenseCountResponse licenseCountResponse = new HealthCheckLicensesCtrl.UserLicenseCountResponse();
		licenseCountResponse.records = new List<HealthCheckLicensesCtrl.UserLicenseCountWrapper>();

		HealthCheckLicensesCtrl.UserLicenseCountWrapper w1 = new HealthCheckLicensesCtrl.UserLicenseCountWrapper();
		w1.UserLicenseId = 'blah1';
		w1.numLicenses = 0;
		licenseCountResponse.records.add(w1);

		HealthCheckLicensesCtrl.UserLicenseCountWrapper w2 = new HealthCheckLicensesCtrl.UserLicenseCountWrapper();
		w2.UserLicenseId = 'blah2';
		w2.numLicenses = 5;
		licenseCountResponse.records.add(w2);

		HealthCheckLicensesCtrl.UserLicenseCountWrapper w3 = new HealthCheckLicensesCtrl.UserLicenseCountWrapper();
		w3.UserLicenseId = 'blah3';
		w3.numLicenses = 1;
		licenseCountResponse.records.add(w3);

		HealthCheckLicensesCtrl.UserLicenseCountWrapper w4 = new HealthCheckLicensesCtrl.UserLicenseCountWrapper();
		w4.UserLicenseId = 'blah4';
		w4.numLicenses = 1;
		licenseCountResponse.records.add(w4);

		//Construct the list of responses the mock callout will "return"
		List<Object> responseObjects = new List<Object>{
			HealthCheckMockCallout.fakeLogin()
			,licenseNameResponse
			,licenseCountResponse
		};

		//Set the mock callout that will generate fake response for the unit tests.
		HealthCheckMockCallout callout = new HealthCheckMockCallout(responseObjects);
		Test.setMock(HttpCalloutMock.class,callout);

		Test.startTest();
		RESTRequestUtil rr = HealthCheckMockCallout.getRESTRequest();
		String rrString = JSON.serialize(rr);

		HealthCheckLicensesCtrl.UserLicenseResponse result = HealthCheckLicensesCtrl.getUserLicenses(rrString);
        Lead l = (Lead)JSON.deserialize(result.newLead,Lead.class);
        insert l;
        HealthCheckLicensesCtrl.updateLead(JSON.serialize(l));
		Test.stopTest();

		System.assertEquals(4,result.records.size());
		//Assert the results come back in the order expected.
		System.assertEquals('Test2',result.records.get(0).Name);
		System.assertEquals('Test3',result.records.get(1).Name);
		System.assertEquals('Test4',result.records.get(2).Name);
		System.assertEquals('Test1',result.records.get(3).Name);
	}
}