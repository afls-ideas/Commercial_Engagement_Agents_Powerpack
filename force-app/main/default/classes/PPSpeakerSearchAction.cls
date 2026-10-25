/** Power Pack action: recommend approved speakers for an event. Read only; the rep adds a speaker with the button on the card. */
global class PPSpeakerSearchAction {
    @InvocableMethod(label='PP Speaker Search' description='Recommends approved, qualified speakers for an event (the event record the rep is on, or their latest draft), ranked with compliance checks. Adds nobody; the rep confirms on the card.')
    global static List<PPSpeakerSearchResult> run(List<PPCardRequest> requests) {
        List<PPSpeakerSearchResult> results = new List<PPSpeakerSearchResult>();
        for (PPCardRequest req : requests) {
            PPSpeakerSearchResult r = new PPSpeakerSearchResult();
            r.card = PPSpeakerSearchService.build('events', 'PP_Speaker_Search', req);
            r.summary = r.card.headline != null ? r.card.headline : r.card.title;
            results.add(r);
        }
        return results;
    }
}