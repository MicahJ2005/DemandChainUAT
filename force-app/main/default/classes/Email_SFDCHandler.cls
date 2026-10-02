//04.08.2022	Sophia Murphy (Demand Chain)
//				updated and stripped out Account Org logic
//05.09.2022	Sophia Murphy (Demand Chain)
//				Added in logic to handle aliases
global class Email_SFDCHandler implements Messaging.InboundEmailHandler {

	private Boolean bolProcessed = false;
	private Set<String> setDisallowedEmailAddresses = new Set<String>();
	private List<Note> lstInsertNotes = new List<Note>();
	private List<FeedItem> lstInsertFeed = new List<FeedItem>();
	private Messaging.InboundEmail objEmail;
	private Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();

    global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, 
                                                         Messaging.Inboundenvelope envelope) {
                                                             
        System.debug('DC: email: ' + email);
        System.debug('DC: email.subject: ' + email.subject);
        System.debug('DC: envelope: ' + envelope);           
        System.debug('DC: envelope.toAddress: ' + envelope.toAddress); //does NOT contain the alias
        
        String aliasStr = '';
        String toAddress = '';
        for(Messaging.InboundEmail.Header key : email.headers) {
        	//header name "TO" has the email with the alias
            if(key.Name == 'To') {
                toAddress = key.Value;
            }
        }
                                                             
        if(toAddress.contains('+')) {       
            Integer positionOfPlus = toAddress.indexOf('+');
            Integer positionOfAt = toAddress.indexOf('@');
            System.debug('DC: positionOfPlus: ' + positionOfPlus);
            System.debug('DC: positionOfAt: ' + positionOfAt);
            if(positionOfPlus > 0 && positionOfAt > 0) {
                aliasStr = toAddress.mid(positionOfPlus + 1, positionOfAt - positionOfPlus - 1);
            	System.debug('DC: aliasStr: ' + aliasStr);
            }
        }    
                                                             
        if(aliasStr != '') {
            String emailAddr = aliasStr + '@demandchain.com';
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            String[] toAddresses = new String[]{}; 
            toAddresses.add(emailAddr);
            mail.setToAddresses(toAddresses);
            mail.setReplyTo(email.fromAddress);  
            mail.setSenderDisplayName(email.fromName);
            mail.setSubject(email.subject);
            mail.setPlainTextBody(email.plainTextBody);
            mail.setHtmlBody(email.htmlBody);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }
        
        return result;
	}
}
/** ORIGINAL CLASS
 * 
 * global class Email_SFDCHandler implements Messaging.InboundEmailHandler {

	private Boolean bolProcessed = false;
	private Set<String> setDisallowedEmailAddresses = new Set<String>();
	private List<Note> lstInsertNotes = new List<Note>();
	private List<FeedItem> lstInsertFeed = new List<FeedItem>();
	private Messaging.InboundEmail objEmail;
	private Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();

    global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, 
                                                         Messaging.Inboundenvelope envelope) {
    
    	objEmail = email;

    	String strSubject = email.subject;
    	String strTextBody = email.plainTextBody;
    	String strHTMLBody = email.htmlBody;
    	setDisallowedEmailAddresses.add('support@salesforce.com');
    	setDisallowedEmailAddresses.add('email@mail.salesforce.com');
    	setDisallowedEmailAddresses.add('no-reply_servicenotifications@salesforce.com');
    	setDisallowedEmailAddresses.add('SFDCNotifications@demandchainsystems.com');
    	setDisallowedEmailAddresses.add('\'SFDCNotifications@demandchainsystems.com\'');
    	setDisallowedEmailAddresses.add('SFDCNotifications@demandchain.com');
    	setDisallowedEmailAddresses.add('\'SFDCNotifications@demandchain.com\'');
		
		// Parse Body and Subject conditionality
		if(String.isNotBlank(strTextBody)) {
			strTextBody = strTextBody.replace('\n', ' ');
			strTextBody = strTextBody.replace('\r', ' ');
		} else {
			strTextBody = '';
		}

        //01.28.2019 - Look for the verification code emails right away and send them through
        //of course this didn't help - so, I , Sophia - added my email into the list. 
        if(strSubject.indexOf('Verify your identity in Salesforce') >= 0) {
            sendErrorEmail_Verification('VERIFICATION EMAIL');
            return result;
        }


		/*****************************************
			ACCOUNT SETUP
		*****************************************
		if(strSubject.indexOf('Salesforce.com password confirmation') >= 0) {
			System.Debug('ACCOUNT SETUP ACTION - PROCESSING');

			// Parse SFDC Username from body
			List<String> lstMatches = parseEmailAddresses(strTextBody);
			String strUsername = lstMatches[0];

			// Parse SFDC Action Links from body
			List<String> lstActionMatches = parseActionLink(strTextBody);

			// Find Account Orgs that this affects
			for(Account_Org__c objAO : [SELECT Id, Login_Email__c FROM Account_Org__c WHERE Username__c = :strUsername]) {

				bolProcessed = true;

				// Create Note to record
				Note objNote = new Note(ParentId=objAO.Id);
				objNote.Title = 'Processed: ' + strSubject.left(68);
				objNote.Body = email.plainTextBody; // Capture true full body, not parsed for processing
				lstInsertNotes.add(objNote);

				// Create Feed Item
				FeedItem objFeed = new FeedItem(ParentId=objAO.Id);
				objFeed.Body = 'ACTION:  Account Setup - make sure that you update the "Password" field in this Account Org when you are done!';
				objFeed.LinkUrl = lstActionMatches[0];
				lstInsertFeed.add(objFeed);
			}

			if(!lstInsertNotes.isEmpty()) { insert lstInsertNotes; }
			if(!lstInsertFeed.isEmpty()) { insert lstInsertFeed; }
		}

		/*****************************************
			PASSWORD LOCKED - CANNOT RESET
		*****************************************
		if(strSubject.indexOf('We can\'t reset your Salesforce password') >= 0) {
			System.Debug('PASSWORD LOCKED ACTION - PROCESSING');
			

			// Parse SFDC Username from body
			List<String> lstMatches = parseEmailAddresses(strTextBody);
			String strUsername = lstMatches[0];

			// Find Account Orgs that this affects
			for(Account_Org__c objAO : [SELECT Id, Login_Email__c FROM Account_Org__c WHERE Username__c = :strUsername]) {

				bolProcessed = true;

				// Create Note to record
				Note objNote = new Note(ParentId=objAO.Id);
				objNote.Title = 'Processed: ' + strSubject.left(68);
				objNote.Body = email.plainTextBody; // Capture true full body, not parsed for processing
				lstInsertNotes.add(objNote);

				// Create Feed Item
				FeedItem objFeed = new FeedItem(ParentId=objAO.Id);
				objFeed.Body = 'ACTION:  Locked Account!  Contact another administrator to get your account unlocked.';
				lstInsertFeed.add(objFeed);
			}

			if(!lstInsertNotes.isEmpty()) { insert lstInsertNotes; }
			if(!lstInsertFeed.isEmpty()) { insert lstInsertFeed; }
		}

		/*****************************************
			PASSWORD CHANGE
		*****************************************
		if(strSubject.indexOf('Finish resetting your Salesforce password') >= 0) {
			System.Debug('PASSWORD CHANGE ACTION - PROCESSING');

			// Parse SFDC Username from body
			List<String> lstMatches = parseEmailAddresses(strTextBody);
			String strUsername = lstMatches[0];

			// Parse SFDC Action Links from body
			List<String> lstActionMatches = parseActionLink(strTextBody);

			// Find Account Orgs that this affects
			for(Account_Org__c objAO : [SELECT Id, Login_Email__c FROM Account_Org__c WHERE Username__c = :strUsername]) {

				bolProcessed = true;

				// Create Note to record
				Note objNote = new Note(ParentId=objAO.Id);
				objNote.Title = 'Processed: ' + strSubject.left(68);
				objNote.Body = email.plainTextBody; // Capture true full body, not parsed for processing
				lstInsertNotes.add(objNote);

				// Create Feed Item
				FeedItem objFeed = new FeedItem(ParentId=objAO.Id);
				objFeed.Body = 'ACTION:  Confirm Password Change!  Make sure that you update the "Password" field in this Account Org when you are done!';
				objFeed.LinkUrl = lstActionMatches[0];
				lstInsertFeed.add(objFeed);
			}

			if(!lstInsertNotes.isEmpty()) { insert lstInsertNotes; }
			if(!lstInsertFeed.isEmpty()) { insert lstInsertFeed; }
		}

		/*****************************************
			ACTIVATION CODE
		*****************************************
		if(strSubject.indexOf('Your salesforce.com Activation Email') >= 0) {
			System.Debug('SECURITY CODE - PROCESSING');

			// Parse SFDC Username from body
			List<String> lstMatches = parseEmailAddresses(strTextBody);
			String strUsername = lstMatches[0];

			List<String> lstCodes = parseActivationCode(strTextBody);
			if(lstCodes.isEmpty()) {
				sendErrorEmail('ACTIVATION CODE NOT SUCCESSFULLY PARSED!');
				return result;
			}

			String strToken = lstCodes[0];

			// Find Account Orgs that this affects
			List<Account_Org__c> lstAccountOrgs = [SELECT Id, Security_Token__c FROM Account_Org__c WHERE Username__c = :strUsername];

			if(lstAccountOrgs.isEmpty()) {
				sendErrorEmail('USERNAME PARSED DOES NOT HAVE AN ACCOUNT ORG!');
				return result;
			}

			for(Account_Org__c objAO : lstAccountOrgs) {

				bolProcessed = true;

				// Create Note to record
				Note objNote = new Note(ParentId=objAO.Id);
				objNote.Title = 'Processed: ' + strSubject.left(68);
				objNote.Body = email.plainTextBody; // Capture true full body, not parsed for processing
				lstInsertNotes.add(objNote);

				// Create Feed Item
				FeedItem objFeed = new FeedItem(ParentId=objAO.Id);
				objFeed.Body = 'ACTION:  Security Code: ' + strToken;
				lstInsertFeed.add(objFeed);
			}

			if(!lstAccountOrgs.isEmpty()) {
				insert lstInsertNotes;
				insert lstInsertFeed;
			}

		}

		/*****************************************
			SECURITY TOKEN
		*****************************************
		if(strSubject.indexOf('Your new Salesforce security token') >= 0) {
			System.Debug('SECURITY TOKEN - PROCESSING');

			// Parse SFDC Username from body
			List<String> lstMatches = parseEmailAddresses(strTextBody);
			String strUsername = lstMatches[0];

			List<String> lstTokens = parseSecurityToken(strTextBody);
			if(lstTokens.isEmpty()) {
				sendErrorEmail('TOKEN NOT SUCCESSFULLY PARSED!');
				return result;
			}

			String strToken = lstTokens[0];

			// Find Account Orgs that this affects
			List<Account_Org__c> lstAccountOrgs = [SELECT Id, Security_Token__c FROM Account_Org__c WHERE Username__c = :strUsername];

			if(lstAccountOrgs.isEmpty()) {
				sendErrorEmail('USERNAME PARSED DOES NOT HAVE AN ACCOUNT ORG!');
				return result;
			}

			for(Account_Org__c objAO : lstAccountOrgs) {

				bolProcessed = true;

				// Update Token
				objAO.Security_Token__c = strToken;

				// Create Note to record
				Note objNote = new Note(ParentId=objAO.Id);
				objNote.Title = 'Processed: ' + strSubject.left(68);
				objNote.Body = email.plainTextBody; // Capture true full body, not parsed for processing
				lstInsertNotes.add(objNote);

				// Create Feed Item
				FeedItem objFeed = new FeedItem(ParentId=objAO.Id);
				objFeed.Body = 'CHANGE:  Token to ' + strToken;
				lstInsertFeed.add(objFeed);
			}

			if(!lstAccountOrgs.isEmpty()) {
				update lstAccountOrgs;
				insert lstInsertNotes;
				insert lstInsertFeed;
			}

		}

		/*****************************************
			EMAIL ADDRESS CHANGE ACTION NEEDED
		*****************************************
		if(strSubject.indexOf('Finish changing your Salesforce account’s email address') >= 0) {
			System.Debug('EMAIL CHANGE ACTION - PROCESSING');

			// Parse SFDC Username from body
			List<String> lstMatches = parseEmailAddresses(strTextBody);
			String strUsername = lstMatches[0];

			// Parse SFDC Action Links from body
			List<String> lstActionMatches = parseActionLink(strTextBody);

			System.Debug(JSON.serializePretty(lstActionMatches));

			// Find Account Orgs that this affects
			for(Account_Org__c objAO : [SELECT Id, Login_Email__c FROM Account_Org__c WHERE Username__c = :strUsername]) {

				bolProcessed = true;

				// Create Note to record
				Note objNote = new Note(ParentId=objAO.Id);
				objNote.Title = 'Processed: ' + strSubject.left(68);
				objNote.Body = email.plainTextBody; // Capture true full body, not parsed for processing
				lstInsertNotes.add(objNote);

				// Create Feed Item
				FeedItem objFeed = new FeedItem(ParentId=objAO.Id);
				objFeed.Body = 'ACTION:  Confirm Email Change!';
				objFeed.LinkUrl = lstActionMatches[0];
				lstInsertFeed.add(objFeed);
			}

			if(!lstInsertNotes.isEmpty()) { insert lstInsertNotes; }
			if(!lstInsertFeed.isEmpty()) { insert lstInsertFeed; }
		}

		/*****************************************
			EMAIL ADDRESS CHANGE CONFIRMATION
		*****************************************
		if(strSubject.indexOf('email address was changed') >= 0) {
			System.Debug('EMAIL CHANGE CONFIRMATION - PROCESSING');

			// Parse SFDC Username from body
			List<String> lstMatches = parseEmailAddresses(strTextBody);
			String strUsername = lstMatches[0];
			String strPreviousEmail = lstMatches[1];
			String strNewEmail = lstMatches[2];

			// Find Account Orgs that this affects
			List<Account_Org__c> lstAccountOrgs = [SELECT Id, Login_Email__c FROM Account_Org__c WHERE Username__c = :strUsername AND Login_Email__c = :strPreviousEmail];

			for(Account_Org__c objAO : lstAccountOrgs) {

				bolProcessed = true;
				
				// Update Email
				objAO.Login_Email__c = strNewEmail;

				// Create Note to record
				Note objNote = new Note(ParentId=objAO.Id);
				objNote.Title = 'Processed: ' + strSubject.left(68);
				objNote.Body = email.plainTextBody; // Capture true full body, not parsed for processing
				lstInsertNotes.add(objNote);

				// Create Feed Item
				FeedItem objFeed = new FeedItem(ParentId=objAO.Id);
				objFeed.Body = 'CHANGE:  Email from ' + strPreviousEmail + ' to ' + strNewEmail;
				lstInsertFeed.add(objFeed);

			}

			if(!lstAccountOrgs.isEmpty()) {
				update lstAccountOrgs;
				insert lstInsertFeed;
				insert lstInsertNotes;
			}
		}

		/*****************************************
			CATCH ALL - UNKNOWN SUBJECT, SEARCH FOR ORG
		*****************************************
		if(!bolProcessed) {

			// Search for OrgID first
			Set<String> setOrgIds = new Set<String>();

			Pattern patOrgIds = pattern.compile('[a-zA-Z0-9]{18}|[a-zA-Z0-9]{15}');
			Matcher matOrgIds = patOrgIds.matcher(strTextBody);
			if(matOrgIds.groupCount() == 0 && strHTMLBody != null) {
				matOrgIds = patOrgIds.matcher(strHTMLBody);
			}

			System.Debug(matOrgIds);
			
			while(matOrgIds.find()) {
				System.Debug('TESTING ' + matOrgIds.group());
			    if(matOrgIds.group().left(3) == '00D') {
			        setOrgIds.add(matOrgIds.group());
			    }
			}

			// Last chance - check email headers!
			if(setOrgIds.isEmpty() && objEmail.headers != null) {
				for(Messaging.InboundEmail.Header objHeader : objEmail.headers) {
					if(objHeader.Name == 'X-SFDC-LK') {
						setOrgIds.add(objHeader.value);
					}
				}
			}

			if(setOrgIds.isEmpty()) {
				sendErrorEmail('COULD NOT PARSE CATCH-ALL ORG ID');
				return result;
			}

			System.Debug('NEW OR UNKNOWN EMAIL - PROCESSING');

			// Find Account Org that this affects
			List<Account_Org__c> lstAccountOrgs = [SELECT Id FROM Account_Org__c WHERE OrgId__c IN :setOrgIds];

			for(Account_Org__c objAO : lstAccountOrgs) {

				bolProcessed = true;

				// Create Note to record
				Note objNote = new Note(ParentId=objAO.Id);
				objNote.Title = 'Processed: ' + strSubject.left(68);
				objNote.Body = email.plainTextBody; // Capture true full body, not parsed for processing
				lstInsertNotes.add(objNote);

				// Create Feed Item
				FeedItem objFeed = new FeedItem(ParentId=objAO.Id);
				objFeed.Body = 'EMAIL: ' + strSubject + '\r\n' + email.plainTextBody; // Capture true full body, not parsed for processing
				lstInsertFeed.add(objFeed);
			}

			if(!lstAccountOrgs.isEmpty()) {
				insert lstInsertFeed;
				insert lstInsertNotes;
			}

		}


		/*****************************************
			HANDLE EMAIL NOT CODED FOR
		*****************************************
		if(!bolProcessed) {
			sendErrorEmail('UNHANDLED EMAIL');
		}


		// Return Successful Result
		return result;

	}

    private void sendErrorEmail_Verification(String strReason) {
        Messaging.reserveSingleEmailCapacity(1);
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = new String[] {'passwords@demandchainsystems.com', 'sophiam@demandchain.com', 'morganp@demandchain.com', 'chrism@demandchain.com'};
        mail.setToAddresses(toAddresses);
        //I don't want reply to - in case out of office replies are on
        //mail.setReplyTo('SFDCNotifications@demandchainsystems.com');
        mail.setSenderDisplayName('DCS Automated SFDC Email Support');
        mail.setSubject('Verify your Identity in Salesforce');
        mail.setBccSender(false);
        mail.setUseSignature(false);
        if(objEmail.htmlBody == null) {
            mail.setPlainTextBody(objEmail.subject + '\r\n' + strReason + '\r\n' + objEmail.plainTextBody);
        } else {
            mail.setHTMLBody(objEmail.subject + '\r\n' + strReason + '\r\n' + objEmail.htmlBody);
        }
        
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }

	private void sendErrorEmail(String strReason) {
		Messaging.reserveSingleEmailCapacity(1);
		Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = new String[] {'passwords@demandchainsystems.com'};
		mail.setToAddresses(toAddresses);
		mail.setReplyTo('SFDCNotifications@demandchainsystems.com');
		mail.setSenderDisplayName('DCS Automated SFDC Email Support');
		mail.setSubject('Received Email that couldn\'t be parsed!');
		mail.setBccSender(false);
		mail.setUseSignature(false);
		if(objEmail.htmlBody == null) {
			mail.setPlainTextBody(objEmail.subject + '\r\n' + strReason + '\r\n' + objEmail.plainTextBody);
		} else {
			mail.setHTMLBody(objEmail.subject + '\r\n' + strReason + '\r\n' + objEmail.htmlBody);
		}
		
		Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
	}

	private List<String> parseEmailAddresses(String bodyToParse) {

		// List because dupes can exist
		List<String> lstMatches = new List<String>();

		for (String bit: bodyToParse.split(' ')) {

   			if(bit.indexOf('@') > -1 && bit.indexOf('[') == -1 && bit.indexOf('(') == -1 && !setDisallowedEmailAddresses.contains(bit)) {

				// Handle if this is hyperlink translated "email@domain.com<mailto:email@domain.com>"
				if(bit.left(1) != '<' && bit.indexOf('<mailto:') > -1) {

					String strTestHREF = bit.substring(0,bit.indexOf('<mailto:'));
					if(!setDisallowedEmailAddresses.contains(strTestHREF)) {
						lstMatches.add(strTestHREF);
					}
				}

				// Handle regularly typed emails
				if(bit.indexOf('<') == -1) {
					if(bit.endsWith('.') || bit.endsWith(',')) {
	                    lstMatches.add(bit.left(bit.length() - 1));
	                } else {
	                	lstMatches.add(bit);
	                }
				}
   			}
        }

        System.Debug(JSON.serializePretty(lstMatches));

        return lstMatches;

	}

	private List<String> parseActionLink(String bodyToParse) {

		// List because dupes can exist
		List<String> lstMatches = new List<String>();

		for (String bit: bodyToParse.split(' ')) {

			if(bit.indexOf('https://') > -1) {
				lstMatches.add(bit); 
			}

		}

		return lstMatches;

	}

	private List<String> parseSecurityToken(String bodyToParse) {

		Boolean bolFoundLeading = false;

		// List because dupes can exist
		List<String> lstMatches = new List<String>();

		for (String bit: bodyToParse.split(' ')) {

			if(bolFoundLeading) {
				lstMatches.add(bit);
				bolFoundLeading = false;
			}

			if(bit.indexOf('(case-sensitive):') > -1) {
				bolFoundLeading = true;
			}

			if(bit.indexOf('Token:') > -1) {
				bolFoundLeading = true;
			}

		}

		return lstMatches;

	}

	private List<String> parseActivationCode(String bodyToParse) {

		Boolean bolFoundLeading = false;

		// List because dupes can exist
		List<String> lstMatches = new List<String>();

		for (String bit: bodyToParse.split(' ')) {

			if(bolFoundLeading) {
				lstMatches.add(bit);
				bolFoundLeading = false;
			}

			if(bit.indexOf('Code:') > -1) {
				bolFoundLeading = true;
			}

		}

		return lstMatches;

	}
}
*/