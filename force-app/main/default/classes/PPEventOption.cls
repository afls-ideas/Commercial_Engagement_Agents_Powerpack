/** An alternative event format the planner considered. */
@JsonAccess(serializable='always' deserializable='always')
global class PPEventOption {
    @AuraEnabled global String eventType;
    @AuraEnabled global String why;
    @AuraEnabled global Decimal estCost;
    @AuraEnabled global Integer attendees;
}
