public class HealthCheckCodeCoverageCtrl {
	@AuraEnabled
	public static Decimal getOrgWideCodeCoverage(String restRequestJson){
        RESTRequestUtil rr = (RESTRequestUtil)JSON.deserialize(restRequestJson,RESTRequestUtil.class);
        //The v is important, otherwise a 404 is thrown.  Grr...
		String queryString = '/services/data/v' + rr.apiVersion + '/tooling/query?q=Select+PercentCovered+From+ApexOrgWideCoverage';
		String response = rr.requestProxy(null,'GET',queryString);
		ApexOrgWideCoverageResponse coverageResponse = (ApexOrgWideCoverageResponse)JSON.deserialize(response,ApexOrgWideCoverageResponse.class);
		return coverageResponse.records.get(0).percentCovered;
	}
    
    public class ApexOrgWideCoverageResponse{
		public List<ApexOrgWideCoverage> records {get;set;}
	}

	public class ApexOrgWideCoverage{
		public Decimal percentCovered {get;set;}
	}
}