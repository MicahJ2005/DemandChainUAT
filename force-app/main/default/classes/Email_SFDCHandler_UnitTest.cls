//05.09.2022	Sophia Murphy (Demand Chain)
//				Updated to reflect changes to the Email_SFDCHandler
@isTest
private class Email_SFDCHandler_UnitTest {

	@isTest static void unitTest() {
		
		String strEmailSubject = 'Alias Test Email';
		String strEmailBody = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse elit leo, tristique at libero nec, varius pulvinar dolor.';
		
		Messaging.InboundEmail objEmail = new Messaging.InboundEmail() ;
		Messaging.InboundEnvelope objEnv = new Messaging.InboundEnvelope();
       	
		objEmail.subject = strEmailSubject;
  		objEmail.fromAddress = 'support@salesforce.com';
  		objEmail.plainTextBody = strEmailBody;
        
        Messaging.InboundEmail.Header hditem = new Messaging.InboundEmail.Header();
        objEmail.headers = new Messaging.InboundEmail.Header[1];
        hditem.name = 'To'; 
        hditem.value = 'helloworld+sophiam@demandchain.com'; 
        objEmail.headers[0] = hditem;

  		Email_SFDCHandler clsTestInbound = new Email_SFDCHandler();
  		clsTestInbound.handleInboundEmail(objEmail, objEnv);
	}
	
}
/** ORIGINAL CODE
 * @isTest
private class Email_SFDCHandler_UnitTest {

	private static String strOrgId = '00D000000000000';
	private static String strUsername = 'me@you.com';
	private static String strPreviousEmail = 'old@email.com';
	private static String strNewEmail = 'new@email.com';

	@testSetup static void setupData() {

		Account objAcct = new Account(Name='Test Account');
		insert objAcct;

		Contact objCont = new Contact(
			AccountId=objAcct.Id,
			LastName='LastName',
			FirstName='FirstName',
			Email=strPreviousEmail
		);
		insert objCont;

		Account_Org__c objAO = new Account_Org__c(
			Account__c=objAcct.Id,
			Name='Production Test Org',
			Org_Type__c='Production',
			Primary_DCS_Contact__c=UserInfo.getUserId(),
			Org_Edition__c='UE/PXE',
			OrgID__c = strOrgId,
			Username__c = strUsername,
			Password__c = '1234567890',
			Login_Email__c = strPreviousEmail
		);
		insert objAO;

	}
	
	@isTest static void emailActivationCode() {
		
		String strEmailSubject = 'Your salesforce.com Activation Email';
		String strEmailBody = 'Dear ' + strUsername + ', You have requested access to salesforce.com from an unknown device. Browser: Firefox Operating System: Windows 7 ';
		strEmailBody+= 'Use the verification code below within 24 hours to activate this device. Verification Code: 14412 IMPORTANT: If you have not requested to activate a ';
		strEmailBody+= 'device, or believe you have received this message in error, please contact salesforce.com support (support@salesforce.com) immediately. What does ';
		strEmailBody+= '"activation" mean? Should I activate this computer? Activation helps reduce the risk of security issues related to login. Activating this computer ';
		strEmailBody+= 'helps salesforce.com recognize this computer when you use it to access salesforce.com. You should activate this computer if it is owned by you or your ';
		strEmailBody+= 'employer and you are confident it is free of malware.';

		Messaging.InboundEmail objEmail = new Messaging.InboundEmail() ;
		Messaging.InboundEnvelope objEnv = new Messaging.InboundEnvelope();

		objEmail.subject = strEmailSubject;
  		objEmail.fromAddress = 'support@salesforce.com';
  		objEmail.plainTextBody = strEmailBody;

  		Email_SFDCHandler clsTestInbound = new Email_SFDCHandler();
  		clsTestInbound.handleInboundEmail(objEmail, objEnv);

  		List<FeedItem> lstAssertFeed = [SELECT Id FROM FeedItem];
  		System.Assert(lstAssertFeed.size() == 1, 'Not the right number of FeedItems');

  		List<Note> lstAssertNotes = [SELECT Id FROM Note];
  		System.Assert(lstAssertNotes.size() == 1, 'Not the right number of Notes');

	}
	
	@isTest static void emailSecurityToken() {
		
		String strEmailSubject = 'Your new Salesforce security token';
		String strEmailBody = 'We\'ve sent you a new Salesforce security token because you recently changed your password or requested to reset your security token. Use this ';
		strEmailBody+= 'updated security token with API or desktop clients that require it. Username: ' + strUsername + ' Security token (case-sensitive): ';
		strEmailBody+= 'AOamn7OAln7rt2lpJlMm5CjZr For more information on using your security token, see Reset Your Security Token at ';
		strEmailBody+= ' https://help.salesforce.com/HTViewHelpDoc?id=user_security_token.htm.';

		Messaging.InboundEmail objEmail = new Messaging.InboundEmail() ;
		Messaging.InboundEnvelope objEnv = new Messaging.InboundEnvelope();

		objEmail.subject = strEmailSubject;
  		objEmail.fromAddress = 'support@salesforce.com';
  		objEmail.plainTextBody = strEmailBody;

  		Email_SFDCHandler clsTestInbound = new Email_SFDCHandler();
  		clsTestInbound.handleInboundEmail(objEmail, objEnv);

  		List<FeedItem> lstAssertFeed = [SELECT Id FROM FeedItem];
  		System.Assert(lstAssertFeed.size() == 1, 'Not the right number of FeedItems');

  		List<Note> lstAssertNotes = [SELECT Id FROM Note];
  		System.Assert(lstAssertNotes.size() == 1, 'Not the right number of Notes');

	}

	@isTest static void emailActionEmailChange() {
		
		String strEmailSubject = 'Finish changing your Salesforce account’s email address';
		String strEmailBody = 'We recently received a request to change your Salesforce account’s email address for username ' + strUsername + '. Previous email address: ';
		strEmailBody+= strNewEmail + ' New email address: ' + strNewEmail + ' To finish changing your email address, go to the following ';
		strEmailBody+= 'link. This link expires in 72 hours. https://abc.com/unittestverifylink/godrinksomewhiskey If you can\'t click the link, copy and paste it into ';
		strEmailBody+= 'your Web browser. If you have questions, contact your Salesforce administrator.';

		Messaging.InboundEmail objEmail = new Messaging.InboundEmail() ;
		Messaging.InboundEnvelope objEnv = new Messaging.InboundEnvelope();

		objEmail.subject = strEmailSubject;
  		objEmail.fromAddress = 'support@salesforce.com';
  		objEmail.plainTextBody = strEmailBody;

  		Email_SFDCHandler clsTestInbound = new Email_SFDCHandler();
  		clsTestInbound.handleInboundEmail(objEmail, objEnv);

  		List<FeedItem> lstAssertFeed = [SELECT Id FROM FeedItem];
  		System.Assert(lstAssertFeed.size() == 1, 'Not the right number of FeedItems');

  		List<Note> lstAssertNotes = [SELECT Id FROM Note];
  		System.Assert(lstAssertNotes.size() == 1, 'Not the right number of Notes');

	}

	@isTest static void emailActionEmailConfirm() {
		
		String strEmailSubject = 'email address was changed';
		String strEmailBody = 'We recently received a request to change your Salesforce account’s email address for username ' + strUsername + '. ';
		strEmailBody+= 'Previous email address: ' + strPreviousEmail + ' New email address: ' + strNewEmail + ' ';
		strEmailBody+= 'If you didn’t request this change, contact your Salesforce administrator.';


		Messaging.InboundEmail objEmail = new Messaging.InboundEmail() ;
		Messaging.InboundEnvelope objEnv = new Messaging.InboundEnvelope();

		objEmail.subject = strEmailSubject;
  		objEmail.fromAddress = 'support@salesforce.com';
  		objEmail.plainTextBody = strEmailBody;

  		Email_SFDCHandler clsTestInbound = new Email_SFDCHandler();
  		clsTestInbound.handleInboundEmail(objEmail, objEnv);

  		Account_Org__c objAO = [SELECT Id, Login_Email__c FROM Account_Org__c LIMIT 1];
  		System.AssertNotEquals(objAO, null, 'Did not find the right Contact!');
  		System.assertEquals(objAO.Login_Email__c, strNewEmail, 'Email Addresses did not get updated correctly!');

  		List<FeedItem> lstAssertFeed = [SELECT Id FROM FeedItem];
  		System.Assert(lstAssertFeed.size() == 1, 'Not the right number of FeedItems');

  		List<Note> lstAssertNotes = [SELECT Id FROM Note];
  		System.Assert(lstAssertNotes.size() == 1, 'Not the right number of Notes');

	}

	@isTest static void emailOtherOrgIdSearch() {

		String strEmailSubject = 'Rando Email';
		String strEmailBody = 'This could be any email, most of the ones we care about have the OrgId ' + strOrgId + '. ';

		Messaging.InboundEmail objEmail = new Messaging.InboundEmail() ;
		Messaging.InboundEnvelope objEnv = new Messaging.InboundEnvelope();

		objEmail.subject = strEmailSubject;
  		objEmail.fromAddress = 'support@salesforce.com';
  		objEmail.plainTextBody = strEmailBody;

  		Email_SFDCHandler clsTestInbound = new Email_SFDCHandler();
  		clsTestInbound.handleInboundEmail(objEmail, objEnv);

  		List<FeedItem> lstAssertFeed = [SELECT Id FROM FeedItem];
  		System.Assert(lstAssertFeed.size() == 1, 'Not the right number of FeedItems');

  		List<Note> lstAssertNotes = [SELECT Id FROM Note];
  		System.Assert(lstAssertNotes.size() == 1, 'Not the right number of Notes');

	}

	@isTest static void emailUnhandledEmailPassThrough() {

		String strEmailSubject = 'Rando Email';
		String strEmailBody = 'Any random email that we can\'t find any identifying info on';

		Messaging.InboundEmail objEmail = new Messaging.InboundEmail() ;
		Messaging.InboundEnvelope objEnv = new Messaging.InboundEnvelope();

		objEmail.subject = strEmailSubject;
  		objEmail.fromAddress = 'support@salesforce.com';
  		objEmail.plainTextBody = strEmailBody;

  		Email_SFDCHandler clsTestInbound = new Email_SFDCHandler();
  		clsTestInbound.handleInboundEmail(objEmail, objEnv);

  		List<FeedItem> lstAssertFeed = [SELECT Id FROM FeedItem];
  		System.Assert(lstAssertFeed.size() == 0, 'Not the right number of FeedItems');

  		List<Note> lstAssertNotes = [SELECT Id FROM Note];
  		System.Assert(lstAssertNotes.size() == 0, 'Not the right number of Notes');

	}

	@isTest static void emailResetPassword() {

		String strEmailSubject = 'Finish resetting your Salesforce password';
		String strEmailBody = 'Your Salesforce administrator recently reset the password for the username ' + strUsername + '. To finish resetting your password, ';
		strEmailBody+= 'go to the following link. https://test.salesforce.com/BLAHBLAHBLAH If you didn\'t ask for your password to be reset, contact your ';
		strEmailBody+= 'Salesforce administrator: hotmom@chris.com.';

		Messaging.InboundEmail objEmail = new Messaging.InboundEmail() ;
		Messaging.InboundEnvelope objEnv = new Messaging.InboundEnvelope();

		objEmail.subject = strEmailSubject;
  		objEmail.fromAddress = 'support@salesforce.com';
  		objEmail.plainTextBody = strEmailBody;

  		Email_SFDCHandler clsTestInbound = new Email_SFDCHandler();
  		clsTestInbound.handleInboundEmail(objEmail, objEnv);

  		List<FeedItem> lstAssertFeed = [SELECT Id FROM FeedItem];
  		System.Assert(lstAssertFeed.size() == 1, 'Not the right number of FeedItems');

  		List<Note> lstAssertNotes = [SELECT Id FROM Note];
  		System.Assert(lstAssertNotes.size() == 1, 'Not the right number of Notes');

	}

	@isTest static void emailLockedAccount() {

		String strEmailSubject = 'We can\'t reset your Salesforce password';
		String strEmailBody = 'We recently received a request to reset the Salesforce password for the username ' + strUsername + '. We can\'t reset your password ';
		strEmailBody+= 'because your account is locked due to too many unsuccessful login attempts.  To re-enable your account, try the following: Contact your ';
		strEmailBody+= 'company\'s administrator for assistance. If you didn\'t ask for your password to be reset, contact your Salesforce administrator.';

		Messaging.InboundEmail objEmail = new Messaging.InboundEmail() ;
		Messaging.InboundEnvelope objEnv = new Messaging.InboundEnvelope();

		objEmail.subject = strEmailSubject;
  		objEmail.fromAddress = 'support@salesforce.com';
  		objEmail.plainTextBody = strEmailBody;

  		Email_SFDCHandler clsTestInbound = new Email_SFDCHandler();
  		clsTestInbound.handleInboundEmail(objEmail, objEnv);

  		List<FeedItem> lstAssertFeed = [SELECT Id FROM FeedItem];
  		System.Assert(lstAssertFeed.size() == 1, 'Not the right number of FeedItems');

  		List<Note> lstAssertNotes = [SELECT Id FROM Note];
  		System.Assert(lstAssertNotes.size() == 1, 'Not the right number of Notes');

	}
	
	@isTest static void emailNewAccount() {

		String strEmailSubject = 'Salesforce.com password confirmation';
		String strEmailBody = 'Your Login Is Enclosed. Dear Andy Boettcher, Welcome to Salesforce! Your user name and temporary password are below: User Name: ' + strUserName + ' ';
		strEmailBody+= 'Password: Set the first time you login Log in automatically by clicking https://test.salesforce.com/TESTTESTTEST If you experience problems ';
		strEmailBody+= 'with the above link, please contact your salesforce.com administrator for assistance. You\'ll be asked to choose a password when you first ';
		strEmailBody+= 'log in. Note that passwords are case sensitive. Make sure to choose a password question and answer that you will easily remember since you will ';
		strEmailBody+= 'use this information in the future should you forget your password. Any administrator in your organization can reset your password. Please keep ';
		strEmailBody+= 'this email for future reference should you have any password problems. Once again, welcome to Salesforce. salesforce.com The Landmark @ One Market, ';
		strEmailBody+= 'Suite 300 San Francisco, CA 94105 Phone: (415) 901-7000 Fax: (415) 901-7040 http://www.salesforce.com/us/';

		Messaging.InboundEmail objEmail = new Messaging.InboundEmail() ;
		Messaging.InboundEnvelope objEnv = new Messaging.InboundEnvelope();

		objEmail.subject = strEmailSubject;
  		objEmail.fromAddress = 'support@salesforce.com';
  		objEmail.plainTextBody = strEmailBody;

  		Email_SFDCHandler clsTestInbound = new Email_SFDCHandler();
  		clsTestInbound.handleInboundEmail(objEmail, objEnv);

  		List<FeedItem> lstAssertFeed = [SELECT Id FROM FeedItem];
  		System.Assert(lstAssertFeed.size() == 1, 'Not the right number of FeedItems');

  		List<Note> lstAssertNotes = [SELECT Id FROM Note];
  		System.Assert(lstAssertNotes.size() == 1, 'Not the right number of Notes');

	}
}*/