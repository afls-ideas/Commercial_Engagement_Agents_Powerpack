/** Data type behind the account-plan custom Lightning type: a goal tree with plan-health gauge and SWOT. */
@JsonAccess(serializable='always' deserializable='always')
global class PPAccountPlan {
    @AuraEnabled global String title;
    @AuraEnabled global String subtitle;
    @AuraEnabled global String badge;
    @AuraEnabled global String badgeTone;
    @AuraEnabled global String headline;
    @AuraEnabled global Integer planHealth;
    @AuraEnabled global String healthSummary;
    @AuraEnabled global List<PPPlanObjective> objectives;
    @AuraEnabled global List<PPSection> swot;
    @AuraEnabled global List<PPSection> sections;
    @AuraEnabled global String nextStep;
    @AuraEnabled global List<PPAction> actions;
}
