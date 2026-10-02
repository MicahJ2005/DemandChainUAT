/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an organization are executed whenever Apex code is deployed
 * to a production organization to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production organization. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the organization size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest(SeeAllData = true)
private class TestAssignmentRequest {

  static testMethod void testRunAs(){
	
	Test.startTest();
	
	//user
	Profile p = [select id from profile where name='System Administrator'];
    
	User testUser = new User();
	testUser.alias='testU';
	testUser.email='iambatman+seriously@wayneenterprises.com';
	testUser.firstname='Neil';
	testUser.lastname='Peart';
	testUser.profileid=p.Id;
	testUser.localesidkey='en_US';
	testUser.username='iambatman+seriously@wayneenterprises.com';
	testUser.timezonesidkey='America/Chicago';
	testUser.languagelocalekey='en_US';
	testUser.emailencodingkey='UTF-8';
	 
	insert testUser;   
    
  //work calendar
  pse__Work_Calendar__c wrkCal = new pse__Work_Calendar__c();
  wrkCal.Name = 'US - Default';    
  wrkCal.pse__Week_Start_Day__c = 'Monday';
  wrkCal.pse__Standard_Hours_Per_Day__c = 8; 
 	wrkCal.pse__Monday_Hours__c = 8;
 	wrkCal.pse__Tuesday_Hours__c = 8; 
  wrkCal.pse__Wednesday_Hours__c = 8;     
  wrkCal.pse__Thursday_Hours__c = 8;
  wrkCal.pse__Friday_Hours__c = 8;
  wrkCal.pse__Saturday_Hours__c = 8; 
  wrkCal.pse__Sunday_Hours__c = 8;  
    
  insert wrkCal; 
    
	//region
	pse__Region__c reg = new pse__Region__c();
	reg.Name = 'Test Region';
	reg.pse__Default_Work_Calendar__c = wrkCal.Id;
	reg.pse__Include_In_Forecasting__c = TRUE;
	
	insert reg;
        
	//dcs acct
	Account dcsAcct = new Account();
	dcsAcct.Name = 'Test DCS';
	dcsAcct.RecordTypeId = '012000000004EcZAAU';
	
	insert dcsAcct;
	
	//client acct
	Account clientAcct = new Account();
	clientAcct.Name = 'Test Client';
	dcsAcct.RecordTypeId = '012000000004EcZAAU';
	
	insert clientAcct;
	
	//dcs contact
	Contact dcsCont = new Contact();
	dcsCont.FirstName = 'Test';
	dcsCont.LastName = 'DCSContact';
	dcsCont.AccountId = dcsAcct.Id;
	//dcsCont.ContactStatus__c = 'Active';
	dcsCont.pse__Region__c = reg.Id;
	dcsCont.pse__Work_Calendar__c = wrkCal.Id;
	dcsCont.pse__Salesforce_User__c = testUser.Id;
	dcsCont.pse__Is_Resource__c = TRUE;
	dcsCont.pse__Is_Resource_Active__c = TRUE;
	
	insert dcsCont;
	
	//project
	pse__Proj__c proj = new pse__Proj__c();
	proj.Name = 'Test Project';
	proj.pse__Account__c = clientAcct.Id;
	proj.pse__Billing_Type__c = 'Time and Materials';
	proj.pse__Is_Active__c = TRUE;
	proj.pse__Is_Billable__c = TRUE;
	proj.pse__Start_Date__c = date.today();
	proj.pse__End_Date__c = date.today() + 30;
	proj.dcs_Requested_Hours__c = 8;
	proj.dcs_Assignment_Start_Date__c = date.today();
	proj.dcs_Assignment_End_Date__c = date.today() + 7;
	
	insert proj;
	
	//schedule
	pse__Schedule__c sched = new pse__Schedule__c();
	sched.pse__Wednesday_Hours__c = 8;
	sched.pse__Tuesday_Hours__c = 8;
	sched.pse__Thursday_Hours__c = 8;
	sched.pse__Sunday_Hours__c = 0;
	sched.pse__Start_Date__c = system.Today();
	sched.pse__Scheduled_Hours__c = 80;
	sched.pse__Scheduled_Days__c = 40;
	sched.pse__Saturday_Hours__c = 0;
	sched.pse__Monday_Hours__c = 8;
	sched.pse__Friday_Hours__c = 8;
	sched.pse__End_Date__c = system.Today() + 90;
  sched.CurrencyIsoCode = 'USD';
  
  insert sched;
  	
	//permission control - resource
  pse__Permission_Control__c pcr = new pse__Permission_Control__c();
  pcr.pse__User__c = testUser.id;
  pcr.pse__Timecard_Ops_Edit__c = true;
  pcr.pse__Timecard_Entry__c = true;
  pcr.pse__Staffing__c = true;
  pcr.pse__Skills_And_Certifications_View__c = true;
  pcr.pse__Skills_And_Certifications_Entry__c = true;
  pcr.pse__Resource__c = dcsCont.id;
  pcr.pse__Resource_Request_Entry__c = true;
  pcr.pse__Invoicing__c = true;
  pcr.pse__Forecast_View__c = true;
  pcr.pse__Forecast_Edit__c = true;
  pcr.pse__Expense_Ops_Edit__c = true;
  pcr.pse__Expense_Entry__c = true;
  pcr.pse__Cascading_Permission__c = true;
  pcr.pse__Billing__c = true;
  
  insert pcr;
  
  //permission control - project
  pse__Permission_Control__c pcp = new pse__Permission_Control__c();
  pcp.pse__User__c = testUser.id;
  pcp.pse__Timecard_Ops_Edit__c = true;
  pcp.pse__Timecard_Entry__c = true;
  pcp.pse__Staffing__c = true;
  pcp.pse__Skills_And_Certifications_View__c = true;
  pcp.pse__Skills_And_Certifications_Entry__c = true;
  pcp.pse__Resource_Request_Entry__c = true;
  pcp.pse__Invoicing__c = true;
  pcp.pse__Forecast_View__c = true;
  pcp.pse__Forecast_Edit__c = true;
  pcp.pse__Expense_Ops_Edit__c = true;
  pcp.pse__Expense_Entry__c = true;
  pcp.pse__Cascading_Permission__c = true;
  pcp.pse__Billing__c = true;
  pcp.pse__Project__c = proj.id;
  
  insert pcp;
	
	system.runAs(testUser){
		//assignment
		pse__Assignment__c asgmt = new pse__Assignment__c();
		asgmt.pse__Schedule__c = sched.Id;
		asgmt.pse__Resource__c = dcsCont.Id;
		asgmt.pse__Project__c = proj.Id;
		asgmt.pse__Planned_Bill_Rate__c = 200;
		asgmt.pse__Cost_Rate_Amount__c = 100;
		asgmt.pse__Bill_Rate__c = 200;
		asgmt.Name = 'Test Assignment';
		asgmt.CurrencyIsoCode = 'USD';
		
		insert asgmt;	
		
		//milestone
		pse__Milestone__c ms = new pse__Milestone__c();
		ms.pse__Target_Date__c = system.today() + 7;
		ms.pse__Project__c = proj.id;
		ms.pse__Milestone_Amount__c = 100;
		ms.Name = 'Test Milestone';
		ms.CurrencyIsoCode = 'USD';
		
		insert ms;
	 	
		//instantiate assignment page and custom controller	
		PageReference pageRef = new PageReference('/apex/AssignmentRequest?id='+testUser.Id);
	  Test.setCurrentPage(pageRef);
			
		AssignmentRequest controller = new AssignmentRequest();
	
		//stage data as the controller would
		controller.lstProjs = new List<AssignmentRequest.progAssgmtHelper>(); //note: progAssgmtHelper is a helper class in controller
		AssignmentRequest.progAssgmtHelper testHelper = new AssignmentRequest.progAssgmtHelper();
	
		testHelper.chooseRec = TRUE;
		testHelper.assignmentNote = 'Test note';
		testHelper.endDate = system.today() + 7;
		testHelper.id = proj.id;
		testHelper.Name = 'Test Project';
		testHelper.recType = 'Project';
		testHelper.reqHours = 8;
		testHelper.startDate = system.today();
		//testHelper.submittedRec = TRUE;	
		
		controller.lstProjs.add(testHelper);  //list referenced in ensuing method (requestAssignment)
	    
	  controller.requestAssgmt();  //request assignment(s) button
	
	  controller.paramFilterProj = 'All';    	    
	  controller.AssignmentSearch();  //toggle link that retrieves my projects and all projects not assigned to user
	
		controller.paramSearchProj = 'Search executed';
		controller.projectSearch = TRUE;
	 
		controller.paramFilterProj = 'My';    	    
		controller.AssignmentSearch();  //retreive all projects
		
		controller.searchText = 'Test';  //search for test project
		controller.searchProjs();  //search project button
		controller.cancel();  //cancel button
		controller.clear();  //clear button
	    
	 Test.stopTest();	  
	 }  //end of runas
  } //end of method
}  //end of class