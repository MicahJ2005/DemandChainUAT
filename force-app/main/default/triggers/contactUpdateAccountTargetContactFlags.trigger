trigger contactUpdateAccountTargetContactFlags on Contact (after insert, after update, after delete) {
    //Created by EBG
    //Each time a contact associated to an account is inserted or updated, look at all contacts under 
    //that account and determine if the fields at the account need to be changed

    System.debug('Inside contactUpdateAccountTargetContactFlags');          

    //Account fields
    Boolean bSalesTargetIdentified = false;
    Boolean bITTargetIdentified = false;
    Boolean bCrmAdminTargetIdentified = false;
    
    //get the account(s) associated to the contact(s) being updated/deleted
    //If in a delete trigger, need to look at the Trigger.old record; otherwise look at Trigger.new
    Set<Id> accountIds = new Set<Id>();
    for (Contact cNew : Trigger.isDelete ? Trigger.old : Trigger.new) {
        if (cNew.accountId == null) {
            //add a bogus id that will not return data
            System.debug('Adding 000000000000000000');
            accountIds.add('000000000000000000');
        } else {
            System.debug('Adding ' + cNew.accountId);
            accountIds.add(cNew.accountId);
        }
    }
    
    //find all accounts and the contacts below them having the contact type we want to track at the account level
    Integer acctIndex = 0;
    for (List<Account> acct : [SELECT id, 
                                    Identified_Sales_Target__c,
                                    Identified_IT_Target__c,
                                    (Select 
                                        Id,
                                        Target_Contact_Sales__c,
                                        Target_Contact_IT__c,
                                        Targeted_Role__c
                                    From Account.Contacts
                                    Where Targeted_Role__c includes ('Primary IT Contact', 'Primary Sales Contact'))
                            FROM Account
                            WHERE Id in :accountIds]){
                               
        System.debug('Did we get any: ' + acct.size());
                  
        
        //initialize the flags
        bSalesTargetIdentified = false;
        bITTargetIdentified = false;
        bCrmAdminTargetIdentified = false;
        
        //make sure we found at least one record
        if (acct.size() > 0 ) {
            //loop through the contacts associated to the account and set the account flags if any of the contact flags are checked
            for (Integer contIndex = 0; contIndex < acct[acctIndex].Contacts.size(); contIndex++) { 
                //if (acct[acctIndex].Contacts[contIndex].Target_Contact_Sales__c == true) {
                //  bSalesTargetIdentified = true;
                //}
                //if (acct[acctIndex].Contacts[contIndex].Target_Contact_IT__c == true) {
                //  bITTargetIdentified = true;
                //}
                
                if (acct[acctIndex].Contacts[contIndex].Targeted_Role__c.indexOf('Primary Sales Contact') != -1) {
                    bSalesTargetIdentified = true;
                }
                if (acct[acctIndex].Contacts[contIndex].Targeted_Role__c.indexOf('Primary IT Contact') != -1) {
                    bITTargetIdentified = true;
                }
                if (acct[acctIndex].Contacts[contIndex].Targeted_Role__c.indexOf('CRM System Admin') != -1) {
                    bCrmAdminTargetIdentified = true;
                }
            }                                       
    
            //if the account values differ from the boolean variables, set the account fields to the values in the boolean variables
            //and update the account
            System.debug('Updating account.');
            if ((acct[acctIndex].Identified_Sales_Target__c != bSalesTargetIdentified) || (acct[acctIndex].Identified_IT_Target__c != bITTargetIdentified)) {
                acct[acctIndex].Identified_Sales_Target__c = bSalesTargetIdentified;
                acct[acctIndex].Identified_IT_Target__c = bITTargetIdentified;
                update acct[acctIndex];
            }
            acctIndex++;
        }
    }



}