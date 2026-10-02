@IsTest
public class PasswordVaultServiceTest {
    @TestSetup
    static void makeData() {
        RecordType rtActiveAccount = [
            SELECT Id
            FROM RecordType
            WHERE Name = 'Active Account'
            LIMIT 1
        ];

        RecordType rtEmployeeContact = [
            SELECT Id, Name
            FROM RecordType
            WHERE Name = 'Employee' AND SobjectType = 'Contact'
            LIMIT 1
        ];

        //user
        Profile p = [
            SELECT id
            FROM profile
            WHERE name = 'System Administrator'
        ];

        // create employees

        User gwenUser = new User(
            Alias = 'testG',
            Email = 'gwenstacy@example.com',
            FirstName = 'Gwen',
            LastName = 'Stacy',
            ProfileId = p.Id,
            LocaleSidKey = 'en_US',
            Username = 'gwenstacy@example.com',
            TimeZoneSidKey = 'America/Chicago',
            LanguageLocaleKey = 'en_US',
            EmailEncodingKey = 'UTF-8'
        );

        User peterUser = new User(
            Alias = 'testP',
            Email = 'peterparker@example.com',
            FirstName = 'Peter',
            LastName = 'Parker',
            ProfileId = p.Id,
            LocaleSidKey = 'en_US',
            Username = 'peterparker@example.com',
            TimeZoneSidKey = 'America/Chicago',
            LanguageLocaleKey = 'en_US',
            EmailEncodingKey = 'UTF-8'
        );

        insert new List<User>{ gwenUser, peterUser };

        //work calendar
        pse__Work_Calendar__c wrkCal = new pse__Work_Calendar__c(
            Name = 'US - Default',
            pse__Week_Start_Day__c = 'Monday',
            pse__Standard_Hours_Per_Day__c = 8,
            pse__Monday_Hours__c = 8,
            pse__Tuesday_Hours__c = 8,
            pse__Wednesday_Hours__c = 8,
            pse__Thursday_Hours__c = 8,
            pse__Friday_Hours__c = 8,
            pse__Saturday_Hours__c = 8,
            pse__Sunday_Hours__c = 8
        );

        insert wrkCal;

        //region
        pse__Region__c reg = new pse__Region__c(
            pse__Default_Work_Calendar__c = wrkCal.Id,
            Name = 'Test Region',
            pse__Include_In_Forecasting__c = true
        );

        insert reg;

        //dcs acct
        Account dcsAcct = new Account(Name = 'Demand Chain', RecordTypeId = rtActiveAccount.Id);

        //client acct
        Account clientAcct = new Account(
            Name = 'Daily Bugle, Inc.',
            RecordTypeId = rtActiveAccount.Id,
            Account_Name_Short__c = 'Daily Bugle'
        );

        insert new List<Account>{ dcsAcct, clientAcct };

        // test employee contacts
        Contact gwenContact = new Contact(
            FirstName = 'Gwen',
            LastName = 'Stacy',
            Email = 'gwenstacy@example.com',
            AccountId = dcsAcct.Id,
            pse__Region__c = reg.Id,
            pse__Work_Calendar__c = wrkCal.Id,
            pse__Salesforce_User__c = gwenUser.Id,
            pse__Is_Resource__c = true,
            pse__Is_Resource_Active__c = true
        );

        Contact peterContact = new Contact(
            FirstName = 'Peter',
            LastName = 'Parker',
            Email = 'peterparker@example.com',
            AccountId = dcsAcct.Id,
            pse__Region__c = reg.Id,
            pse__Work_Calendar__c = wrkCal.Id,
            pse__Salesforce_User__c = peterUser.Id,
            pse__Is_Resource__c = true,
            pse__Is_Resource_Active__c = true
        );

        insert new List<Contact>{ gwenContact, peterContact };

        //project
        pse__Proj__c proj = new pse__Proj__c(
            Name = 'Test Project',
            pse__Account__c = clientAcct.Id,
            pse__Billing_Type__c = 'Time and Materials',
            pse__Is_Active__c = true,
            pse__Is_Billable__c = true,
            pse__Start_Date__c = date.today(),
            pse__End_Date__c = date.today() + 30,
            dcs_Requested_Hours__c = 8,
            dcs_Assignment_Start_Date__c = date.today(),
            dcs_Assignment_End_Date__c = date.today() + 7
        );

        insert proj;

        //schedules
        pse__Schedule__c schedActivePeter = new pse__Schedule__c(
            pse__Wednesday_Hours__c = 8,
            pse__Tuesday_Hours__c = 8,
            pse__Thursday_Hours__c = 8,
            pse__Sunday_Hours__c = 0,
            pse__Start_Date__c = system.Today(),
            pse__Scheduled_Hours__c = 80,
            pse__Scheduled_Days__c = 40,
            pse__Saturday_Hours__c = 0,
            pse__Monday_Hours__c = 8,
            pse__Friday_Hours__c = 8,
            pse__End_Date__c = system.Today() + 90,
            CurrencyIsoCode = 'USD'
        );

        insert new List<pse__Schedule__c>{ schedActivePeter };

        //permission control - resource
        pse__Permission_Control__c pcr = new pse__Permission_Control__c(
            pse__User__c = gwenUser.id,
            pse__Timecard_Ops_Edit__c = true,
            pse__Timecard_Entry__c = true,
            pse__Staffing__c = true,
            pse__Skills_And_Certifications_View__c = true,
            pse__Skills_And_Certifications_Entry__c = true,
            pse__Resource__c = gwenContact.id,
            pse__Resource_Request_Entry__c = true,
            pse__Invoicing__c = true,
            pse__Forecast_View__c = true,
            pse__Forecast_Edit__c = true,
            pse__Expense_Ops_Edit__c = true,
            pse__Expense_Entry__c = true,
            pse__Cascading_Permission__c = true,
            pse__Billing__c = true
        );

        //permission control - project
        pse__Permission_Control__c pcp = new pse__Permission_Control__c(
            pse__User__c = gwenUser.id,
            pse__Timecard_Ops_Edit__c = true,
            pse__Timecard_Entry__c = true,
            pse__Staffing__c = true,
            pse__Skills_And_Certifications_View__c = true,
            pse__Skills_And_Certifications_Entry__c = true,
            pse__Resource_Request_Entry__c = true,
            pse__Invoicing__c = true,
            pse__Forecast_View__c = true,
            pse__Forecast_Edit__c = true,
            pse__Expense_Ops_Edit__c = true,
            pse__Expense_Entry__c = true,
            pse__Cascading_Permission__c = true,
            pse__Billing__c = true,
            pse__Project__c = proj.id
        );

        //permission control - resource
        pse__Permission_Control__c pcr2 = new pse__Permission_Control__c(
            pse__User__c = peterUser.id,
            pse__Timecard_Ops_Edit__c = true,
            pse__Timecard_Entry__c = true,
            pse__Staffing__c = true,
            pse__Skills_And_Certifications_View__c = true,
            pse__Skills_And_Certifications_Entry__c = true,
            pse__Resource__c = peterContact.id,
            pse__Resource_Request_Entry__c = true,
            pse__Invoicing__c = true,
            pse__Forecast_View__c = true,
            pse__Forecast_Edit__c = true,
            pse__Expense_Ops_Edit__c = true,
            pse__Expense_Entry__c = true,
            pse__Cascading_Permission__c = true,
            pse__Billing__c = true
        );

        //permission control - project
        pse__Permission_Control__c pcp2 = new pse__Permission_Control__c(
            pse__User__c = peterUser.id,
            pse__Timecard_Ops_Edit__c = true,
            pse__Timecard_Entry__c = true,
            pse__Staffing__c = true,
            pse__Skills_And_Certifications_View__c = true,
            pse__Skills_And_Certifications_Entry__c = true,
            pse__Resource_Request_Entry__c = true,
            pse__Invoicing__c = true,
            pse__Forecast_View__c = true,
            pse__Forecast_Edit__c = true,
            pse__Expense_Ops_Edit__c = true,
            pse__Expense_Entry__c = true,
            pse__Cascading_Permission__c = true,
            pse__Billing__c = true,
            pse__Project__c = proj.id
        );

        insert new List<pse__Permission_Control__c>{ pcr, pcp, pcr2, pcp2 };

        Test.setMock(HttpCalloutMock.class, new PasswordVaultMockCallout());

        pse__Assignment__c asgmt = new pse__Assignment__c(
            pse__Schedule__c = schedActivePeter.Id,
            pse__Resource__c = peterContact.Id,
            pse__Project__c = proj.Id,
            pse__Planned_Bill_Rate__c = 200,
            pse__Cost_Rate_Amount__c = 100,
            pse__Bill_Rate__c = 200,
            Name = 'Peter Assignment Active',
            CurrencyIsoCode = 'USD'
        );

        System.runAs(peterUser) {
            insert asgmt;
        }
    }

