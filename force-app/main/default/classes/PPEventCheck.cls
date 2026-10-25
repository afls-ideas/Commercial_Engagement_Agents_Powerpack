/** A compliance preflight result. level: pass | warn | block. Computed in Apex, never by the model. */
@JsonAccess(serializable='always' deserializable='always')
global class PPEventCheck {
    @AuraEnabled global String label;
    @AuraEnabled global String level;
    @AuraEnabled global String detail;

    public PPEventCheck() {}

    public PPEventCheck(String label, String level, String detail) {
        this.label = label;
        this.level = level;
        this.detail = detail;
    }
}
