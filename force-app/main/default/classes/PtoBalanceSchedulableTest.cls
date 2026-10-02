@isTest
public class PtoBalanceSchedulableTest {

    @TestSetup
    static void makeData(){
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
    }

    @isTest
    static void testPtoBalanceSchedulable() {
        // Mess up the last balance and check that the schedulable fixes it
        PTO_Balance__c balance = [SELECT Id, Starting_Balance__c FROM PTO_Balance__c ORDER BY End_Date__c DESC LIMIT 1];
        balance.Starting_Balance__c = -10;
        update balance;

        Test.startTest();
        String cron = '0 0 0 1/1 * ? *';
        String jobId = System.schedule('PtoBalanceSchedulable', cron, new PtoBalanceSchedulable());
        test.stopTest();

        balance = [SELECT Id, Starting_Balance__c FROM PTO_Balance__c ORDER BY End_Date__c DESC LIMIT 1];
        System.Assert(balance.Starting_Balance__c > 0);
    }
}