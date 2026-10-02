@isTest
public class PtoBalanceMethods_Test {
	//Deactivate flow "FF PROJECT - SYNC PO AND PM" before running and then activate flow after test is complete
    @testSetup
    static void testSetup() {
        Account oAccount = new Account(Name = 'Test Account');
        insert oAccount;
        
        RecordType recType_Employee = [Select Id, Name From RecordType Where Name = 'Employee' And SobjectType = 'Contact' LIMIT 1];
        Contact oContact = new Contact(FirstName = 'TestFN'
										, LastName = 'TestLN'
                                      	, AccountId = oAccount.Id
                                       	, Email = 'test@test.com'
                                       	, Phone = '(651) 222-3333'
                                       	, MobilePhone = '(952) 222-3333'
                                       	, RecordTypeId = recType_Employee.Id
                                       	, pse__Is_Resource__c = true
                                       	, pse__Is_Resource_Active__c = true
                                      	, pse__Salesforce_User__c = UserInfo.getUserId());
        insert oContact;
        system.debug('Contact: ' + oContact);
        
        pse__Proj__c oProject = new pse__Proj__c(Name = 'PTO'
												, pse__Account__c = oAccount.Id
												, pse__Is_Active__c = true);
        insert oProject;
        
        List<pse__Permission_Control__c> lstFFControls = new List<pse__Permission_Control__c>();
        lstFFControls.add(new pse__Permission_Control__c(pse__User__c = UserInfo.getUserId()
														, pse__Project__c = oProject.Id
														, pse__Expense_Entry__c = true
                                                       	, pse__Expense_Ops_Edit__c = true
                                                       	, pse__Forecast_Edit__c = true
                                                       	, pse__Forecast_View__c = true
                                                       	, pse__Invoicing__c = true
                                                       	, pse__Edit_Task_Manager__c = true
                                                       	, pse__View_Task_Manager__c = true
                                                       	, pse__Compare_Project_Version__c = true
                                                       	, pse__Create_Project_Version__c = true
                                                       	, pse__Delete_Project_Version__c = true
                                                       	, pse__Resource_Request_Entry__c = true
                                                       	, pse__Skills_And_Certifications_Entry__c = true
                                                       	, pse__Skills_And_Certifications_View__c = true
                                                       	, pse__Staffing__c = true
                                                       	, pse__Team_Create__c = true
                                                       	, pse__Team_Edit__c = true
                                                       	, pse__Team_View__c = true
                                                       	, pse__Timecard_Entry__c = true
                                                       	, pse__Timecard_Ops_Edit__c = true));

                         
        lstFFControls.add(new pse__Permission_Control__c(pse__User__c = UserInfo.getUserId()
														, pse__Resource__c = oContact.Id
														, pse__Expense_Entry__c = true
                                                       	, pse__Expense_Ops_Edit__c = true
                                                       	, pse__Forecast_Edit__c = true
                                                       	, pse__Forecast_View__c = true
                                                       	, pse__Invoicing__c = true
                                                       	, pse__Edit_Task_Manager__c = true
                                                       	, pse__View_Task_Manager__c = true
                                                       	, pse__Compare_Project_Version__c = false
                                                       	, pse__Create_Project_Version__c = false
                                                       	, pse__Delete_Project_Version__c = false
                                                       	, pse__Resource_Request_Entry__c = true
                                                       	, pse__Skills_And_Certifications_Entry__c = true
                                                       	, pse__Skills_And_Certifications_View__c = true
                                                       	, pse__Staffing__c = true
                                                       	, pse__Team_Create__c = true
                                                       	, pse__Team_Edit__c = true
                                                       	, pse__Team_View__c = true
                                                       	, pse__Timecard_Entry__c = true
                                                       	, pse__Timecard_Ops_Edit__c = true));
		insert lstFFControls;
    }
    
    static testMethod void testCreateBalanceRecs() {
        Account oAccount = [Select Id, Name From Account LIMIT 1];
        Contact oContact = [Select Id, FirstName, LastName, AccountId, pse__Salesforce_User__c From Contact LIMIT 1];
        pse__Proj__c oProjPTO = [Select Id, Name From pse__Proj__c LIMIT 1];
        Test.startTest();
        
        Date startDate = Date.newInstance(Date.today().year(), 6, 1);
        Date endDate = startDate.addYears(1).addDays(-1);
        
        PTO_Accrual_Setup__c oSetup1 = new PTO_Accrual_Setup__c(Employee__c = oContact.Id
																, Accrual_Start_Date__c = startDate
																, Accrual_End_Date__c = endDate
																, Annual_PTO_Hours__c = 80
																, Starting_PTO_Balance__c = 20
																, Carryover_Allowed__c = 40);
        insert oSetup1;

        startDate = startDate.addYears(1);
        endDate = endDate.addYears(1);
        PTO_Accrual_Setup__c oSetup2 = new PTO_Accrual_Setup__c(Employee__c = oContact.Id
																, Accrual_Start_Date__c = startDate
																, Accrual_End_Date__c = endDate
																, Annual_PTO_Hours__c = 80
																, Starting_PTO_Balance__c = null
																, Carryover_Allowed__c = 40);
        insert oSetup2;
        
        PTO_Balance__c oBalance = [Select Id
										, Start_Date__c
										, End_Date__c
										, Record_ID__c 
										, Employee__c
										, Starting_Balance__c
										, Mgmt_Adjustment__c
										, Hours_Taken__c
										, Hours_Requested__c
										, Accrued_Hours__c
										, PTO_Accrual_Setup__c
										, PTO_Accrual_Setup__r.Carryover_Allowed__c
										, PTO_Accrual_Setup__r.Accrual_Rate__c
									From PTO_Balance__c
									Order By Start_Date__c
									LIMIT 1];
		oBalance.Mgmt_Adjustment__c = 1;
		update oBalance;
        
        oSetup2.Accrual_End_Date__c = endDate.addMonths(-2);
        
        PtoBalanceMethods.fetchPTOBalances(startDate, endDate, oContact.Id);
        update oSetup2;
        delete oSetup2;

        PtoBalanceMethods.nullToZero(null);
        PtoBalanceMethods.getPeriodStartDate(Date.newInstance(Date.today().year(), Date.today().month(), 20));
        
        test.stopTest();
    }
    
