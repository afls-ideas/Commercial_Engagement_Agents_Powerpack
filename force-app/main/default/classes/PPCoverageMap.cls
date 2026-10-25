/** Data type behind the stakeholder-coverage custom Lightning type: an org-chart network with relationship-strength rings and coverage gaps. */
@JsonAccess(serializable='always' deserializable='always')
global class PPCoverageMap {
    @AuraEnabled global String title;
    @AuraEnabled global String subtitle;
    @AuraEnabled global String badge;
    @AuraEnabled global String badgeTone;
    @AuraEnabled global String headline;
    @AuraEnabled global List<PPCoverageNode> nodes;
    @AuraEnabled global List<PPMetric> metrics;
    @AuraEnabled global List<PPSection> sections;
    @AuraEnabled global String nextStep;
    @AuraEnabled global List<PPAction> actions;
}
