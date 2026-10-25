/** A headed bullet list on a Power Pack card. */
@JsonAccess(serializable='always' deserializable='always')
global class PPSection {
    @AuraEnabled global String heading;
    @AuraEnabled global List<String> bullets;
}
