public class AttendeeListCtrl{

    @AuraEnabled 
    public static List<User> getAttendees(String recordId){
        System.debug('JWL: recordID: ' + recordId);
        Team_Meeting__c meeting = [Select  Id,(Select Id,Attendee__r.Name,Attendee__r.Email,Attendee__r.SmallPhotoUrl From Meeting_Attendees__r) From Team_Meeting__c Where Id = :recordId];
        List<User> users = new List<User>();
        for(Meeting_Attendee__c ma : meeting.Meeting_Attendees__r){
            users.add(ma.Attendee__r);
        }
        return users;
    }
}