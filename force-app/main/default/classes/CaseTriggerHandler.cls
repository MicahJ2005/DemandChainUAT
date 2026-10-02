//01.27.2020	Sophia Murphy (Demand Chain - d'uh)
//				Created to auto-set the Project on PC/Managed Services cases
public class CaseTriggerHandler {

    public static void catchDCSentCases(List<Case> newList) {
        /**When new case is forwarded in from a Demand Chain person; on behalf of a client
         * instead of tying the case to the DC person - tie it to the client.
         * Only for Managed Services Cases
         * And if the web email (SuppliedEmail) contains demandchain.com or demandchainsystems.com
		*/
        Map<Id, Case> casesICareAbout = new Map<Id, Case>();
        Map<Id, String> caseIdToEmailAddr = new Map<Id, String>();
        //Set<Id> acctIds = new Set<Id>();
        //Map<Id, List<pse__Proj__c>> acctToProjMap = new Map<Id, List<pse__Proj__c>>();
        for(Case c : newList) {
            if(c.RecordTypeId == '012370000001axLAAQ' && (c.SuppliedEmail.contains('demandchain.com') || c.SuppliedEmail.contains('demandchainsystems.com') ) ) {
                String emlAddr = getEMLAddress(c.Description);
                if(emlAddr != '') {
                    casesICareAbout.put(c.Id, c);
                    caseIdToEmailAddr.put(c.Id, emlAddr);
                }
            }
        } //end: for(Case c : newList)
        
        //With all the email addresses we have - we need to find these contacts and their accounts
        Map<String, Contact> contactMap = new Map<String, Contact>();
        Set<Id> acctIds = new Set<Id>();
        for(Contact c : [SELECT Id, Email, AccountId FROM Contact WHERE Email IN :caseIdToEmailAddr.values()]) {
            contactMap.put(c.Email, c);
            acctIds.add(c.AccountId);
        }
        
        Map<Id, List<pse__Proj__c>> acctToProjMap = getPrimaryPCProject(acctIds);
        
        //Ok - so we have a Map of cases; and a map of case id with an email address to match up with.
        //	Just the first non-DC email address found in the description
        List<Case> casesToUpdate = new List<Case>();
        for(Id caseId : casesICareAbout.keySet()) {
            Case cs = casesICareAbout.get(caseId);
            String emlAddr = caseIdToEmailAddr.get(caseId);
            Contact cnt = contactMap.get(emlAddr);
            
            Case newCase = new Case(Id = cs.Id);
            newCase.AccountId = cnt.AccountId;
            newCase.ContactId = cnt.Id;
            try {
                //I don't want this to fail and we lose the account/contact update.
                List<pse__Proj__c> tmpList = acctToProjMap.get(cnt.AccountId);
                if(tmpList.size() == 1) {
                    newCase.Project__c = tmpList[0].Id;
                }
            } catch (Exception e) {}
            casesToUpdate.add(newCase);
        }
        if(casesToUpdate.size() > 0) {
        	update casesToUpdate;
        }
    }
    
    private static String getEMLAddress(String emlBody) {
        Matcher m = Pattern.compile('[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\\.[a-zA-Z0-9-.]+').matcher(emlBody);
        String emlAddr = '';
        Boolean keepFinding = true;
            while (m.find() && keepFinding) {
                System.debug(m.group());
                if(m.group().contains('demandchain.com') || m.group().contains('demandchainsystems.com') ) {
                    //do nothing... this is not an address we want...
                } else {
                    emlAddr = m.group();
                    keepFinding = false;
                }
            } //end while
        return emlAddr;
    }
    
    public static void setPCProject(List<Case> newList) {
        /**When new case is entered and Project is empty, but Account is not.
         	* If Case is a Managed Services case: 012370000001axLAAQ 
            * pse__Proj__c - With the Account ID, search for all Projects related to that Account that are...
                * pse__Stage__c: Planning or In Progress
                * pse__Practice__c: Platform Commitment
            * Once you find 1 project - set that on the case - if MORE THAN 1 project is found, do nothing
		*/
        List<Case> casesICareAbout = new List<Case>();
        Set<Id> acctIds = new Set<Id>();
        for(Case c : newList) {
            if(c.RecordTypeId == '012370000001axLAAQ' && c.AccountId != null && c.Project__c == null) {
                casesICareAbout.add(c);
                acctIds.add(c.AccountId);
            }
        }
        
        System.debug('DC: casesICareAbout: ' + casesICareAbout);
        System.debug('DC: acctIds: ' + acctIds);
        
        Map<Id, List<pse__Proj__c>> acctToProjMap = getPrimaryPCProject(acctIds);
        System.debug('DC: acctToProjMap: ' + acctToProjMap);
        
        List<Case> casesToUpdate = new List<Case>();
        if(casesICareAbout.size() > 0 && acctToProjMap.size() > 0) {
            for(Case c : casesICareAbout) {
                Id acctId = c.AccountId;
                List<pse__Proj__c> tmpList = acctToProjMap.get(acctId);
                if(tmpList.size() == 1) {
                    Case cNew = new Case(Id = c.Id);
                    cNew.Project__c = tmpList[0].Id;
                    casesToUpdate.add(cNew);
                }
            }
        }
        
        System.debug('DC: casesToUpdate: ' + casesToUpdate);
        
        if(casesToUpdate.size() > 0) {
            update casesToUpdate;
        }
    }
    
    private static Map<Id, List<pse__Proj__c>> getPrimaryPCProject(Set<Id> acctIds) {
        Map<Id, List<pse__Proj__c>> acctToProjMap = new Map<Id, List<pse__Proj__c>>();
        
        //Now - query for Projects related to those Accounts
        for(pse__Proj__c proj : [SELECT Id, pse__Account__c FROM pse__Proj__c WHERE pse__Account__c IN :acctIds
                                		AND (pse__Stage__c = 'Planning' OR pse__Stage__c = 'In Progress')
                                 		AND pse__Practice__r.Name = 'Platform Commitment']) {
			List<pse__Proj__c> tmpList =   acctToProjMap.get(proj.pse__Account__c);
            if(tmpList == null) {
            	tmpList = new List<pse__Proj__c>();
            }
            tmpList.add(proj);
            acctToProjMap.put(proj.pse__Account__c, tmpList);
        }    
        return acctToProjMap;
    }
}