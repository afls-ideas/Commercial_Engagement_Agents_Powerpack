/**
 * Data type behind the committee stakeholder-map custom Lightning type. The prompt template returns JSON in this shape;
 * the LWC draws members as an influence-vs-position chart and annotates the selected member.
 */
@JsonAccess(serializable='always' deserializable='always')
global class PPCommitteeMap {
    @AuraEnabled global String title;
    @AuraEnabled global String subtitle;
    @AuraEnabled global String badge;
    @AuraEnabled global String badgeTone;
    @AuraEnabled global String headline;
    @AuraEnabled global String decision;
    @AuraEnabled global String decisionDate;
    @AuraEnabled global String votesNeeded;
    @AuraEnabled global List<PPCommitteeMember> members;
    @AuraEnabled global List<PPSection> sections;
    @AuraEnabled global String nextStep;
    @AuraEnabled global List<PPAction> actions;
}
