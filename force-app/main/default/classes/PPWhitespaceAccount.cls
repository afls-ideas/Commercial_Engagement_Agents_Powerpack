/** One account bubble on the whitespace matrix. potential and share are 0-100; revenue is in thousands of dollars. */
@JsonAccess(serializable='always' deserializable='always')
global class PPWhitespaceAccount {
    @AuraEnabled global String account;
    @AuraEnabled global String segment;
    @AuraEnabled global Integer potential;
    @AuraEnabled global Integer share;
    @AuraEnabled global Integer revenue;
    @AuraEnabled global Integer gap;
    @AuraEnabled global String quadrant;
    @AuraEnabled global String whitespace;
    @AuraEnabled global String barrier;
    @AuraEnabled global String recordId;
    @AuraEnabled global PPAction action;
}
