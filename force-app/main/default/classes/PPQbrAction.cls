/** An action item assigned to a function. */
@JsonAccess(serializable='always' deserializable='always')
global class PPQbrAction {
    @AuraEnabled global String text;
    @AuraEnabled global String owner;
    @AuraEnabled global String due;
}
