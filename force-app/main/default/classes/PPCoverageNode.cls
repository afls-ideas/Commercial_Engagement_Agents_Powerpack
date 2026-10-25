/** One person in the account relationship network. strength 0-100; status (Covered | Cooling | Gap) and daysSince are computed in Apex. */
@JsonAccess(serializable='always' deserializable='always')
global class PPCoverageNode {
    @AuraEnabled global String name;
    @AuraEnabled global String role;
    @AuraEnabled global String tier;
    @AuraEnabled global String reportsTo;
    @AuraEnabled global Integer strength;
    @AuraEnabled global String lastContact;
    @AuraEnabled global Integer daysSince;
    @AuraEnabled global String owner;
    @AuraEnabled global String status;
    @AuraEnabled global String note;
    @AuraEnabled global String recordId;
    @AuraEnabled global PPAction action;
}
