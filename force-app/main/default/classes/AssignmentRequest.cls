public class AssignmentRequest {
/**
*   {Purpose}   ? Class manages the request assignment functionalty
*                
*   {Function}  ? Feeds project data to the AssignmentRequest page as well as provides page functionalty (search, query, request assignment)
*               - Ultimately creates a Task per selected project promting the FF admin to create an assignment per project for resource
*
*   CHANGE  HISTORY
*   =============================================================================
*   Date     Name             Description
*   2/11/13  KDJ              Created
*   9/10/13  KDJ              Added tasksToInsert.Clear() to requestAssgmt function
*   9/26/13  KDJ              Added ability to request assignments from milestones
*   1/4/14   KDJ              Added first generation of page pagnation
*   1/19/14  KDJ              Updated list query to better account for all projects (unassigned and old assigned)
*                             Added assignment request notification for multiple users
*   =============================================================================
**/

	public List<Contact> searchResultsContact {get; set;}
	transient public List<pse__Proj__c> searchResultsProjects {get; set;}
	public List<User> ffAdminUser = [Select Id, Email, dcs_FF_Assignment_Task_Owner__c From User Where dcs_FF_Project_Assignment_Admin__c = TRUE];  //id user(s) flagged to receive ff admin notifications
	public string uId = null;
	public string resource = null;
	public string resourceid = null;	
	public List<Task> tasksToInsert = new List<Task>();
	public List<FeedItem> feedsToInsert = new List<FeedItem>();
	public List<progAssgmtHelper> lstProjs {get; set;}
	public string paramFilterProj {get; set;}
	public string paramSearchProj {get; set;}
	public string searchText {get; set;}
	public string submittedRequest {get; set;}
	public string fullName = userinfo.getName();
	public decimal errorNum = 0;
	public decimal invalidDataEntryCount {get; set;}
	
	private integer counter=0;  //keeps track of the offset
  private integer list_size=15;  //sets the page size or number of projects displayed on the page
  public integer total_size;  //used to show user the total size of the list
  public integer totalProjMy;  //total of my projects 
  public integer totalProjAll;  //total of project not assigned me
				
  //helper class
	public class progAssgmtHelper {		
		public boolean chooseRec {get; set;}
		public boolean submittedRec {get; set;}		
		public id Id {get; set;} 
    public string Name {get; set;}
    public date startDate {get;set;}  
    public date endDate {get;set;}
    public string assignmentNote {get;set;}
    public decimal reqHours {get;set;}
    public string recType {get; set;}		
	}

	//project search flag
	public boolean projectSearch {
		get {
			if(paramSearchProj == 'Search executed'){
				projectSearch = TRUE;
			} else {
				projectSearch = FALSE;
			} 
			return projectSearch;
			}
		set;		
	}
	
	//project filtering (my vs. all) flag
	public string projectFilter {
		get {
			if(paramFilterProj == 'My'){
				projectFilter = 'My';
			} else if(paramFilterProj == 'All') {
				projectFilter = 'All';
			} else {
				projectFilter = 'My';
			}
			return projectFilter;
		}
		set;		
	}
	
	//function determining user requesting assignment.  
	//variable passed to calling method to be used in project query
	public string assignmentResource(){		
		string uId = null;				
		PageReference pageRefConst = ApexPages.currentPage();		
		uId = pageRefConst.getParameters().get('Id');
	
		System.Debug('USER ID: ' + uId);
		
		//query resource contact record using the users sfdc id
		string qryResource = 'select c.Id from Contact c where c.pse__Salesforce_User__c = :uId';		
		searchResultsContact = new List<Contact>();		
		searchResultsContact = Database.query(qryResource);		
		resourceid = searchResultsContact[0].Id; 
		
		return resourceid;		
	}	
	   	
  //constructor: populate projects
  public AssignmentRequest() {
		invalidDataEntryCount = 0;
		submittedRequest = 'Not submitted';
		projectFilter = 'My';
		resource = assignmentResource();  //determine user requesting assignment
		
		totalProjMy = [Select count() 
								   From pse__Proj__c p 
								   Where p.pse__Is_Active__c = TRUE 
								   and p.Id in (Select pa.pse__Project__c 
								                From pse__Assignment__c pa 
								                Where pa.pse__Resource__c = :resource)];
		
		totalProjAll = [Select count()
								              From pse__Proj__c p
								              Where p.pse__Is_Active__c = TRUE 
								              and p.Id not in (Select pa.pse__Project__c 
								                               From pse__Assignment__c pa
								                               Where pa.pse__Resource__c = :resource)];	
		
		total_size = totalProjMy;  //initial page load defaults to 'my' data view
		
		getlstProjs();		
	}
	
	//filter 'my' and 'not my' project links 
	public void AssignmentSearch(){
		counter = 0;
		getlstProjs();		
	}
	
	public List<progAssgmtHelper> getlstProjs(){
		
		resource = assignmentResource();  //determine user requesting assignment		
		invalidDataEntryCount = 0;  //ensure variable is reset so that page renders with correct information

		lstProjs = new List<progAssgmtHelper>();  //clear list
		
		searchResultsProjects = new List<pse__Proj__c>();		

		if(projectFilter=='All'){
			//run two queries due to limitation that an or operator cannot be run when using subqueries in a where clause
			total_size = totalProjAll;
			System.Debug('TOTAL SIZE ALL: ' + searchResultsProjects.size());
      System.Debug('LIST SIZE ALL: ' + searchResultsProjects.size());
			searchResultsProjects = [Select p.Id, 
			                                p.Name, 
			                                (Select pm.id, 
			                                        pm.Name,
			                                        pm.pse__Project__r.Name
			                                 From pse__Milestones__r pm)
			                                From pse__Proj__c p
			                                where p.pse__Is_Active__c = TRUE 
			                                and p.Id not in (Select pa.pse__Project__c 
			                                                 From pse__Assignment__c pa
			                                                 Where pa.pse__Resource__c = :resource) 
			                                order by p.Name
			                                limit :list_size 
                                      offset :counter];      
			//System.Debug('SEARCHRESULTPROJECTS-NOT MINE IN IF: ' + searchResultsProjects.size());
		} else {
			total_size = totalProjMy;
			System.Debug('TOTAL SIZE MY: ' + searchResultsProjects.size());
      System.Debug('LIST SIZE MY: ' + searchResultsProjects.size()); 
			searchResultsProjects = [Select p.Id, 
			                                p.Name, 
			                                (Select pm.id, 
			                                        pm.Name,
			                                        pm.pse__Project__r.Name
			                                 From pse__Milestones__r pm) 
			                                From pse__Proj__c p 
			                                Where p.pse__Is_Active__c = TRUE 
			                                and p.Id in (Select pa.pse__Project__c 
			                                             From pse__Assignment__c pa 
			                                             Where pa.pse__Resource__c = :resource) 
			                                order by p.Name
			                                limit :list_size 
                                      offset :counter];
			//System.Debug('SEARCHRESULTPROJECTS-MINE IN IF: ' + searchResultsProjects.size());
		}
			
		for(pse__Proj__c pr : searchResultsProjects) {					
			 progAssgmtHelper pah = new progAssgmtHelper();
	       pah.Id = pr.Id;
	       pah.Name = pr.Name;
	       pah.recType = 'Project';      
       
         lstProjs.add(pah);
       
       for(pse__Milestone__c prm : pr.pse__Milestones__r){
           pah = new progAssgmtHelper();               
	           pah.Id = prm.Id;
	           pah.Name = prm.pse__Project__r.Name + '-' + prm.Name;  
	           pah.recType = 'Milestone';    
	           
	           lstProjs.add(pah);
       }        	
        	System.Debug('PROJECT LIST VALUES: ' + pah);    	
    	}  //end of loop	
    	//System.Debug('total_size: ' + total_size); 
    	return lstProjs;
	}  //end of filtered search method	
   	
  // project search button
	public void searchProjs(){	

		invalidDataEntryCount = 0;  //ensure variable is reset so that page renders with correct information

		if (searchResultsProjects == null) {
			searchResultsProjects = new List<pse__Proj__c>();  // init the list if it is null
		} else {
			searchResultsProjects.clear();
		}
		
		lstProjs = new List<progAssgmtHelper>();  //clear list
	
		//query all projects regardless if the user is assigned to it or not
		String qry = 'Select Id, Name, (Select pm.id, pm.Name, pse__Project__r.Name From pse__Milestones__r pm) From pse__Proj__c Where pse__Is_Active__c = TRUE and Name LIKE \'%'+searchText+'%\' Order By Name';
    searchResultsProjects = Database.query(qry);
	
		System.Debug('PROJECTSEARCHRESULT: ' + searchResultsProjects.size());
		
		for(pse__Proj__c pr : searchResultsProjects) {
					
			progAssgmtHelper pah = new progAssgmtHelper();
         pah.Id = pr.Id;
         pah.Name = pr.Name;
         pah.recType = 'Project';        
             
       lstProjs.add(pah);
       
       for(pse__Milestone__c prm : pr.pse__Milestones__r){
           pah = new progAssgmtHelper();               
           pah.Id = prm.Id;
           pah.Name = prm.pse__Project__r.Name + '-' + prm.Name;  
           pah.recType = 'Milestone';    
            
           lstProjs.add(pah);
       }        	
      //System.Debug('PROJECT LIST VALUES: ' + pah);   			
    	}  //end of for loop    	
    	//System.debug('PARAMSEARCHPROJ' + paramSearchProj);  
	}  //end of search method
  
   public PageReference Beginning() { //user clicked beginning
      counter = 0;
      getlstProjs();
      return null;
   }
  
   public PageReference Previous() { //user clicked previous button
      counter -= list_size;
      getlstProjs();
      return null;
   }
 
   public PageReference Next() { //user clicked next button
      counter += list_size;
      getlstProjs();
      return null;
   }
   
   public PageReference End() { //user clicked end
      counter = total_size - math.mod(total_size, list_size);
      getlstProjs();
      return null;
   }
   
   public Boolean getDisablePrevious() { //this will disable the previous and beginning buttons
      if (counter>0) return false; else return true;
   }
 
   public Boolean getDisableNext() { //this will disable the next and end buttons
      if (counter + list_size < total_size) return false; else return true;
   }
 
   public Integer getTotal_size() {
      return total_size;
   }
 
   public Integer getPageNumber() {
      return counter/list_size + 1;
   }
 
   public Integer getTotalPages() {
      if (math.mod(total_size, list_size) > 0) {
         return total_size/list_size + 1;
      } else if (total_size == 0){
      	 return 1;
      } else {
         return (total_size/list_size);
      }
   }  
   	
  //cancel button
  public PageReference cancel() {
   	PageReference pgRef = new PageReference('/home/home.jsp');
    pgRef.setRedirect(true);
    return pgRef;
  }
    
  //clear button
  public void clear() {    	
    paramFilterProj = 'My';
    paramSearchProj = null;
    invalidDataEntryCount = 0;
    searchText = null;
    submittedRequest = 'Not submitted';
    	
    AssignmentSearch();
  }

	//request assignment button
	public void requestAssgmt() {	
		
		System.Debug('PROJECT LIST: ' + lstProjs);				
		
		tasksToInsert.Clear();  //ensure task to insert list and feed to inser list is cleared each time the request button is selected
		//feedsToInsert.Clear();  //leave in for now...may want to augment feed functionality later
		invalidDataEntryCount = 0;
		submittedRequest = 'Not submitted';		
		
		for(progAssgmtHelper pa : lstProjs){
			
			System.Debug('SELECT FLAG: ' + pa.chooseRec);
			
			if(pa.chooseRec == TRUE){
				if(pa.reqHours != NULL && 
				   pa.startDate != NULL && 
				   pa.endDate != NULL){
					
					Integer startMth = pa.startDate.month();
					Integer startDay = pa.startDate.day();
					Integer startYr = pa.startDate.year();
					Integer endMth = pa.endDate.month();
					Integer endDay = pa.endDate.day();
					Integer endYr = pa.endDate.year();
					String assgmtNotes = null;
					
					if(pa.assignmentNote == null){
						assgmtNotes = 'n/a';
					} else {
						assgmtNotes = pa.assignmentNote;
					}
					
					String assignee = null;  //project assignment task assignee
      
		      for(User u : ffAdminUser){   
		        if(u.dcs_FF_Assignment_Task_Owner__c == TRUE){
		        	assignee = u.Id;  //should be only one user designated as task assignee
		        } else {
		        	assignee = u.Id;  //if no user flagged assign to last ffadmin
		        }		          
		      }					
										
					Task tsk = new Task();
						tsk.CurrencyIsoCode = 'USD';
						tsk.OwnerId = assignee; //ffAdminUser[0].Id;  //grab first (should be only) userid from query pulling ff admin - VALIDATE PROCESS / ASSUMPTIONS INTERNALLY
						tsk.Status = 'Not Started';
						tsk.WhatId = pa.Id;
						tsk.Priority = 'Normal';
						tsk.ActivityDate = pa.startDate;
						tsk.Subject = 'Assignment Request: ' + fullName + ' - '+ startMth + '/' + startDay + '/' + startYr;
						tsk.Project_Assignment_Details__c = 'Start Date: ' + startMth + '/' + startDay + '/' + startYr + '\r\n';
						tsk.Project_Assignment_Details__c += 'End Date: ' + endMth + '/' + endDay + '/' + endYr + '\r\n';
						tsk.Project_Assignment_Details__c += 'Requested Hours: ' + pa.reqHours + '\r\n';
						tsk.Project_Assignment_Details__c += 'Asignment Notes: ' + assgmtNotes;						
						
						system.debug('TASK: ' + tsk);						
						
						tasksToInsert.add(tsk);
					/* leave in for now...may want to augment feed functionality later
					//insert chatter feed post at project	
				  FeedItem feedProj = new FeedItem();
            feedProj.ParentId = pa.Id;
            feedProj.Body = tsk.Project_Assignment_Details__c;
            feedProj.Title = tsk.Subject;
          
            feedsToInsert.add(feedProj);
					*/	
						system.debug('TASK INSERT SIZE: ' + tasksToInsert.size());
						system.debug('FEED INSERT SIZE: ' + feedsToInsert.size());
										
				} else {
				
					invalidDataEntryCount += 1;  //track number of invalid record entries on request page
				
					system.debug('INVALID DATA ENTRY COUNT: ' + invalidDataEntryCount);
				
				}  //end of data validation if statement
			}  //end of select flag if statement			
		}  //end of for loop
		
		//check to see if any requests are invalid in respects to data entry.  
		//if invalid entries exist clear the insert list and prompt user.  list will be rebuilt upon new request.
		if(invalidDataEntryCount > 0){
			tasksToInsert.Clear();
			//feedsToInsert.Clear();
		}

		//insert project tasks
		try{
			
			if(tasksToInsert.size() > 0 && invalidDataEntryCount == 0) insert tasksToInsert;
		
		} catch(DmlException e) {  //catch errors				
				
   			for (Task projTasks : tasksToInsert) {
            	projTasks.addError(' Assignment Request Task Not Inserted: ' + e.getMessage());
     		}
     		
     		errorNum = e.getNumDml();  //number of insert errors
     		
		}		
		
		//notify user and email admin of submitted assignment request(s)		
		System.Debug('TASKS TO INSERT: ' + tasksToInsert.size());
		System.Debug('NUM OF INSERT ERRORS: ' + errorNum);
	
		if(tasksToInsert.size() > 0 && errorNum == 0){
			
			submittedRequest = 'Submitted';							
      
      String serverURL = URL.getSalesforceBaseUrl().toExternalForm();	
		  List<String> addressee = new List<String>();  //list of email addressees
			
			for(User u : ffAdminUser){  //add ffadmin address to email list		
				addressee.add(u.Email);		
			}	    

			Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
			mail.setToAddresses(addressee);
			mail.setSubject('Assignment Submitted for ' + fullName);
			mail.setHTMLBody('Please refer the My Tasks section on the Home tab if you are designated as the Assignment Task owner for assignment details.' +
												'<br><br>' +
                       'For all others please see the report <a href="' + serverURl + '/00O0000000A55Do">PENDING PROJECT ASSIGNMENTS</a> for assignment details.');
			mail.setPlainTextBody('Please refer the My Tasks section on the Home tab if you are designated as the Assignment Task owner for assignment details.' + '\r\n' + '\r\n' +
			                      'For all others please see the report PENDING PROJECT ASSIGNMENTS for assignment details.');
			Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
		}  //end of email if		
	}  // end of requestAssgmt function	
}  //end of class