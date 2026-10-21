/**
 * @group BusinessHealth
 *
 * @description Keeps Business Health goal versions unambiguous: two Active goal sets
 * for the same scope (firm-wide, the same practice, or the same person) may not have overlapping
 * effective dates, so exactly one version is in force for any date. Checked against
 * the database and within the same save. Runs without sharing so the rule holds even
 * against versions the editor cannot see.
 */
public without sharing class BusinessHealthGoalSetHandler {
    private static final Date FAR_FUTURE = Date.newInstance(9999, 12, 31);

    public static void validate(List<Business_Health_Goal_Set__c> records) {
        List<Business_Health_Goal_Set__c> active = new List<Business_Health_Goal_Set__c>();
        Set<Id> selfIds = new Set<Id>();
        for (Business_Health_Goal_Set__c g : records) {
            if (g.Status__c == 'Active' && g.Effective_Start__c != null) {
                active.add(g);
                if (g.Id != null) {
                    selfIds.add(g.Id);
                }
            }
        }
        if (active.isEmpty()) {
            return;
        }
        // Goal sets are a small configuration table, so compare against every other Active one.
        List<Business_Health_Goal_Set__c> pool = [
            SELECT Id, Name, Practice__c, User__c, Effective_Start__c, Effective_End__c
            FROM Business_Health_Goal_Set__c
            WHERE Status__c = 'Active' AND Id NOT IN :selfIds
        ];
        for (Integer i = 0; i < active.size(); i++) {
            Business_Health_Goal_Set__c g = active[i];
            for (Business_Health_Goal_Set__c other : pool) {
                if (sameScope(g, other) && overlaps(g, other)) {
                    g.addError(conflictMessage(other));
                }
            }
            for (Integer j = 0; j < i; j++) {
                if (sameScope(g, active[j]) && overlaps(g, active[j])) {
                    g.addError(conflictMessage(active[j]));
                }
            }
        }
    }

    @TestVisible
    private static Boolean overlaps(Business_Health_Goal_Set__c a, Business_Health_Goal_Set__c b) {
        Date aEnd = a.Effective_End__c == null ? FAR_FUTURE : a.Effective_End__c;
        Date bEnd = b.Effective_End__c == null ? FAR_FUTURE : b.Effective_End__c;
        return a.Effective_Start__c <= bEnd && b.Effective_Start__c <= aEnd;
    }

    private static Boolean sameScope(Business_Health_Goal_Set__c a, Business_Health_Goal_Set__c b) {
        return a.Practice__c == b.Practice__c && a.User__c == b.User__c;
    }

    private static String conflictMessage(Business_Health_Goal_Set__c other) {
        return 'Another Active goal set for the same scope (' + other.Name + ', starting ' + other.Effective_Start__c.format() +
            ') overlaps these dates. End-date or deactivate it first, so only one version is in force on any day.';
    }
}
