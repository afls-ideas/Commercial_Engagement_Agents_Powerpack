/** Power Pack action: stakeholder coverage and relationship health for an account. All behaviour lives in prompt template PP_Coverage_Map. */
@JsonAccess(serializable='always' deserializable='always')
global class PPCoverageMapAction {
    @InvocableMethod(label='PP Stakeholder Coverage and Relationship Health' description='Returns an org-chart network of an account\'s stakeholders with relationship strength, last contact and coverage gaps.')
    global static List<PPCoverageMapResult> run(List<PPCardRequest> requests) {
        List<PPCoverageMapResult> results = new List<PPCoverageMapResult>();
        for (PPCardRequest req : requests) {
            PPCoverageMapResult r = new PPCoverageMapResult();
            r.card = PPCoverageMapService.build('coverage', 'PP_Coverage_Map', req);
            r.summary = r.card.headline != null ? r.card.headline : r.card.title;
            results.add(r);
        }
        return results;
    }
}