    @IsTest
    static void projectShouldExist() {
        pse__Proj__c proj = [
            SELECT Id
            FROM pse__Proj__c
            WHERE Name = 'Test Project'
        ];
        Assert.isNotNull(proj, 'Project should exist');
    }

    @IsTest
    static void testAssignmentShouldExist() {
        User gwen = [
            SELECT Id
            FROM User
            WHERE Alias = 'testG'
        ];

        pse__Schedule__c sched = new pse__Schedule__c(
            pse__Wednesday_Hours__c = 8,
            pse__Tuesday_Hours__c = 8,
            pse__Thursday_Hours__c = 8,
            pse__Sunday_Hours__c = 0,
            pse__Start_Date__c = system.Today(),
            pse__Scheduled_Hours__c = 80,
            pse__Scheduled_Days__c = 40,
            pse__Saturday_Hours__c = 0,
            pse__Monday_Hours__c = 8,
            pse__Friday_Hours__c = 8,
            pse__End_Date__c = system.Today() + 90,
            CurrencyIsoCode = 'USD'
        );

        insert sched;

        Contact contact = [
            SELECT Id
            FROM Contact
            WHERE pse__Salesforce_User__c = :gwen.Id
        ];

        pse__Proj__c proj = [
            SELECT Id
            FROM pse__Proj__c
            WHERE Name = 'Test Project'
        ];

        Test.setMock(HttpCalloutMock.class, new PasswordVaultMockCallout());

        pse__Assignment__c asgmt = new pse__Assignment__c(
            pse__Schedule__c = sched.Id,
            pse__Resource__c = contact.Id,
            pse__Project__c = proj.Id,
            pse__Planned_Bill_Rate__c = 200,
            pse__Cost_Rate_Amount__c = 100,
            pse__Bill_Rate__c = 200,
            Name = 'Test Assignment',
            CurrencyIsoCode = 'USD'
        );

        Test.startTest();
        System.runAs(gwen) {
            //assignment
            insert asgmt;
        }

        Test.stopTest();

        Assert.areEqual('Test Assignment', asgmt.Name, 'Assignment should exist');
    }

