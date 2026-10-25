/**
 * Shared data type behind every Power Pack custom Lightning type (the five persona CLTs all bind to this class
 * and differ only in their LWC renderer). The LLM prompt template returns JSON in exactly this shape, so the
 * template — not Apex — decides the content; the LWC decides the layout.
 *
 * CLT rules (see docs/LIGHTNING_TYPES.md): top-level global class, @AuraEnabled fields, @JsonAccess.
 */
@JsonAccess(serializable='always' deserializable='always')
global class PPCard {
    @AuraEnabled global String variant;
    @AuraEnabled global String title;
    @AuraEnabled global String subtitle;
    @AuraEnabled global String badge;
    @AuraEnabled global String badgeTone;
    @AuraEnabled global String headline;
    @AuraEnabled global List<PPMetric> metrics;
    @AuraEnabled global String rowsHeading;
    @AuraEnabled global List<PPRow> rows;
    @AuraEnabled global List<PPSection> sections;
    @AuraEnabled global String nextStep;
    @AuraEnabled global List<PPAction> actions;
}
