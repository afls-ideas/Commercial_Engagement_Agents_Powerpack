/** Power Pack action: P&T / pathways committee stakeholder map. All behaviour lives in prompt template PP_Committee_Map. */
@JsonAccess(serializable='always' deserializable='always')
global class PPCommitteeMapAction {
    @InvocableMethod(label='PP Committee Stakeholder Map' description='Returns a chart of the committee members who decide on a health system formulary or pathway, with each member\'s position, influence, wants and a suggested approach.')
    global static List<PPCommitteeMapResult> run(List<PPCardRequest> requests) {
        List<PPCommitteeMapResult> results = new List<PPCommitteeMapResult>();
        for (PPCardRequest req : requests) {
            PPCommitteeMapResult r = new PPCommitteeMapResult();
            r.card = PPCommitteeMapService.build('health_system', 'PP_Committee_Map', req);
            r.summary = r.card.headline != null ? r.card.headline : r.card.title;
            results.add(r);
        }
        return results;
    }
}