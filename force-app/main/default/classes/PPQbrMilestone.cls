/** A dated milestone on the QBR timeline. status: done | next | risk. */
@JsonAccess(serializable='always' deserializable='always')
global class PPQbrMilestone {
    @AuraEnabled global String eventDate;
    @AuraEnabled global String label;
    @AuraEnabled global String status;
    @AuraEnabled global Integer daysFromToday;
}