    static testMethod void requestPTO() {
        Account oAccount = [Select Id, Name From Account LIMIT 1];
        Contact oContact = [Select Id, FirstName, LastName, AccountId, pse__Salesforce_User__c From Contact LIMIT 1];
        pse__Proj__c oProjPTO = [Select Id, Name From pse__Proj__c LIMIT 1];
        
        Date startDate = Date.newInstance(Date.today().year(), Date.today().month(), 1);
        Date endDate = startDate.addYears(1).addDays(-1);
        
        PTO_Accrual_Setup__c oSetup1 = new PTO_Accrual_Setup__c(Employee__c = oContact.Id
																, Accrual_Start_Date__c = startDate
																, Accrual_End_Date__c = endDate
																, Annual_PTO_Hours__c = 80
																, Starting_PTO_Balance__c = 20
																, Carryover_Allowed__c = 40);
        insert oSetup1;
        
        Test.startTest();
        pse__Schedule__c oSchedule1 = new pse__Schedule__c(pse__Start_Date__c = startDate.addMonths(2)
														, pse__End_Date__c = startDate.addMonths(2)
														, pse__Scheduled_Hours__c = 8
														, pse__Scheduled_Days__c = 1);
        insert oSchedule1;
        pse__Assignment__c oAssignment1 = new pse__Assignment__c(Name = 'Test'
                                                                , pse__Schedule__c = oSchedule1.Id
																, pse__Status__c = 'Scheduled'
                                                                , pse__Bill_Rate__c = 0
																, pse__Project__c = oProjPTO.Id
																, pse__Resource__c = oContact.Id);
        insert oAssignment1;
        
        pse__Schedule__c oSchedule2 = new pse__Schedule__c(pse__Start_Date__c = oSchedule1.pse__Start_Date__c.addDays(1)
                                                            , pse__End_Date__c = oSchedule1.pse__End_Date__c.addDays(6)
                                                            , pse__Sunday_Hours__c = 1
                                                            , pse__Monday_Hours__c = 2
                                                            , pse__Tuesday_Hours__c = 3
                                                            , pse__Wednesday_Hours__c = 4
                                                            , pse__Thursday_Hours__c = 5
                                                            , pse__Friday_Hours__c = 6
                                                            , pse__Saturday_Hours__c = 7);
        insert oSchedule2;
        pse__Assignment__c oAssignment2 = new pse__Assignment__c(Name = 'Test'
                                                                , pse__Schedule__c = oSchedule2.Id
																, pse__Status__c = 'Scheduled'
                                                                , pse__Bill_Rate__c = 0
																, pse__Project__c = oProjPTO.Id
																, pse__Resource__c = oContact.Id);
        insert oAssignment2;
        
        Test.stopTest();
    }
    
    static testMethod void submitPTO() {
        Account oAccount = [Select Id, Name From Account LIMIT 1];
        Contact oContact = [Select Id, FirstName, LastName, AccountId, pse__Salesforce_User__c From Contact LIMIT 1];
        pse__Proj__c oProjPTO = [Select Id, Name From pse__Proj__c LIMIT 1];
        
        Date startDate = Date.newInstance(Date.today().year(), Date.today().month(), 1);
        Date endDate = startDate.addYears(1).addDays(-1);
        
        PTO_Accrual_Setup__c oSetup1 = new PTO_Accrual_Setup__c(Employee__c = oContact.Id
																, Accrual_Start_Date__c = startDate
																, Accrual_End_Date__c = endDate
																, Annual_PTO_Hours__c = 80
																, Starting_PTO_Balance__c = 20
																, Carryover_Allowed__c = 40);
        insert oSetup1;
        
        Test.startTest();
        Datetime dttDOW = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
        while (dttDOW.format('EEE') != 'Sun') {
            startDate = startDate.addDays(1);
            dttDOW = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
        }
        endDate = startDate.addDays(6);
        
        pse__Assignment__c oAssignment = new pse__Assignment__c(Name = 'Test'
																, pse__Status__c = 'Scheduled'
                                                                , pse__Bill_Rate__c = 0
																, pse__Project__c = oProjPTO.Id
																, pse__Resource__c = oContact.Id);
        insert oAssignment;
        pse__Timecard_Header__c oTimecard = new pse__Timecard_Header__c(pse__Resource__c = oContact.Id
																		, pse__Project__c = oProjPTO.Id
                                                                       	, pse__Start_Date__c = startDate
                                                                       	, pse__End_Date__c = endDate
                                                                       	, pse__Sunday_Hours__c = 8
                                                                       	, pse__Monday_Hours__c = 8
                                                                       	, pse__Tuesday_Hours__c = 8
                                                                       	, pse__Wednesday_Hours__c = 8
                                                                       	, pse__Thursday_Hours__c = 8
                                                                       	, pse__Friday_Hours__c = 8
                                                                       	, pse__Saturday_Hours__c = 8
                                                                       	, pse__Status__c = 'Approved'
                                                                       	, pse__Assignment__c = oAssignment.Id
                                                                       	, pse__Billable__c = false);
        insert oTimecard;
        Test.stopTest();
    }
}