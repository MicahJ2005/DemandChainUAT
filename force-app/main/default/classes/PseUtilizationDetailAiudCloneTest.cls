/****************************************************************************************
Name            : PseUtilizationDetailAiudClone
Revision Log    : 2012-04-11 JT Lovell (FinacialForce)
                : 
                : 
Use             : This class is used to test trigger PseUtilizationDetailAiudClone
****************************************************************************************/
@isTest
private class PseUtilizationDetailAiudCloneTest
{
    @isTest
    private static void TestPseUtilizationDetailAiudClone1()
    {
        //Insert dummy data//
    
        Schema.DescribeSObjectResult d = Schema.SObjectType.Account;
        Map<String,Schema.RecordTypeInfo> rtMapByName = d.getRecordTypeInfosByName();
        
        Id resourceRecordTypeId;
        if(rtMapByName.containsKey('New Resource for PSA')) {
          Schema.RecordTypeInfo rtByName = rtMapByName.get('New Resource for PSA');
          resourceRecordTypeId = rtByName.getRecordTypeId();
        }
    
        //Insert Account
        Account testAccount = new Account();
        testAccount.Name = 'Test';
        testAccount.CurrencyIsoCode = 'USD';
        insert testAccount;
        system.assert(testAccount.Id != null);
        
        //Insert workcalender 
        pse__Work_Calendar__c workcalender = new pse__Work_Calendar__c();
        workcalender.Name = 'TestCal';
        workcalender.pse__Monday_Hours__c = 8.0;
        workcalender.pse__Tuesday_Hours__c = 8.0;
        workcalender.pse__Wednesday_Hours__c = 8.0;
        workcalender.pse__Thursday_Hours__c = 8.0;
        workcalender.pse__Friday_Hours__c = 8.0;
        
        insert workcalender;
        system.assert(workcalender.Id != null);
        
        //Insert region 
        pse__Region__c region = new pse__Region__c();
        region.Name = 'testregion';
        region.CurrencyIsoCode = 'USD';
        insert region;
        system.assert(region.Id != null);
                        
        pse__Utilization_Calculation__c utilCalculation = new pse__Utilization_Calculation__c();
        utilCalculation.Name = 'TestUtil';
        utilCalculation.pse__Region__c = region.Id;
        insert utilCalculation;
        system.assert(utilCalculation.Id != null); 
        
        //Insert contact
        Contact testContact = new Contact();
        testContact.LastName = 'Test';
        testContact.AccountId = testAccount.Id;
        testContact.CurrencyIsoCode = 'USD';
        testContact.pse__Is_Resource_Active__c = true;
        testContact.pse__Is_Resource__c = true;    
        testContact.pse__Resource_Role__c ='Consultant';
        testContact.pse__Work_Calendar__c =workcalender.Id;
        testContact.pse__Default_Cost_Rate__c = 25.0;
        testContact.pse__Region__c = region.Id;
        testContact.pse__Salesforce_User__c = UserInfo.getUserId();  
        testContact.Email = 'xxx@xxx.com'; 
        if (resourceRecordTypeId != null)
            testContact.RecordTypeId = resourceRecordTypeId;
        insert testContact;
        system.assert(testContact.Id != null);
    
        pse__Utilization_Detail__c testUtilizationDetail = new pse__Utilization_Detail__c();
        testUtilizationDetail.pse__Resource__c = testContact.Id;
        testUtilizationDetail.pse__Historical_Billable_Hours__c = 8.0;
        testUtilizationDetail.pse__Historical_Calendar_Hours__c = 8.0;
        testUtilizationDetail.pse__Historical_Credited_Hours__c = 8.0;
        testUtilizationDetail.pse__Historical_Excluded_Hours__c = 8.0;
        testUtilizationDetail.pse__Scheduled_Billable_Hours__c = 8.0;
        testUtilizationDetail.pse__Scheduled_Calendar_Hours__c = 8.0;
        testUtilizationDetail.pse__Scheduled_Credited_Hours__c = 8.0;
        testUtilizationDetail.pse__Scheduled_Excluded_Hours__c = 8.0;
        testUtilizationDetail.pse__Scheduled_Non_Billable_Hours__c = 8.0;
        testUtilizationDetail.pse__Utilization_Calculation__c = utilCalculation.Id;
        insert testUtilizationDetail;
        
        //20220808 KDJ: commented - deprecated
        //System.assertEquals([select Id,Resource__c from PseUtilization__c where UtilizationDetailId__c = :testUtilizationDetail.Id][0].Resource__c, testContact.id);
                
        testUtilizationDetail.pse__Historical_Billable_Hours__c = 9.0;
        update testUtilizationDetail;
        
        //20220808 KDJ: commented - deprecated
        //System.assertEquals([select Id,Historical_Billable_Hours__c from PseUtilization__c where UtilizationDetailId__c = :testUtilizationDetail.Id][0].Historical_Billable_Hours__c, 9.0);
        
        
        update testUtilizationDetail;
        //20220808 KDJ: commented - deprecated
        //System.assert(1 == [select count() from pse__Utilization_Detail__c where id = :testUtilizationDetail.Id]);
        
        delete testUtilizationDetail;
        //20220808 KDJ: commented - deprecated
        //System.assert(0 == [select count() from pse__Utilization_Detail__c where id = :testUtilizationDetail.Id]);
        //System.assert(0 == [select count() from PseUtilization__c where UtilizationDetailId__c = :testUtilizationDetail.Id]);
    }
}