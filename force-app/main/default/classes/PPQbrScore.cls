/** One scorecard line: plan versus actual. attainment (percent of plan) and status are computed in Apex. */
@JsonAccess(serializable='always' deserializable='always')
global class PPQbrScore {
    @AuraEnabled global String metric;
    @AuraEnabled global Decimal plan;
    @AuraEnabled global Decimal actual;
    @AuraEnabled global String unit;
    @AuraEnabled global Integer attainment;
    @AuraEnabled global String status;
}
