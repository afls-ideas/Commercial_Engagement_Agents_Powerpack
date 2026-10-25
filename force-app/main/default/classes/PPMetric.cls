/** A headline number on a Power Pack card (e.g. "Treated patients: 2"). tone: positive | warning | critical | neutral. */
@JsonAccess(serializable='always' deserializable='always')
global class PPMetric {
    @AuraEnabled global String label;
    @AuraEnabled global String value;
    @AuraEnabled global String tone;
}
