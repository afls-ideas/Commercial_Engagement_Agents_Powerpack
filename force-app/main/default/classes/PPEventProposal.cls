/** Data type behind the Event Planner custom Lightning type: a proposed event with cost, budget fit and a compliance preflight. The rep confirms before anything is written. */
@JsonAccess(serializable='always' deserializable='always')
global class PPEventProposal {
    @AuraEnabled global String title;
    @AuraEnabled global String subtitle;
    @AuraEnabled global String badge;
    @AuraEnabled global String badgeTone;
    @AuraEnabled global String headline;
    @AuraEnabled global String eventName;
    @AuraEnabled global String eventType;
    @AuraEnabled global String eventTypeId;
    @AuraEnabled global String mode;
    @AuraEnabled global String locationType;
    @AuraEnabled global String city;
    @AuraEnabled global String startDate;
    @AuraEnabled global String startTime;
    @AuraEnabled global Integer durationHours;
    @AuraEnabled global Integer attendees;
    @AuraEnabled global String audience;
    @AuraEnabled global String description;
    @AuraEnabled global List<String> products;
    @AuraEnabled global List<PPEventExpense> expenses;
    @AuraEnabled global Decimal totalCost;
    @AuraEnabled global Decimal costPerAttendee;
    @AuraEnabled global String budgetName;
    @AuraEnabled global String budgetId;
    @AuraEnabled global Decimal budgetRemaining;
    @AuraEnabled global List<PPEventCheck> checks;
    @AuraEnabled global List<PPEventOption> options;
    @AuraEnabled global Boolean canCreate;
    @AuraEnabled global List<PPSection> sections;
    @AuraEnabled global String nextStep;
    @AuraEnabled global List<PPAction> actions;
}
