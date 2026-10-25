/**
 * One row of a Power Pack card table / list (funnel stage, stakeholder, ranked account, checklist item...).
 * status is a short chip label; tone is positive | warning | critical | neutral; score is an optional 0-100 value
 * that persona renderers can draw as a bar or step.
 */
@JsonAccess(serializable='always' deserializable='always')
global class PPRow {
    @AuraEnabled global String label;
    @AuraEnabled global String status;
    @AuraEnabled global String tone;
    @AuraEnabled global String detail;
    @AuraEnabled global Integer score;
    @AuraEnabled global String recordId;
    @AuraEnabled global PPAction action;
}
