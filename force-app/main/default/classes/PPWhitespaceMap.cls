/** Data type behind the whitespace custom Lightning type: potential versus current share, bubbles sized by revenue. */
@JsonAccess(serializable='always' deserializable='always')
global class PPWhitespaceMap {
    @AuraEnabled global String title;
    @AuraEnabled global String subtitle;
    @AuraEnabled global String badge;
    @AuraEnabled global String badgeTone;
    @AuraEnabled global String headline;
    @AuraEnabled global List<PPWhitespaceAccount> accounts;
    @AuraEnabled global List<PPMetric> metrics;
    @AuraEnabled global List<PPSection> sections;
    @AuraEnabled global String nextStep;
    @AuraEnabled global List<PPAction> actions;
}
