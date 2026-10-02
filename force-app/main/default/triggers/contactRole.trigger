trigger contactRole on Contact (after Update, after Insert, after delete){
    
    /////////////////////////////////////////////////////////////////////////// 
    /// Step 1 - Get all the accounts associated with the
    /// contacts that are being updated
    /////////////////////////////////////////////////////////////////////////// 
    
    List<Id> accountIds = new List<Id>();
     List<Id> accountIds2Skip = new List<Id>();
  //  Set<Id> eventOwnerIds = new Set<Id>();
    
    if (Trigger.isDelete) {
    
        for (Contact cont : Trigger.old) { 
            accountIds.add(cont.AccountId);
        }
    
    } else {
                
        for (Contact cont : Trigger.new) { 
            accountIds.add(cont.AccountId);
        }

    }
    System.debug('accountIds.count: ' + accountIds.size());
    
    /////////////////////////////////////////////////////////////////////////// 
    /// Step 2 - Get all of the contacts associated with all of those accounts
    /////////////////////////////////////////////////////////////////////////// 
    
    List<Contact> allContacts = new List<Contact>();
     
    if(accountIds.size() > 0 ) {
        
        allContacts = ([select Id,Targeted_Role__c, AccountId from Contact where AccountId in :accountIds]);    
        
    }
    
    Map<Id, Account> allAccounts = new Map<Id, Account> ([select Id,Date_DCS_Key_Contact_Roles_Identified__c,DCS_Key_Contact_Roles_Identified__c from Account where Id in :accountIds]);
        
    /////////////////////////////////////////////////////////////////////////// 
    /// Loop through each account and check to see if there are contacts there
    /// where "Targeted_Role__c" -> Multiselect picklist
    /// one contact -> "Primary IT Contact" &&
    /// one contact -> "Primary Business Contact"
    /// if this is true then 
    ///
    /// Date_DCS_Key_Contact_Roles_Identified__c -> The date it was identified
    /// DCS_Key_Contact_Roles_Identified__c -> Check to true
    /// 
    /// else 
    /// 
    /// null out those 2 fields
    /////////////////////////////////////////////////////////////////////////// 
    
    List<Account> accounts2Update = new List<Account>();
    
    if(accountIds.size() > 0 ) { // A
        
        for (Integer j = 0; j < accountIds.size(); j++) { // B
           
           Boolean skip = false;
           
           for (Integer jm = 0; jm < accountIds2Skip.size(); jm++) { // B
           	
           		if(accountIds2Skip[jm] == accountIds[j]) {skip = true;}
           }
           
           if(!skip) {
            
            System.debug('Working on accounId: ' + accountIds[j]);
            
            Boolean primaryIt = false;
            Boolean primaryBusinessContact = false;
            
            /// Here need to loop through all accounts 
            /// and all contacts related to that account
            
            List<String> targetedRoles = new List<String>();
            
            for (Integer jk = 0; jk < allContacts.size(); jk++) { // C
                
                if(allContacts[jk].AccountId == accountIds[j]) { // D
                    
                    System.debug('Match!');
                    System.debug('Contact : ' + allContacts[jk].Targeted_Role__c);
                    
                    /// allContacts[jk].Targeted_Role__c) is a multi-select picklist 
                    /// will be seperated by ";"
                    
                    String targetedRole = allContacts[jk].Targeted_Role__c;

                    if(allContacts[jk].Targeted_Role__c != null) { // E
                    
                        if(targetedRole.contains(';')) { // F
                        
                            /// The multi-select has multiple vlaues
                            targetedRoles =  targetedRole.split(';',0);
                            
                        } else { // F
                            
                            // There is just one or no values
                            targetedRoles.add(targetedRole);
                            
                        } // EOF F
                    } // EOF E
                
                //    System.debug('targetedRoles.size(): ' + targetedRoles.size());
                
                    // Now loop through all the targetedRoles to see if the 
                    // 2 are there
                    
                    for (Integer jl = 0; jl < targetedRoles.size(); jl++) {// G

                        if(targetedRoles[jl] == 'Primary IT Contact') { primaryIt = true;}
                        if(targetedRoles[jl] == 'Primary Business Contact') {primaryBusinessContact = true;}
                        
                    }// EOF G
                } // EOF D
            } // EOF C
            
            // At this point I have looped through
            // all contacts at this account
            // now I need to check to see if 
            // targetedRoles && primaryBusinessContact = TRUE
            
            if(primaryBusinessContact && primaryBusinessContact) {
                
                System.debug('This account has both roles');
                Account account2Update = allAccounts.get(accountIds[j]);
                allAccounts.remove(accountIds[j]);
                
                /// Dont want to overwrite old dates
                
                if(account2Update.Date_DCS_Key_Contact_Roles_Identified__c != null) {
                    
                    // Do nothing. It was allready identified
                
                } else {
                    
                    account2Update.Date_DCS_Key_Contact_Roles_Identified__c = System.Today();
                    account2Update.DCS_Key_Contact_Roles_Identified__c = true;
                    accounts2Update.add(account2Update);
                }
                
                
            } else {
                
                System.debug('This account does not have both roles');
                
                Account account2Update = allAccounts.get(accountIds[j]);
                
                allAccounts.remove(accountIds[j]);
			
			    if(account2Update.Date_DCS_Key_Contact_Roles_Identified__c != null) {
                
                    account2Update.Date_DCS_Key_Contact_Roles_Identified__c = null;
                
                }                
                
                account2Update.DCS_Key_Contact_Roles_Identified__c = false;
                accounts2Update.add(account2Update);
            }
        
        	accountIds2Skip.add(accountIds[j]);
           }
        } // EOF B
    }  // EOF A

    ///////////////////////////////////////////////////////
    /// Add any accounts2Update
    /////////////////////////////////////////////////////////
    
    if(accounts2Update.size() > 0) update accounts2Update;
}