/** Output of the QBR action; `card` is bound to the ppQbr custom Lightning type. */
@JsonAccess(serializable='always' deserializable='always')
global class PPQbrResult {
    @InvocableVariable(label='QBR Storyboard' description='Structured QBR storyboard rendered by the QBR custom Lightning type')
    global PPQbr card;

    @InvocableVariable(label='Summary' description='One-line plain-text summary for the planner')
    global String summary;
}
