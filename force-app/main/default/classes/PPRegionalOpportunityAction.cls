/** Power Pack persona action: PP Regional Opportunity Brief. All behaviour lives in prompt template PP_Cardio_Regional_Brief; this class only wires it up. */
@JsonAccess(serializable='always' deserializable='always')
global class PPRegionalOpportunityAction {
    @InvocableMethod(label='PP Regional Opportunity Brief' description='Returns a prevalence-versus-penetration opportunity CARD for a cardiology rep in a high-prevalence region.')
    global static List<PPCardResult> run(List<PPCardRequest> requests) {
        List<PPCardResult> results = new List<PPCardResult>();
        for (PPCardRequest req : requests) {
            PPCardResult r = new PPCardResult();
            r.card = PPCardService.build('cardio_regional', 'PP_Cardio_Regional_Brief', req, true);
            r.summary = r.card.headline != null ? r.card.headline : r.card.title;
            results.add(r);
        }
        return results;
    }
}