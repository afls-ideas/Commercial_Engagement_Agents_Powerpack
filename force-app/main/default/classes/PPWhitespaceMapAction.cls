/** Power Pack action: whitespace and opportunity across key accounts. All behaviour lives in prompt template PP_Whitespace_Map. */
@JsonAccess(serializable='always' deserializable='always')
global class PPWhitespaceMapAction {
    @InvocableMethod(label='PP Whitespace and Opportunity' description='Returns a bubble matrix of key accounts by potential versus current share, sized by revenue, with Grow / Defend / Develop / Maintain quadrants and where the whitespace is.')
    global static List<PPWhitespaceMapResult> run(List<PPCardRequest> requests) {
        List<PPWhitespaceMapResult> results = new List<PPWhitespaceMapResult>();
        for (PPCardRequest req : requests) {
            PPWhitespaceMapResult r = new PPWhitespaceMapResult();
            r.card = PPWhitespaceMapService.build('whitespace', 'PP_Whitespace_Map', req);
            r.summary = r.card.headline != null ? r.card.headline : r.card.title;
            results.add(r);
        }
        return results;
    }
}