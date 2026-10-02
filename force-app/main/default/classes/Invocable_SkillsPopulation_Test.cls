@IsTest
private class Invocable_SkillsPopulation_Test  {

	@testSetup private static void setupTestData() {
		
		Contact objContact = new Contact(LastName='Contact', Firstname='Test', Email='me@you.com', pse__Is_Resource__c = true, pse__Is_Resource_Active__c=true);
		insert objContact;
		
		pse__Skill__c objSkill = new pse__Skill__c(Name='Test Skill', IsActive__c = true, pse__Skill_Or_Certification__c = 'Skill');
		insert objSkill;

		pse__Skill__c objSkillExisting = new pse__Skill__c(Name='Test Skill Existing', IsActive__c = true, pse__Skill_Or_Certification__c = 'Skill');
		insert objSkillExisting;

		pse__Skill_Certification_Rating__c objRating = new pse__Skill_Certification_Rating__c(
			pse__Resource__c=objContact.Id,
			pse__Skill_Certification__c=objSkillExisting.Id
		);
		insert objRating;

	}

	@isTest private static void testSkillThingy() {

		List<String> lstContactIds = new List<String>();
		for(Contact objContact : [SELECT Id FROM Contact]) {
			lstContactIds.add(objContact.Id);
		}

		Invocable_SkillsPopulation.populateSkillsForContact(lstContactIds);

	}


}