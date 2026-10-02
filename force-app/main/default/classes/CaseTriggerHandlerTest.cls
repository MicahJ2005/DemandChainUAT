@isTest
private class CaseTriggerHandlerTest {
	
    static testMethod void test1(){
        
		Account a = TestUtil.getAccounts(1, true)[0];
        
        List<pse__Proj__c> projList = new List<pse__Proj__c>();
        List<pse__Practice__c> practiceList = TestUtil.createFourPractices();
        Integer i = 0;
        
        for(pse__Proj__c p : TestUtil.getProjects(4, false))
        {
            p.pse__Practice__c = practiceList[i].Id;
            p.pse__Account__c = a.Id;
            
            projList.add(p);
            i++;
        }
        insert projList;
        pse__Proj__c pcProj = [SELECT Id FROM pse__Proj__c WHERE pse__Practice__r.Name = 'Platform Commitment' AND Id IN :projList LIMIT 1];
        
        //Create a case; check that it gets assigned to the PC project.
        Id msRTId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Managed Service').getRecordTypeId();
        List<Case> caseList = TestUtil.getCases(a, msRTId, 10, true);
        
        for(Case c : [SELECT Id, Project__c FROM Case WHERE Id IN :caseList]) {
            System.assertEquals(pcProj.Id, c.Project__c);
        }
        
        
    }
    
    //test when an email is forwarded from demandchain - it gets reassigned.
    static testMethod void test2(){
        
		Account a = TestUtil.getAccounts(1, true)[0];
        Contact cnt = TestUtil.getContacts(1, true, a)[0];
        
        List<pse__Proj__c> projList = new List<pse__Proj__c>();
        List<pse__Practice__c> practiceList = TestUtil.createFourPractices();
        Integer i = 0;
        
        for(pse__Proj__c p : TestUtil.getProjects(4, false))
        {
            p.pse__Practice__c = practiceList[i].Id;
            p.pse__Account__c = a.Id;
            
            projList.add(p);
            i++;
        }
        insert projList;
        pse__Proj__c pcProj = [SELECT Id FROM pse__Proj__c WHERE pse__Practice__r.Name = 'Platform Commitment' AND Id IN :projList LIMIT 1];
        
        //Create a case; check that it gets assigned to the PC project.
        Id msRTId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Managed Service').getRecordTypeId();
        List<Case> caseList = new List<Case>();
        for(Case cs : TestUtil.getCases(a, msRTId, 10, false)) {
            cs.SuppliedEmail = 'someone@demandchain.com';
            cs.Description = 'Hey I sent this email from someone@demandchain.com but it should really be applied to ' + cnt.Email + ' because it is really from them.';
        	caseList.add(cs);
        }
        insert caseList;
        
        for(Case cs2 : [SELECT Id, Project__c, ContactId, AccountId FROM Case WHERE Id IN :caseList]) {
            System.assertEquals(pcProj.Id, cs2.Project__c);
            System.assertEquals(a.Id, cs2.AccountId);
            System.assertEquals(cnt.Id, cs2.ContactId);
        }
        
        
    }
	
}