/** Data type behind the formulary-status custom Lightning type: accounts x products tier heatmap with decision timelines. */
@JsonAccess(serializable='always' deserializable='always')
global class PPFormularyMap {
    @AuraEnabled global String title;
    @AuraEnabled global String subtitle;
    @AuraEnabled global String badge;
    @AuraEnabled global String badgeTone;
    @AuraEnabled global String headline;
    @AuraEnabled global List<String> products;
    @AuraEnabled global List<PPFormularyRow> rows;
    @AuraEnabled global List<PPMetric> metrics;
    @AuraEnabled global List<PPSection> sections;
    @AuraEnabled global String nextStep;
    @AuraEnabled global List<PPAction> actions;
}
