/** A decision the customer or the internal team must make at the QBR. */
@JsonAccess(serializable='always' deserializable='always')
global class PPQbrDecision {
    @AuraEnabled global String decision;
    @AuraEnabled global String owner;
    @AuraEnabled global String needBy;
    @AuraEnabled global String recommendation;
    @AuraEnabled global PPAction action;
}
