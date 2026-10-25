/** Data type behind the Event Brief custom Lightning type: an existing event (or one person's event history) with speakers, attendees and their attendance history. */
@JsonAccess(serializable='always' deserializable='always')
global class PPEventBrief {
    @AuraEnabled global String title;
    @AuraEnabled global String subtitle;
    @AuraEnabled global String badge;
    @AuraEnabled global String badgeTone;
    @AuraEnabled global String headline;
    @AuraEnabled global String eventId;
    @AuraEnabled global String eventName;
    @AuraEnabled global String focus;
    @AuraEnabled global List<PPMetric> metrics;
    @AuraEnabled global List<PPMetric> facts;
    @AuraEnabled global List<PPSection> sections;
    @AuraEnabled global List<PPEventPerson> speakers;
    @AuraEnabled global List<PPEventPerson> attendees;
    @AuraEnabled global List<PPEventPerson> colleagues;
    @AuraEnabled global Integer moreAttendees;
    @AuraEnabled global String nextStep;
}
