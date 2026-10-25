/** Output of the speaker-search action; `card` is bound to the ppSpeakerSearch custom Lightning type. */
@JsonAccess(serializable='always' deserializable='always')
global class PPSpeakerSearchResult {
    @InvocableVariable(label='Speaker Search' description='Ranked approved speakers for the event, rendered by the speaker-search custom Lightning type')
    global PPSpeakerSearch card;

    @InvocableVariable(label='Summary' description='One-line plain-text summary of the shortlist for the planner')
    global String summary;
}
