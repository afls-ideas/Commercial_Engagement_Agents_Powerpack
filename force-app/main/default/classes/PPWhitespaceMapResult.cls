/** Output of the whitespace action; `card` is bound to the ppWhitespaceMap custom Lightning type. */
@JsonAccess(serializable='always' deserializable='always')
global class PPWhitespaceMapResult {
    @InvocableVariable(label='Whitespace Map' description='Structured bubble matrix rendered by the whitespace custom Lightning type')
    global PPWhitespaceMap card;

    @InvocableVariable(label='Summary' description='One-line plain-text summary for the planner')
    global String summary;
}
