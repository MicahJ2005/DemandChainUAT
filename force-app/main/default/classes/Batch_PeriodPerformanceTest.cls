@isTest private class Batch_PeriodPerformanceTest {
	@testSetup
    static void setup(){
        insert new PeriodPerformanceSettings__c(PP_Start_Date__c = date.today()-60, PP_End_Date__c = date.today()+60);
     
        Contact testContact = new Contact(lastname = 'test', Email = 'test@test.com', pse__Is_Resource__c = true, pse__Is_Resource_Active__c = true);
        insert testContact; 
        
        pse__Practice__c corporatePractice = new pse__Practice__c(Name = 'Corporate');
        pse__Practice__c practice = new pse__Practice__c(Name = 'Platform Commitment');
        insert practice;
        insert corporatePractice;
   
        List<Account> accounts = new List<Account>();
        List<Opportunity> opps = new List<Opportunity>();
        List<pse__Timecard__c> timecards  = new List<pse__Timecard__c>();
        List<pse__Billing_Event__c> billingEvents = new List<pse__Billing_Event__c >();
        List<Account_Plan__c> plans = new List<Account_Plan__c>();
        
        for(Integer i=0;i<10;i++){
            accounts.add(new Account(name='Account ' + i, Salesforce_Aligned_Vertical__c = 'Other'));           
        }
        insert accounts;       

        // Project for timecards/billing events
        pse__Proj__c p = new pse__Proj__c(pse__Account__c = [SELECT Id From Account Limit 1].Id, pse__Is_Active__c = true, 	pse__Is_Billable__c = true, pse__Practice__c = practice.Id);
        insert p;
        
        // Permissions
        List<pse__Permission_Control__C> permissions = new List<pse__Permission_Control__C>();
                
        pse__Permission_Control__c staffContact = new pse__Permission_Control__c(pse__User__c = UserInfo.getUserId(), pse__Staffing__c = true, pse__Resource__c = testContact.Id);
        permissions.add(staffContact);
        
        pse__Permission_Control__c staffProject = new pse__Permission_Control__c(pse__User__c = UserInfo.getUserId(), pse__Project__c = p.Id, pse__Staffing__c = true);
        permissions.add(staffProject);
        
        pse__Permission_Control__c createTimecards = new pse__Permission_Control__c(pse__User__c = UserInfo.getUserId(), pse__Resource__c = testContact.Id, pse__Timecard_Entry__c = true);
        permissions.add(createTimecards);
        
        insert permissions;
                  
        //Assignment for timecard, timecard header
        pse__Assignment__c assignment = new pse__Assignment__c(	pse__Is_Billable__c = true, pse__Project__c = p.Id, pse__Resource__c = testContact.Id, Name = 'test', pse__Bill_Rate__c = 10, pse__Cost_Rate_Amount__c = 10, pse__Planned_Bill_Rate__c = 10 );
        insert assignment;
        
        pse__Timecard_Header__c header = new pse__Timecard_Header__c(pse__Project__c = p.Id, pse__Resource__c = testContact.Id, pse__Start_Date__c = date.today(), pse__End_Date__C = date.today()+6, pse__Assignment__c = assignment.Id);
        insert header;
        
        for(Account a : [select id from Account]){
            opps.add(new Opportunity(Name = 'test', pse__practice__c = practice.Id, CloseDate = date.today(), StageName = 'A. Closed/Won', accountId = a.Id, Amount = 0, Partner_Project_Name__c = 'name', Partner_Impacted_Users__c = 1, Partner_Salesforce_Admin__c = testContact.Id, Partner_Executive_Sponsor__c = testContact.Id));
        	plans.add(new Account_Plan__c(Practice1__c = practice.Id, Planned_Revenue__c = 0, Plan_Start_Date__c = date.today(), Plan_End_Date__c = date.today(), Account__c = a.Id, Practice__C = 'Platform Commitment'));
            timecards.add(new pse__Timecard__c(pse__Status__c ='Approved', pse__Start_Date__c = date.today(), pse__End_Date__c = date.today(), pse__Timecard_Header__c = header.Id, pse__Assignment__c = assignment.Id, pse__Project__c = p.Id, pse__Total_Billable_Amount__c = 0, pse__Resource__c = testContact.Id));
            billingEvents.add(new pse__Billing_Event__c(pse__Status__c = 'Approved', pse__Project__c = p.Id, pse__Summary_Amount__c = 0, pse__Invoice_Date__c = date.today()));      
        }
        insert opps;
        insert plans;
        insert timecards;
        insert billingEvents;
        
        List<Account> activeAccounts = new List<Account>();
        for(Integer i=0;i<10;i++){
            activeAccounts.add(new Account(name='Account '+ i));
        }
        insert activeAccounts;

    }
    
    
    static testmethod void test(){
        Test.startTest();
        String CRON_EXP = '0 0 0 ? * * *';
        String jobId = System.schedule('Batch_PeriodPerformanceSchedule', '0 0 0 ? * * *', new Batch_PeriodPerformanceSchedule());
        Test.stopTest();
        
        System.assertEquals(0, [SELECT count() FROM Period_Performance__c WHERE Has_Data_In_Period__c = false]);
    }
}