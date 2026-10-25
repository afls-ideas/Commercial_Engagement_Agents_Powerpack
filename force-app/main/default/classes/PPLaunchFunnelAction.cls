/** Power Pack persona action: PP Launch Funnel Brief. All behaviour lives in prompt template PP_Myeloma_Launch_Brief; this class only wires it up. */
@JsonAccess(serializable='always' deserializable='always')
global class PPLaunchFunnelAction {
    @InvocableMethod(label='PP Launch Funnel Brief' description='Returns a launch-funnel and referral-pathway CARD for a multiple myeloma launch HCP or for the whole territory.')
    global static List<PPCardResult> run(List<PPCardRequest> requests) {
        List<PPCardResult> results = new List<PPCardResult>();
        for (PPCardRequest req : requests) {
            PPCardResult r = new PPCardResult();
            r.card = PPCardService.build('myeloma_launch', 'PP_Myeloma_Launch_Brief', req, true);
            r.summary = r.card.headline != null ? r.card.headline : r.card.title;
            results.add(r);
        }
        return results;
    }
}