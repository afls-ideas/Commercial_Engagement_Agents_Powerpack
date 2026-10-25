/** Power Pack action: formulary and pathway status across accounts. All behaviour lives in prompt template PP_Formulary_Map. */
@JsonAccess(serializable='always' deserializable='always')
global class PPFormularyMapAction {
    @InvocableMethod(label='PP Formulary and Pathway Status' description='Returns a heatmap of formulary and pathway tier by account and product with submission-to-decision timelines and risk flags, for market access and national account roles.')
    global static List<PPFormularyMapResult> run(List<PPCardRequest> requests) {
        List<PPFormularyMapResult> results = new List<PPFormularyMapResult>();
        for (PPCardRequest req : requests) {
            PPFormularyMapResult r = new PPFormularyMapResult();
            r.card = PPFormularyMapService.build('formulary', 'PP_Formulary_Map', req);
            r.summary = r.card.headline != null ? r.card.headline : r.card.title;
            results.add(r);
        }
        return results;
    }
}