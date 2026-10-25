/** One product's pathway/formulary tier at one account. tier: Preferred | Alternate | Restricted | Not reviewed. */
@JsonAccess(serializable='always' deserializable='always')
global class PPFormularyCell {
    @AuraEnabled global String product;
    @AuraEnabled global String tier;
    @AuraEnabled global String note;
}
