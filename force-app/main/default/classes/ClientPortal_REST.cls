@RESTRESOURCE(URLMAPPING='/ClientPortal/*')
global class ClientPortal_REST{
	static String	CLIENT_CASEDETAIL	=	'';
	static String	CLIENT_CASELIST		=	'';
	static String	CLIENT_ORGID			= '';
	static String	CLIENT_USERID			=	'';
	
	static DCS_Response	RESPONSE	= new DCS_Response();
	
	static Map<String,Account>											MAP_ACCOUNTS			= new Map<String,Account>();
	static Map<String,List<CLIENT_SFDC_Comment__c>>	MAP_CASECOMMENTS	= new	Map<String,List<CLIENT_SFDC_Comment__c>>(); 	
	static Map<String,Case>													MAP_CLOSEDCASES		= new Map<String,Case>();
	static Map<String,Contact>											MAP_CONTACTS			= new Map<String,Contact>();	
	static Map<String,Case>													MAP_OPENCASES			= new Map<String,Case>();
	static Map<String,CLIENT_SFDC_Instance__c>			MAP_ORGIDS				= new Map<String,CLIENT_SFDC_Instance__c>();
	
	static List<String>	LIST_DEBUG	= new List<String>(); 
	
	@HTTPGET
	global static DCS_Response doGet(){
		LIST_DEBUG.add('\N\N ***** START DEBUG LOG ****** \N\N');
		
		CLIENT_ORGID			= RestContext.request.headers.get('CLIENT-OrgID');		
		CLIENT_USERID			= RestContext.request.headers.get('CLIENT-UserID');		
		CLIENT_CASEDETAIL	= RestContext.request.headers.get('DCS-CaseDetail');
		CLIENT_CASELIST		= RestContext.request.headers.get('DCS-CaseList');
		
		ProcessData();
		
		if( ValidUser() ){
			LIST_DEBUG.add(
				MAP_CONTACTS.get(CLIENT_USERID).Name +
				' IS AUTHORIZED AGAINST ' +
				MAP_ACCOUNTS.get( MAP_ORGIDS.get(CLIENT_ORGID).Account__c ).Name +
				' (' + MAP_ORGIDS.get(CLIENT_ORGID).Id__c + ')'
			);			
			ProcessCases();
		}
		else{ LIST_DEBUG.add('USER IS NOT AUTHORIZED'); }
		
		LIST_DEBUG.add('\N\N ***** END DEBUG LOG ****** ');
		
		ProcessDebug();
		
		return RESPONSE;
	}
	
	@HTTPPOST
	global static DCS_Response doPost(){
		CLIENT_ORGID			= RestContext.request.headers.get('CLIENT-OrgID');		
		CLIENT_USERID			= RestContext.request.headers.get('CLIENT-UserID');
		CLIENT_CASEDETAIL	= RestContext.request.headers.get('DCS-CaseDetail');
		system.debug(CLIENT_CASEDETAIL);		
		
		ProcessData();
		
		if( RestContext.request.headers.get('DCS-SubmitType') == 'Case' ){
			DCS_Case NEW_CASE = (DCS_Case)JSON.deserialize(RestContext.request.requestBody.toString(), DCS_Case.class);					
			Case NewClientCase = new Case();
			NewClientCase.Subject = NEW_CASE.Subject;
			NewClientCase.Description = NEW_CASE.Description;
			NewClientCase.Reason = NEW_CASE.Reason;
			NewClientCase.Origin = NEW_CASE.Origin;
			NewClientCase.Priority = NEW_CASE.Priority;
			NewClientCase.AccountId = MAP_ORGIDS.get(CLIENT_ORGID).Account__c;
			NewClientCase.Requestor__c = MAP_CONTACTS.get(CLIENT_USERID).Id;
			NewClientCase.ContactId = MAP_CONTACTS.get(CLIENT_USERID).Id;
			insert NewClientCase;
		}
		
		if( RestContext.request.headers.get('DCS-SubmitType') == 'Comment' ){
			DCS_CaseComment NEW_COMMENT = (DCS_CaseComment)JSON.deserialize(RestContext.request.requestBody.toString(), DCS_CaseComment.class);					
			CLIENT_SFDC_Comment__c NewComment = new CLIENT_SFDC_Comment__c();
			NewComment.Comment__c = NEW_COMMENT.Comment;
			NewComment.External__c = NEW_COMMENT.External;
			NewComment.IsPublic__c = NEW_COMMENT.IsPublic;
			NewComment.Account__c = MAP_ORGIDS.get(CLIENT_ORGID).Account__c;
			NewComment.Contact__c = MAP_CONTACTS.get(CLIENT_USERID).Id;
			if( MAP_OPENCASES.containsKey(CLIENT_CASEDETAIL) ){
				NewComment.Case__c = MAP_OPENCASES.get(CLIENT_CASEDETAIL).Id;
			}else if( MAP_CLOSEDCASES.containsKey(CLIENT_CASEDETAIL) ){
				NewComment.Case__c = MAP_CLOSEDCASES.get(CLIENT_CASEDETAIL).Id;
			}
			insert NewComment;
		}
		
		return null;
	}
	
	static void ProcessData(){
		
		for(CLIENT_SFDC_Instance__c SFDC_INSTANCE : [
			SELECT Account__c, ChatterEnabled__c, CustomObjects__c, CustomSettings__c, Id__c, StandardObjects__c
			FROM CLIENT_SFDC_Instance__c
			WHERE Id__c = :CLIENT_ORGID]){
				MAP_ORGIDS.put(SFDC_INSTANCE.Id__c, SFDC_INSTANCE);
				MAP_ACCOUNTS.put(SFDC_INSTANCE.Account__c,null);
		}
		if(MAP_ORGIDS.size() == 0){ LIST_DEBUG.add('CLIENT SFDC ORG IS NOT SETUP'); }
		
		for(Account SFDC_ACCOUNT : [
			SELECT Id, Name
			FROM Account
			WHERE Id IN :MAP_ACCOUNTS.keySet()]){
				MAP_ACCOUNTS.put(SFDC_ACCOUNT.Id,SFDC_ACCOUNT);
		}
		
		for(Case SFDC_CASE : [
			SELECT ClosedDate, Contact.Email, Contact.Name, Contact.Phone, CreatedBy.Name, CreatedDate, Description, Id, LastModifiedBy.Name, LastModifiedDate, CaseNumber, Origin, Owner.Email, Owner.Name, Owner.Phone, Priority, Reason, Status, Subject
			FROM Case
			WHERE AccountId IN :MAP_ACCOUNTS.keySet()]){
				if(SFDC_CASE.Status == 'Closed'){
					MAP_CASECOMMENTS.put(SFDC_CASE.Id,null);
					MAP_CLOSEDCASES.put(SFDC_CASE.Id,SFDC_CASE);					
				}else{
					MAP_CASECOMMENTS.put(SFDC_CASE.Id,null);
					MAP_OPENCASES.put(SFDC_CASE.Id,SFDC_CASE);
				}				
		}
		
		for(CLIENT_SFDC_Comment__c SFDC_CASECOMMENT : [
			SELECT Case__c, Comment__c, Contact__c, Contact__r.Name, External__c, Id, IsPublic__c, LastModifiedBy.Name, LastModifiedDate
			FROM CLIENT_SFDC_Comment__c
			WHERE (Case__c IN :MAP_OPENCASES.keySet() OR	Case__c IN :MAP_CLOSEDCASES.keySet())
			AND IsPublic__c = TRUE
			ORDER BY LastModifiedDate DESC]){
				if(MAP_CASECOMMENTS.get(SFDC_CASECOMMENT.Case__c) <> null){
					MAP_CASECOMMENTS.get(SFDC_CASECOMMENT.Case__c).add(SFDC_CASECOMMENT);
				}else{
					List<CLIENT_SFDC_Comment__c> TEMPLIST = new List<CLIENT_SFDC_Comment__c>();
					TEMPLIST.add(SFDC_CASECOMMENT);
					MAP_CASECOMMENTS.put(SFDC_CASECOMMENT.Case__c,TEMPLIST);
				}
		}
				
		for(Contact SFDC_CONTACT : [
			SELECT Id, PortalID__c, Name
			FROM Contact
			WHERE AccountId IN :MAP_ACCOUNTS.keySet()]){
				MAP_CONTACTS.put(SFDC_CONTACT.PortalID__c,SFDC_CONTACT);
		}
		
	}
	
	static Boolean ValidUser(){
		if( MAP_CONTACTS.containsKey(CLIENT_USERID) ){ return TRUE; }
		else{ return FALSE; }
	}
	
	static void ProcessCases(){		
		if(CLIENT_CASELIST == 'Open'){
			for( Case OPENCASE : MAP_OPENCASES.values() ){
				RESPONSE.Open_Cases.add( new DCS_Case(OPENCASE) );
			}
			LIST_DEBUG.add('OPEN CASES:');
			LIST_DEBUG.add('' + RESPONSE.Open_Cases);
		}else if(CLIENT_CASELIST == 'Closed'){
			for( Case CLOSEDCASE : MAP_CLOSEDCASES.values() ){
				RESPONSE.Closed_Cases.add( new DCS_Case(CLOSEDCASE) );
			}
			LIST_DEBUG.add('CLOSED CASES:');
			LIST_DEBUG.add('' + RESPONSE.Closed_Cases);
		}		
		if( MAP_CLOSEDCASES.containsKey(CLIENT_CASEDETAIL) ){
			RESPONSE.Case_Detail = new DCS_Case(MAP_CLOSEDCASES.get(CLIENT_CASEDETAIL));
			LIST_DEBUG.add('CASE DETAIL:');
			LIST_DEBUG.add('' + RESPONSE.Case_Detail);	
		}else if( MAP_OPENCASES.containsKey(CLIENT_CASEDETAIL) ){
			RESPONSE.Case_Detail = new DCS_Case(MAP_OPENCASES.get(CLIENT_CASEDETAIL));
			LIST_DEBUG.add('CASE DETAIL:');
			LIST_DEBUG.add('' + RESPONSE.Case_Detail);	
		}			
	}
	
	static void ProcessDebug(){
		String DEBUG_MSG = '';
		for(String MSG : LIST_DEBUG){ DEBUG_MSG += MSG + '\N'; }
		system.debug(DEBUG_MSG);
	} 
	
	global class DCS_Case{		
		String CreatedBy;		
		String Description;
		String Id;
		String ModifiedBy;
		Integer CaseNumber;
		String ContactEmail;
		String ContactName;
		String ContactPhone;
		String Origin;
		String OwnerEmail;
		String OwnerName;
		String OwnerPhone;
		String Priority;
		String Reason;
		String Status;		
		String Subject;		
		Datetime DateClosed;
		Datetime DateCreated;
		Datetime DateModified;		
		List<DCS_CaseComment>	Comments;
		
		global DCS_Case(Case THISCASE){			
			CreatedBy = THISCASE.CreatedBy.Name;		
			Description = THISCASE.Description;
			Id = THISCASE.Id;
			ModifiedBy = THISCASE.LastModifiedBy.Name;
			if(CaseNumber != null){ CaseNumber = Integer.valueof(THISCASE.CaseNumber); }
			ContactEmail = THISCASE.Contact.Email;
			ContactName = THISCASE.Contact.Name;
			ContactPhone = THISCASE.Contact.Phone;
			Origin = THISCASE.Origin;
			OwnerEmail = THISCASE.Owner.Email;
			OwnerName = THISCASE.Owner.Name;
			OwnerPhone = THISCASE.Owner.Phone;
			Priority = THISCASE.Priority;
			Reason = THISCASE.Reason;
			Status = THISCASE.Status;		
			Subject = THISCASE.Subject;			
			DateClosed = THISCASE.ClosedDate;
			DateCreated = THISCASE.CreatedDate;
			DateModified = THISCASE.LastModifiedDate;
			
			Comments = new List<DCS_CaseComment>();
			if(MAP_CASECOMMENTS.get(THISCASE.Id) <> null){
				for(CLIENT_SFDC_Comment__c SFDC_CASECOMMENT : MAP_CASECOMMENTS.get(THISCASE.Id)){
					Comments.add( new DCS_CaseComment(SFDC_CASECOMMENT) );
				}
			}
		}
	}
	
	global class DCS_CaseComment{
		String Comment;		
		Datetime DateModified;
		Boolean External;
		String ModifiedBy;
		Boolean IsPublic;
		
		global DCS_CaseComment(CLIENT_SFDC_Comment__c THISCOMMENT){
			Comment = THISCOMMENT.Comment__c;
			DateModified = THISCOMMENT.LastModifiedDate;
			External = THISCOMMENT.External__c;
			if(THISCOMMENT.External__c){ ModifiedBy = THISCOMMENT.Contact__r.Name; }
			else{ ModifiedBy = THISCOMMENT.LastModifiedBy.Name; }
			IsPublic = THISCOMMENT.IsPublic__c;
		} 								
	}
	
	global class DCS_Response{
		DCS_Case Case_Detail;		
		List<DCS_Case> Closed_Cases = new List<DCS_Case>();
		List<DCS_Case> Open_Cases = new List<DCS_Case>();
		String Status_Message = '';				
	}

}