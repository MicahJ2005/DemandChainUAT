public with sharing class RESTQueriesCtrl {
	/*public static QueryResponse query(RESTRequest rest,String query){
		query = query.replaceAll(' ','+');
		String queryString = '/services/data/v37.0/query?q=' + query;
		String response = rest.request(null,'GET',queryString);
		return (QueryResponse)JSON.deserialize(response,QueryResponse.class);
	}

	public static MetadataContainerQueryResponse queryMC(RESTRequest rest,String query){
		query = query.replaceAll(' ','+');
		String queryString = '/services/data/v37.0/tooling/query?q=' + query;
		String response = rest.request(null,'GET',queryString);
		return (MetadataContainerQueryResponse)JSON.deserialize(response,MetadataContainerQueryResponse.class);
	}

	public static QueryResponse queryTooling(RESTRequest rest,String query){
		query = query.replaceAll(' ','+');
		String queryString = '/services/data/v37.0/tooling/query?q=' + query;
		String response = rest.request(null,'GET',queryString);
		return (QueryResponse)JSON.deserialize(response,QueryResponse.class);
	}

	public static MetadataContainerResponse createTooling(RESTRequest rest,String sobjectName,String body){

		String queryString = '/services/data/v37.0/tooling/sobjects/' + sobjectName;
		String response = rest.request(body,'POST',queryString);
		return (MetadataContainerResponse)JSON.deserialize(response,MetadataContainerResponse.class);
	}

	public static ApexClassResult queryApexClasses(RESTRequest rest,String query){
		query = query.replaceAll(' ','+');
		String queryString = '/services/data/v37.0/tooling/query?q=' + query;
		String response = rest.request(null,'GET',queryString);
		return (ApexClassResult)JSON.deserialize(response,ApexClassResult.class);
	}

	public class ApexClassMember{
		public String body {get;set;}
		public String contentEntityId {get;set;}
		public String metadataContainerId {get;set;}
	}

	public class MetadataContainerResponse{
		public String id {get;set;}
		public boolean success {get;set;}
	}*/

	public class ApiVersionResponse{
		public String version {get;set;}
		public String label {get;set;}
		public String url {get;set;}
	}

	/*public class QueryResponse{
		public Integer totalSize {get;set;} 
		public Boolean done {get;set;} 
		public List<sObject> records {get;set;}
	}

	public class MetadataContainerQueryResponse{
		public List<Record> records {get; set;}
	}

	public class Record{
		public String id {get; set;}
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

	public class LimitWrapper{
		public Integer Max {get; set;}
		public Integer Remaining {get; set;}
	}

	public class LimitReport{
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

	public class ApexClassResult{
		public List<ApexClassRecord> records {get; set;}
	}

	public class ApexClassRecord{
		public String Id {get;set;}
		public String body {get; set;}
		public SymbolTable SymbolTable {get;set;}
	}

	public class UserRoleReport{
		@AuraEnabled
		public Integer numRoles  {get;set;}
		@AuraEnabled
		public Integer numUnusedRoles {get;set;}
		@AuraEnabled
		public Integer percentUsed { get; set;}
	}

	public class SymbolTable {
		public List<Constructor> constructors {get;set;}
		public List<String> externalReferences {get;set;}
		public String id {get;set;}
		public List<SymbolTable> innerClasses {get;set;}
		//public List<String> interfaces {get;set;}
		public String key {get;set;}
		public List<Method> methods {get;set;}
		public String name {get;set;}
		public Object namespace {get;set;}
		public String parentClass {get;set;}
		//public List<Constructors> properties {get;set;}
		public TableDeclaration tableDeclaration {get;set;}
		public List<Variable> variables {get;set;}
	}

	public class Variable {
		public List<Constructor> annotations {get;set;}
		public Location location {get;set;}
		public List<Constructor> modifiers {get;set;}
		public String name {get;set;}
		public List<Constructor> references {get;set;}
		public String type_Z {get;set;} // in json: type
	}

	public class Parameters {
		public String name {get;set;}
		public String type_Z {get;set;} // in json: type

	}

	public class TableDeclaration {
		public List<Constructor> annotations {get;set;}
		public Location location {get;set;}
		public List<String> modifiers {get;set;}
		public String name {get;set;}
		public List<Constructor> references {get;set;}
		public String type_Z {get;set;} // in json: type
	}

	public class Constructor {
	}

	public class Method {
		public List<Constructor> annotations {get;set;}
		public Location location {get;set;}
		public List<String> modifiers {get;set;}
		public String name {get;set;}
		public List<Parameters> parameters {get;set;}
		public List<Constructor> references {get;set;}
		public String returnType {get;set;}
		public Object type_Z {get;set;} // in json: type

	}

	public class Location {
		public Integer column {get;set;}
		public Integer line {get;set;}
	}*/
}