/** Output of the committee-map action; `card` is bound to the ppCommitteeMap custom Lightning type. */
@JsonAccess(serializable='always' deserializable='always')
global class PPCommitteeMapResult {
    @InvocableVariable(label='Committee Map' description='Structured stakeholder map rendered by the committee-map custom Lightning type')
    global PPCommitteeMap card;

    @InvocableVariable(label='Summary' description='One-line plain-text summary of the map for the planner')
    global String summary;
}
