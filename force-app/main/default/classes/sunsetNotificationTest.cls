@isTest
private class sunsetNotificationTest {

// COMMENTED OUT 20171215 AAB - WHAT THE HELL IS THIS CRAP?

//static testMethod void resourceUpdateUnitTest() {
 
//        Date dt = system.today();
        
//        //insert test resource
//        Resource__c testResource = new Resource__c(
//            name = 'Kevin Testperson',
//            Email_Address__c = 'kevin@gmail.com');
        
//        insert testResource;
    
//        //insert test account
//        Account testAccount = new Account(name = 'KDJ Test Account');
        
//        insert testAccount; 
        
//        //insert test oppty
//        Opportunity testOppty = new Opportunity( 
//            StageName = 'Closed Won', 
//            name = 'Test Opportunity',
//            CloseDate = dt,
//            Amount = 1,
//            Hourly_Rate__c = 1,
//            Client_Sponsor__c = 'TEST',
//            AccountId = testAccount.id,
//            Target_End_Date__c = dt,
//            Resource_One__c = testResource.id
//        ,Reason_for_Win_Loss_Abandoned__c='Won');
        
//        insert testOppty;
                
//        testOppty.Sunset_Meeting_Review_Items__c = 'Test   Test again';
//        testOppty.Sunset_Notification_Created__c = true;
//        update testOppty;
        
//        //insert test sunset task
//        Task testTask = new Task(
//        	WhatID = testOppty.Id,
//        	OwnerID = '00500000005CNYC',
//        	Subject = 'Sunset Meeting: ' + testOppty.Name,
//	        Priority = 'Normal',
//	        Status = 'Not Started',
//	        ActivityDate = testOppty.Target_End_Date__c,
//	        Description = testOppty.Sunset_Meeting_Review_Items__c);
                
//        insert testTask;
        
//        testTask.Description = 'Update with more information...';
//        update testTask;
        
//        delete testTask;
        
//    }
}