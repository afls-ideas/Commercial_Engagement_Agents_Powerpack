/**
 * One decision-maker on a committee (P&T, pathways, value analysis...). position runs -100 (opposed) to +100 (champion),
 * influence 0-100. wants / thinks / approach are the annotations shown beside the chart point.
 */
@JsonAccess(serializable='always' deserializable='always')
global class PPCommitteeMember {
    @AuraEnabled global String name;
    @AuraEnabled global String role;
    @AuraEnabled global String committee;
    @AuraEnabled global String stance;
    @AuraEnabled global Integer position;
    @AuraEnabled global Integer influence;
    @AuraEnabled global Boolean isVoter;
    @AuraEnabled global String wants;
    @AuraEnabled global String thinks;
    @AuraEnabled global String approach;
    @AuraEnabled global String lastContact;
    @AuraEnabled global String recordId;
    @AuraEnabled global PPAction action;
}
