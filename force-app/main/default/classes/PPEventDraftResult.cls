/** Result of creating or cancelling a draft event from the card. */
global class PPEventDraftResult {
    @AuraEnabled global String eventId;
    @AuraEnabled global String eventName;
    @AuraEnabled global String message;
    @AuraEnabled global String proposalJson;
}
