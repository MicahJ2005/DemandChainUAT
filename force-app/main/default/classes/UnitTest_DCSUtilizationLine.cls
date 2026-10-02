@isTest
public class UnitTest_DCSUtilizationLine {

    @testSetup
    private static void testSetup() {
        Goal_Tracking__c objGoal = new Goal_Tracking__c(
            Name = 'Test Goal', 
            IsActive__c = TRUE
        );
        insert objGoal;
        
        Goal_Tracking_Week__c objWeek = new Goal_Tracking_Week__c(
            Related_Goal__c = objGoal.Id, 
            Week_Starting__c = System.Today()
        );
        insert objWeek;
    }
    
    @isTest
    private static void testUtilizationAssignment() {
        
        DCSUtilization__c objUtil = new DCSUtilization__c();
        insert objUtil;
        
        DCSUtilizationLine__c objUtilLine = new DCSUtilizationLine__c(
        	DCSUtilization__c = objUtil.Id,
            StartofWeek__c = System.Today(),
            Hours__c = 40
        );
        
        test.startTest();
        insert objUtilLine;
        test.stopTest();
        
        System.Debug(objUtilLine);
        
    }
    
}