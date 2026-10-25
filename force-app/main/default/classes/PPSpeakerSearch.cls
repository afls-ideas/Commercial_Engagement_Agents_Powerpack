/** Data type behind the Speaker Search custom Lightning type: ranked approved speakers for an event, with an add-as-speaker button per speaker. */
@JsonAccess(serializable='always' deserializable='always')
global class PPSpeakerSearch {
    @AuraEnabled global String title;
    @AuraEnabled global String subtitle;
    @AuraEnabled global String badge;
    @AuraEnabled global String badgeTone;
    @AuraEnabled global String headline;
    @AuraEnabled global String eventId;
    @AuraEnabled global String eventName;
    @AuraEnabled global List<PPSpeakerCandidate> candidates;
    @AuraEnabled global List<PPSection> sections;
    @AuraEnabled global String nextStep;
}
