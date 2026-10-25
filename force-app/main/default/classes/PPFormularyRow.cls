/** One account (IDN or payer) on the formulary heatmap, with its decision timeline and risk flag. */
@JsonAccess(serializable='always' deserializable='always')
global class PPFormularyRow {
    @AuraEnabled global String account;
    @AuraEnabled global String accountType;
    @AuraEnabled global List<PPFormularyCell> cells;
    @AuraEnabled global String submitted;
    @AuraEnabled global String decisionDue;
    @AuraEnabled global Integer daysToDecision;
    @AuraEnabled global Integer daysSinceSubmission;
    @AuraEnabled global String risk;
    @AuraEnabled global String riskTone;
    @AuraEnabled global String recordId;
    @AuraEnabled global PPAction action;
}
