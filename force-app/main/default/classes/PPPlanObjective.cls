/** One objective on the account-plan canvas: owner, KPI target versus actual, progress and the initiatives underneath it. */
@JsonAccess(serializable='always' deserializable='always')
global class PPPlanObjective {
    @AuraEnabled global String title;
    @AuraEnabled global String owner;
    @AuraEnabled global String kpi;
    @AuraEnabled global String baseline;
    @AuraEnabled global String target;
    @AuraEnabled global String actual;
    @AuraEnabled global Integer progress;
    @AuraEnabled global String status;
    @AuraEnabled global String due;
    @AuraEnabled global List<String> initiatives;
    @AuraEnabled global PPAction action;
}
