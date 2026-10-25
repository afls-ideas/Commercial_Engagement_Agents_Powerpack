/** Actions grouped by function (Sales, Market Access, Medical, Marketing, Operations). */
@JsonAccess(serializable='always' deserializable='always')
global class PPQbrLane {
    @AuraEnabled global String lane;
    @AuraEnabled global List<PPQbrAction> actions;
}
