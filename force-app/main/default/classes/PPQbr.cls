/** Data type behind the QBR storyboard custom Lightning type: timeline, scorecard versus plan, decisions needed and actions by function. */
@JsonAccess(serializable='always' deserializable='always')
global class PPQbr {
    @AuraEnabled global String title;
    @AuraEnabled global String subtitle;
    @AuraEnabled global String badge;
    @AuraEnabled global String badgeTone;
    @AuraEnabled global String headline;
    @AuraEnabled global List<PPQbrMilestone> milestones;
    @AuraEnabled global List<PPQbrScore> scorecard;
    @AuraEnabled global List<PPQbrDecision> decisions;
    @AuraEnabled global List<PPQbrLane> lanes;
    @AuraEnabled global List<PPSection> sections;
    @AuraEnabled global String nextStep;
    @AuraEnabled global List<PPAction> actions;
}
