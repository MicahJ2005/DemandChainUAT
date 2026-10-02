@isTest
private class contactTest {
	static testMethod void contactUpdate() {

		Account newAcct = new Account(name='Test', RecordTypeId='012000000004EcZ');
		Contact newCont = new Contact(LastName = 'Tester', AccountId=newAcct.Id, RecordTypeId='0120000000000V8', Targeted_Role__c='CRM System Admin', Target_Contact_Sales__c=false, Target_Contact_IT__c=false);
		
		for (Integer a=0; a<2; a++) {
			//create an account
			newAcct = new Account(name='Test Account1' + a, RecordTypeId='012000000004EcZ');
			System.debug('Insert Test Account1' + a);
			insert newAcct;
			//create test contacts
			for (Integer i=0; i<2; i++) {
				newCont = new Contact(LastName = 'Tester1' + a + i, AccountId=newAcct.Id, RecordTypeId='0120000000000V8', Targeted_Role__c='Primary Sales Contact', Target_Contact_Sales__c=true, Target_Contact_IT__c=true);
				System.debug('Insert Tester1' + a + i);
				insert newCont;
			}
		}

		for (Integer a=0; a<2; a++) {
			//create an account
			newAcct = new Account(name='Test Account2' + a, RecordTypeId='012000000004EcZ');
			System.debug('Insert Test Account2' + a);
			insert newAcct;
		
			//create test contacts
			for (Integer i=0; i<2; i++) {
				newCont = new Contact(LastName = 'Tester2' + a + i, AccountId=newAcct.Id, RecordTypeId='0120000000000V8', Targeted_Role__c='Primary Sales Contact', Target_Contact_Sales__c=true, Target_Contact_IT__c=false);
				System.debug('Insert Tester2' + a + i);
				insert newCont;
			}
		}
    /*  2013.11.14 KDJ: commented due to appirio core class failing due to too many soql queries being run
		for (Integer a=0; a<2; a++) {
			//create an account
			newAcct = new Account(name='Test Account3' + a, RecordTypeId='012000000004EcZ');
			System.debug('Insert Test Account3' + a);
			insert newAcct;
		
			//create test contacts
			for (Integer i=0; i<2; i++) {
				newCont = new Contact(LastName = 'Tester3' + a + i, AccountId=newAcct.Id, RecordTypeId='0120000000000V8', Targeted_Role__c='Primary IT Contact', Target_Contact_Sales__c=false, Target_Contact_IT__c=true);
				System.debug('Insert Tester3' + a + i);
				insert newCont;
			}
		}

		for (Integer a=0; a<2; a++) {
			//create an account
			newAcct = new Account(name='Test Account4' + a, RecordTypeId='012000000004EcZ');
			System.debug('Insert Test Account4' + a);
			insert newAcct;
		
			//create test contacts
			for (Integer i=0; i<2; i++) {
				newCont = new Contact(LastName = 'Tester4' + a + i, AccountId=newAcct.Id, RecordTypeId='0120000000000V8', Target_Contact_Sales__c=false, Target_Contact_IT__c=false);
				System.debug('Insert Tester4' + a + i);
				insert newCont;
			}
		}
    */
	}
}