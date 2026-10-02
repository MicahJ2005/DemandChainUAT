trigger ProjectAlignToAccountGoals on pse__Proj__c (before insert, before update) {

    // ANDY MADE THIS TO CONNECT PROJECTS TO ACCOUNT PLANS
     
    // Get what accounts are in scope
    Map<Id, Map<String, Id>> mapAccountPlans = new Map<Id, Map<String, Id>>();
    for(pse__Proj__c objProject : trigger.new) {
        if(objProject.DCS_Primary_Practice__c != null && objProject.pse__Start_Date__c <= System.Today() && objProject.pse__End_Date__c >= System.Today()) {
            mapAccountPlans.put(objProject.pse__Account__c, new Map<String, Id>());
        }
    }
    
    // Get active Account Plans by Account and Practice
    
    for(Account_Plan__c objPlan : [SELECT Id, Account__c, Practice__c FROM Account_Plan__c WHERE Account__c IN :mapAccountPlans.keyset() AND Plan_Start_Date__c <= :System.Today() AND Plan_End_Date__c >= :System.Today()]) {
        Map<String, Id> mapPractice = mapAccountPlans.get(objPlan.Account__c);
        mapPractice.put(objPlan.Practice__c, objPlan.Id);
        mapAccountPlans.put(objPlan.Account__c, mapPractice);
    }
    
    System.Debug(JSON.serialize(mapAccountPlans));
    
    // Loop through Projects and assign Plans as appropriate
    for(pse__Proj__c objProject : trigger.new) {
        if(objProject.DCS_Primary_Practice__c != null && mapAccountPlans.containsKey(objProject.pse__Account__c)) {
            System.Debug('Ok, in the loop - looking for ' + objProject.DCS_Primary_Practice__c + ' on ' + objProject.pse__Account__c);
            Map<String, Id> mapPractice = mapAccountPlans.get(objProject.pse__Account__c);
            if(mapPractice.containsKey(objProject.DCS_Primary_Practice__c)) {
                System.Debug('GOOD TO GO');
                objProject.Account_Plan__c = mapPractice.get(objProject.DCS_Primary_Practice__c);
            }
        }
    }
    
    
}