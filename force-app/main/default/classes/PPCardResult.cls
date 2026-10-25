/** Shared output for every Power Pack persona action; `card` is bound to the persona's custom Lightning type. */
@JsonAccess(serializable='always' deserializable='always')
global class PPCardResult {
    @InvocableVariable(label='Card' description='Structured card rendered by the persona custom Lightning type')
    global PPCard card;

    @InvocableVariable(label='Summary' description='One-line plain-text summary of the card for the planner')
    global String summary;
}
