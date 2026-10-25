/** Output of the event-brief action; `card` is bound to the ppEventBrief custom Lightning type. */
@JsonAccess(serializable='always' deserializable='always')
global class PPEventBriefResult {
    @InvocableVariable(label='Event Brief' description='An existing event with its speakers, attendees and attendance history, rendered by the event-brief custom Lightning type')
    global PPEventBrief card;

    @InvocableVariable(label='Summary' description='One-line plain-text answer for the planner')
    global String summary;
}
