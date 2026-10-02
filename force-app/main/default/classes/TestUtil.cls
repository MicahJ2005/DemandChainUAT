//Test Util - creates data, to be used in test classes across the org
//01.28.2020	Sophia Murphy
//				Initial Creation
@isTest
public class TestUtil {
	public static List<Account> getAccounts(integer numOfRecords, boolean doInsert){
		
		List<Account> acctList = new List<Account>();

		for(Integer i = 0; i < numOfRecords; i++) {
			String randNo = String.valueOf(Crypto.getRandomInteger());
			Account acct = new Account(	Name = 'DC ' + randNo ); 
			acctList.add(acct);
		}

		if(doInsert)
		{
			INSERT acctList;
		}
		return acctList;		// Return account list
	}	// END: getAccount
    
    public static List<Contact> getContacts(integer numOfRecords, boolean doInsert, Account act) {

		List<Contact> cntList = new List<Contact>();

		for(Integer i = 0; i < numOfRecords; i++) {
			// Get rand no.
			String randNo = String.valueOf(Crypto.getRandomInteger());
			Contact con = new Contact(FirstName = 'Test '
									, LastName = 'Contact ' + randNo
                                    , Email = 'abc' + randNo + 'xyz@domain' + randNo + '.com'
									, AccountId = act.Id
									, MailingState = 'NY');
			cntList.add(con);
		}

		if(doInsert)
		{
			INSERT cntList;
		}
		return cntList;		// Return Contact
	}	// END: getContacts
    
	public static List<pse__Practice__c> createFourPractices(){
		
		List<pse__Practice__c> practiceList = new List<pse__Practice__c>();
        
        practiceList.add(new pse__Practice__c(Name = 'Platform Commitment'));
        practiceList.add(new pse__Practice__c(Name = 'Program Advancement'));
        practiceList.add(new pse__Practice__c(Name = 'Project Deployment'));
        practiceList.add(new pse__Practice__c(Name = 'Solution Engagement'));
        
		INSERT practiceList;
		return practiceList;		
	}	// END: createFourPractices
    
	public static List<pse__Proj__c> getProjects(integer numOfRecords, boolean doInsert){
		
		List<pse__Proj__c> projList = new List<pse__Proj__c>();

		for(Integer i = 0; i < numOfRecords; i++) {
			String randNo = String.valueOf(Crypto.getRandomInteger());
			pse__Proj__c proj = new pse__Proj__c(	Name = 'DC ' + randNo, pse__Stage__c = 'Planning' ); 
			projList.add(proj);
		}

		if(doInsert)
		{
			INSERT projList;
		}
		return projList;		
	}	// END: getProjects

	public static List<Case> getCases(Account a, Id rtId, integer numOfRecords, boolean doInsert){
		
		List<Case> caseList = new List<Case>();

		for(Integer i = 0; i < numOfRecords; i++) {
			String randNo = String.valueOf(Crypto.getRandomInteger());
			Case c = new Case(	Subject = 'DC Case ' + randNo, Status = 'Backlog', AccountId = a.Id, RecordTypeId = rtId ); 
			caseList.add(c);
		}

		if(doInsert)
		{
			INSERT caseList;
		}
		return caseList;		
	}	// END: getCases
}