    @IsTest
    static void expiredAssignmentShouldRevokeAccess() {
        Test.setMock(HttpCalloutMock.class, new PasswordVaultMockCallout());

        User testUser = [
            SELECT Id
            FROM User
            WHERE Alias = 'testG'
        ];

        Contact dcsCont = [
            SELECT Id
            FROM Contact
            WHERE pse__Salesforce_User__c = :testUser.Id
        ];

        pse__Proj__c proj = [
            SELECT Id
            FROM pse__Proj__c
            WHERE Name = 'Test Project'
        ];

        pse__Schedule__c sched = new pse__Schedule__c(
            pse__Wednesday_Hours__c = 8,
            pse__Tuesday_Hours__c = 8,
            pse__Thursday_Hours__c = 8,
            pse__Sunday_Hours__c = 0,
            pse__Start_Date__c = system.Today() - 90,
            pse__Scheduled_Hours__c = 80,
            pse__Scheduled_Days__c = 40,
            pse__Saturday_Hours__c = 0,
            pse__Monday_Hours__c = 8,
            pse__Friday_Hours__c = 8,
            pse__End_Date__c = system.Today() - 14,
            CurrencyIsoCode = 'USD'
        );

        insert sched;

        pse__Assignment__c asgmt = new pse__Assignment__c(
            pse__Schedule__c = sched.Id,
            pse__Resource__c = dcsCont.Id,
            pse__Project__c = proj.Id,
            pse__Planned_Bill_Rate__c = 200,
            pse__Cost_Rate_Amount__c = 100,
            pse__Bill_Rate__c = 200,
            Name = 'Test Assignment',
            CurrencyIsoCode = 'USD'
        );

        System.runAs(testUser) {
            insert asgmt;
        }

        Test.startTest();

        List<ID> assignmentIds = new List<ID>{ asgmt.Id };
        Invocable_PasswordVaultAssignments.processAssignments(assignmentIds);

        Test.stopTest();
    }

