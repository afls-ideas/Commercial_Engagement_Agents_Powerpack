/** Power Pack action: propose a compliant commercial event. Read only; the rep confirms on the card before a Draft event is created. */
global class PPEventPlannerAction {
    @InvocableMethod(label='PP Event Planner' description='Proposes an event (type, date, audience, products, cost breakdown and budget) with a compliance preflight. Does not create any record; the rep confirms on the card.')
    global static List<PPEventPlannerResult> run(List<PPCardRequest> requests) {
        List<PPEventPlannerResult> results = new List<PPEventPlannerResult>();
        for (PPCardRequest req : requests) {
            PPEventPlannerResult r = new PPEventPlannerResult();
            r.card = PPEventPlannerService.build('events', 'PP_Event_Planner', req);
            r.summary = r.card.headline != null ? r.card.headline : r.card.title;
            results.add(r);
        }
        return results;
    }
}