@isTest
public class ProjectAlignToAccountGoals_UnitTest {

    @isTest static void testAccountPlan() {
        
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
        
        // Account Plan
        Account_Plan__c objPlan1 = new Account_Plan__c();
        objPlan1.Account__c = clientAcct.Id;
        objPlan1.Practice__c = 'Platform Commitment';
        objPlan1.Plan_Start_Date__c = System.Today().addDays(-100);
        objPlan1.Plan_End_Date__c = System.Today().addDays(100);
        insert objPlan1;
        
        // Account Plan2
        Account_Plan__c objPlan2 = new Account_Plan__c();
        objPlan2.Account__c = clientAcct.Id;
        objPlan2.Practice__c = 'Project Deployment';
        objPlan2.Plan_Start_Date__c = System.Today().addDays(-100);
        objPlan2.Plan_End_Date__c = System.Today().addDays(100);
        insert objPlan2;
        
        //project
        pse__Proj__c proj = new pse__Proj__c();
        proj.Name = 'Test Project';
        proj.pse__Account__c = clientAcct.Id;
        proj.DCS_Primary_Practice__c = 'Platform Commitment';
        proj.pse__Billing_Type__c = 'Time and Materials';
        proj.pse__Is_Active__c = TRUE;
        proj.pse__Is_Billable__c = TRUE;
        proj.pse__Start_Date__c = date.today();
        proj.pse__End_Date__c = date.today() + 30;
        proj.dcs_Requested_Hours__c = 8;
        proj.dcs_Assignment_Start_Date__c = date.today();
        proj.dcs_Assignment_End_Date__c = date.today() + 7;
		proj.pse__Project_Type__c = 'Test Type';
	
        insert proj;
        
        //project
        pse__Proj__c proj2 = new pse__Proj__c();
        proj2.Name = 'Test Project';
        proj2.pse__Account__c = clientAcct.Id;
        proj2.DCS_Primary_Practice__c = 'Project Deployment';
        proj2.pse__Billing_Type__c = 'Time and Materials';
        proj2.pse__Is_Active__c = TRUE;
        proj2.pse__Is_Billable__c = TRUE;
        proj2.pse__Start_Date__c = date.today();
        proj2.pse__End_Date__c = date.today() + 30;
        proj2.dcs_Requested_Hours__c = 8;
        proj2.dcs_Assignment_Start_Date__c = date.today();
        proj2.dcs_Assignment_End_Date__c = date.today() + 7;
		proj2.pse__Project_Type__c = 'Test Type';
	
        insert proj2;
       
        
    }
}