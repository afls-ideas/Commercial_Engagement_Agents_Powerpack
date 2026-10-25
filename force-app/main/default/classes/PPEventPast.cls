/** One earlier event a person was invited to, with whether they responded and showed up. */
@JsonAccess(serializable='always' deserializable='always')
global class PPEventPast {
    @AuraEnabled global String eventId;
    @AuraEnabled global String name;
    @AuraEnabled global String eventDate;
    @AuraEnabled global String status;
    @AuraEnabled global String role;
    @AuraEnabled global String response;
    @AuraEnabled global String attendance;
}
