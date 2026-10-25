/** Power Pack persona action: PP Diagnostic Journey Brief. All behaviour lives in prompt template PP_Rare_Disease_Brief; this class only wires it up. */
@JsonAccess(serializable='always' deserializable='always')
global class PPDiagnosticJourneyAction {
    @InvocableMethod(label='PP Diagnostic Journey Brief' description='Returns a rare-disease patient-finding opportunity CARD for an HCP or the territory.')
    global static List<PPCardResult> run(List<PPCardRequest> requests) {
        List<PPCardResult> results = new List<PPCardResult>();
        for (PPCardRequest req : requests) {
            PPCardResult r = new PPCardResult();
            r.card = PPCardService.build('rare_disease', 'PP_Rare_Disease_Brief', req, true);
            r.summary = r.card.headline != null ? r.card.headline : r.card.title;
            results.add(r);
        }
        return results;
    }
}