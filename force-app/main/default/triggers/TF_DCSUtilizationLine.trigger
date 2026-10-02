trigger TF_DCSUtilizationLine on DCSUtilizationLine__c (before insert, before update) {

    ////////////////////////////////////////
    // LINK UP Line to Forecast Object
    ////////////////////////////////////////
    Set<Date> setGoalSundays = new Set<Date>();
    Map<Date, Id> mapGoalSundays = new Map<Date, Id>();
    
    // STEP 1:  GET GOAL TRACKING WEEKS FOR WEEKS IN TRIGGER LIST
    for(DCSUtilizationLine__c objUL : trigger.new) {
        setGoalSundays.add(objUL.StartOfWeek__c);
    }
    
    for(Goal_Tracking_Week__c objWeek : [SELECT Id, Week_Starting__c FROM Goal_Tracking_Week__c WHERE Week_Starting__c IN :setGoalSundays]) {
		 mapGoalSundays.put(objWeek.Week_Starting__c, objWeek.Id);       
    }
    
    // STEP 2:  SPIN THROUGH TRIGGER LIST AND SET LOOKUP TO GOAL WEEK
    for(DCSUtilizationLine__c objUL : trigger.new) {
        if(mapGoalSundays.containsKey(objUL.StartOfWeek__c)) {
            objUL.GoalTrackingWeek__c = mapGoalSundays.get(objUL.StartOfWeek__c);
        }
    }
    
    
    
}