    @IsTest
    static void deletedAssignmentShouldNotExist() {
        Test.setMock(HttpCalloutMock.class, new PasswordVaultMockCallout());

        User testUser = [
            SELECT Id
            FROM User
            WHERE Alias = 'testG'
        ];

        Contact dcsCont = [
            SELECT Id
            FROM Contact
            WHERE pse__Salesforce_User__c = :testUser.Id
        ];

        pse__Proj__c proj = [
            SELECT Id
            FROM pse__Proj__c
            WHERE Name = 'Test Project'
        ];

        pse__Schedule__c sched = new pse__Schedule__c(
            pse__Wednesday_Hours__c = 8,
            pse__Tuesday_Hours__c = 8,
            pse__Thursday_Hours__c = 8,
            pse__Sunday_Hours__c = 0,
            pse__Start_Date__c = system.Today() - 90,
            pse__Scheduled_Hours__c = 80,
            pse__Scheduled_Days__c = 40,
            pse__Saturday_Hours__c = 0,
            pse__Monday_Hours__c = 8,
            pse__Friday_Hours__c = 8,
            pse__End_Date__c = system.Today(),
            CurrencyIsoCode = 'USD'
        );

        insert sched;

        pse__Assignment__c asgmt = new pse__Assignment__c(
            pse__Schedule__c = sched.Id,
            pse__Resource__c = dcsCont.Id,
            pse__Project__c = proj.Id,
            pse__Planned_Bill_Rate__c = 200,
            pse__Cost_Rate_Amount__c = 100,
            pse__Bill_Rate__c = 200,
            Name = 'Test Assignment',
            CurrencyIsoCode = 'USD'
        );

        System.runAs(testUser) {
            insert asgmt;
        }

        Test.startTest();

        System.runAs(testUser) {
            delete asgmt;
        }

        Test.stopTest();

        List<pse__Assignment__c> assignments = [
            SELECT Id
            FROM pse__Assignment__c
            WHERE Id = :asgmt.Id
        ];

        Assert.areEqual(0, assignments.size(), 'Assignment should not exist');
    }

    @IsTest
    static void createVaultAsyncShouldUpdateVaultId() {
        Test.setMock(HttpCalloutMock.class, new PasswordVaultMockCallout());

        Account account = [
            SELECT Id
            FROM Account
            WHERE Name = 'Daily Bugle, Inc.'
        ];

        Test.startTest();

        PasswordVaultService.createVaultAsync(account.Id, 'I am a test vault');

        Test.stopTest();

        Account updatedAccount = [
            SELECT Id, CredentialVaultId__c
            FROM Account
            WHERE Name = 'Daily Bugle, Inc.'
        ];

        Assert.isNotNull(updatedAccount.CredentialVaultId__c, 'Vault ID should not be null.');
    }
}