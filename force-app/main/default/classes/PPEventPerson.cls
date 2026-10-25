/** A speaker, attendee or colleague on an event, with their history on earlier events. Counts and flags are computed in Apex. */
@JsonAccess(serializable='always' deserializable='always')
global class PPEventPerson {
    @AuraEnabled global String name;
    @AuraEnabled global String accountId;
    @AuraEnabled global String kind;
    @AuraEnabled global String role;
    @AuraEnabled global String response;
    @AuraEnabled global String attendance;
    @AuraEnabled global String specialty;
    @AuraEnabled global Integer tier;
    @AuraEnabled global Decimal fee;
    @AuraEnabled global String trained;
    @AuraEnabled global Integer programsYtd;
    @AuraEnabled global Integer invited;
    @AuraEnabled global Integer completed;
    @AuraEnabled global Integer attended;
    @AuraEnabled global Integer noShows;
    @AuraEnabled global String lastAttended;
    @AuraEnabled global String flag;
    @AuraEnabled global String tone;
    @AuraEnabled global Boolean highlight;
    @AuraEnabled global List<String> notes;
    @AuraEnabled global List<PPEventPast> past;
}
