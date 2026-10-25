/** Output of the event-planner action; `card` is bound to the ppEventPlanner custom Lightning type. */
@JsonAccess(serializable='always' deserializable='always')
global class PPEventPlannerResult {
    @InvocableVariable(label='Event Proposal' description='Proposed event with cost, budget fit and compliance preflight, rendered by the event-planner custom Lightning type')
    global PPEventProposal card;

    @InvocableVariable(label='Summary' description='One-line plain-text summary of the proposal for the planner')
    global String summary;
}
