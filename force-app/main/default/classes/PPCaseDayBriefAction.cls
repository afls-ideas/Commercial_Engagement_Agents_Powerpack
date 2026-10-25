/** Power Pack persona action: PP Case Day Brief. All behaviour lives in prompt template PP_Medtech_Case_Brief; this class only wires it up. */
@JsonAccess(serializable='always' deserializable='always')
global class PPCaseDayBriefAction {
    @InvocableMethod(label='PP Case Day Brief' description='Returns a case-day checklist and physician-profile CARD for a medtech cath lab or structural heart rep.')
    global static List<PPCardResult> run(List<PPCardRequest> requests) {
        List<PPCardResult> results = new List<PPCardResult>();
        for (PPCardRequest req : requests) {
            PPCardResult r = new PPCardResult();
            r.card = PPCardService.build('medtech_cath', 'PP_Medtech_Case_Brief', req, false);
            r.summary = r.card.headline != null ? r.card.headline : r.card.title;
            results.add(r);
        }
        return results;
    }
}