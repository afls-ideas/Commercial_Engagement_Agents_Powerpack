/** Power Pack action: cross-functional account huddle / quarterly business review prep. All behaviour lives in prompt template PP_Qbr. */
@JsonAccess(serializable='always' deserializable='always')
global class PPQbrBuilderAction {
    @InvocableMethod(label='PP QBR Prep' description='Returns a quarterly business review storyboard for an account: timeline, scorecard versus plan, decisions needed and actions assigned by function, within the commercial/medical sharing rules.')
    global static List<PPQbrResult> run(List<PPCardRequest> requests) {
        List<PPQbrResult> results = new List<PPQbrResult>();
        for (PPCardRequest req : requests) {
            PPQbrResult r = new PPQbrResult();
            r.card = PPQbrService.build('qbr', 'PP_Qbr', req);
            r.summary = r.card.headline != null ? r.card.headline : r.card.title;
            results.add(r);
        }
        return results;
    }
}