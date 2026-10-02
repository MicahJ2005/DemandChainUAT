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
@isTest
private class assignmentDefaultRateTest {

    static testMethod void myAssignmentDefaultRateTest() {

	/*

        pse__Assignment__c asgn = null;
        Test.startTest();
        System.runAs((User)[Select Id From User Where username like 'chris@demandchainsystems.com%']){
	        Account acct = new Account();
	        acct.Name = 'Chris Test Account';
//	        acct.OwnerId = '00500000005CNYC'; //Owner is Chris Dahlberg 'Dev
	        acct.OwnerId = '00500000005CNYC'; //Owner is Chris Dahlberg 'Prod
	       
	        insert acct;
	       
//	        Contact cont = new Contact();
//	        cont.LastName = 'Dahlberg';
//	        cont.OwnerId = '00500000005CNYC'; //Owner is Chris Dahlberg
//	        cont.AccountId = acct.Id;
//	        cont.pse__Default_Cost_Rate__c = 1.50;
//	        cont.pse__Is_Resource_Active__c= true;
//	        cont.pse__Is_Resource__c= true;
//	        insert cont;
	       
	        pse__Proj__c proj = new pse__Proj__c();
	        proj.pse__Account__c = acct.Id;
	        proj.Name = 'Test Project';
	        proj.pse__Billing_Type__c = 'Time and Materials';
//	        proj.pse__Region__c = 'a1NP0000000JgbS'; //Twin Cities region - Dev
	        proj.pse__Region__c = 'a1N00000002Xnj7'; //Twin Cities region - Prod
	        insert proj;
	       
	        pse__Schedule__c sched = new pse__Schedule__c();
	        //sched.Name = 'ScheduleTest';
 	        sched.pse__End_Date__c = system.today();
 	        sched.pse__Start_Date__c = system.today();
 	        sched.pse__Monday_Hours__c = 1;	
	        sched.pse__Tuesday_Hours__c = 1;
	        sched.pse__Wednesday_Hours__c = 1;
	        sched.pse__Thursday_Hours__c = 1;
	        sched.pse__Friday_Hours__c = 1;
	        sched.pse__Saturday_Hours__c = 1;
	        sched.pse__sunday_Hours__c = 1;
	        insert sched;	       
	       	
	        asgn = new pse__Assignment__c();
	        asgn.Name = 'Chris Test Project 1 - Chris Dahlberg';
	        //asgn.pse__Resource__c = cont.Id;
//	        asgn.pse__Resource__c = '003P000000aspHsIAI'; //Chris Dahlberg - Dev
	        asgn.pse__Resource__c = '00300000003CkDz'; //Chris Dahlberg - Prod
	        asgn.pse__Role__c = 'Business Analyst';
	        asgn.pse__Schedule__c = sched.Id;
	        asgn.pse__Project__c = proj.Id;
	        asgn.pse__Bill_Rate__c = 0;
        
          
	        insert asgn;
        }
        Test.stopTest();
        
        system.debug('rcd assignmentId: ' + asgn.Id);
        system.debug('rcd resourceId: ' + asgn.pse__Resource__c);	       
        system.debug('rcd costRateAmount: ' + asgn.pse__Cost_Rate_Amount__c);
        system.debug('rcd CostRate: ' + asgn.pse__Cost_Rate__c);
        
        // Verify that the record got updated
        pse__Assignment__c updatedAssignment = [SELECT Id, pse__Cost_Rate_Amount__c  FROM pse__Assignment__c WHERE Id = :asgn.Id];
        
        
        system.debug('rcd updatedAssignment: ' + updatedAssignment.pse__Cost_Rate_Amount__c);	       
        System.assertEquals(100.00, updatedAssignment.pse__Cost_Rate_Amount__c);
        //system.assert(asgn.Id != null);
       
       
       */
       
    }
}