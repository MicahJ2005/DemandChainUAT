global without sharing class Invocable_SkillsPopulation  {

	@InvocableMethod(label='Populate Skills for Contact')
	global static void populateSkillsForContact(List<String> lstContactId) {

		List<pse__Skill__c> lstSkillsFull = [SELECT Id FROM pse__Skill__c WHERE IsActive__c = TRUE AND pse__Skill_Or_Certification__c = 'Skill'];
		List<pse__Skill_Certification_Rating__c> lstInsertSkills = new List<pse__Skill_Certification_Rating__c>();

		for(String strContactId : lstContactId) {
			Set<Id> setExistingSkills = new Set<Id>();
			for(pse__Skill_Certification_Rating__c objRating : [SELECT Id, pse__Skill_Certification__c FROM pse__Skill_Certification_Rating__c WHERE pse__Resource__c = :strContactId]) {
				setExistingSkills.add(objRating.pse__Skill_Certification__c);
			}

			// Loop through all Skills and add as necessary
			for(pse__Skill__c objSkill : lstSkillsFull) {
				if(!setExistingSkills.contains(objSkill.Id)) {
					lstInsertSkills.add(
						new pse__Skill_Certification_Rating__c(
							pse__Skill_Certification__c = objSkill.Id,
							pse__Resource__c = strContactId,
							pse__Rating__c = 'None',
							pse__Evaluation_Date__c = System.today()
						)
					);
				}
			}
		}

		if(!lstInsertSkills.isEmpty()) {
			insert lstInsertSkills;
		}

	}

}