/** Power Pack action: answer questions about an existing Managed Event (speakers, attendees, attendance history, budget) or one person's event history. Read only. */
global class PPEventBriefAction {
    @InvocableMethod(label='PP Event Brief' description='Answers questions about an existing Managed Event the rep is on or names: who is speaking, who is invited, who attended earlier events, which other events a person was invited to, budget and status. Also shows one HCP\'s event invitation history when the rep is on an account. Read only.')
    global static List<PPEventBriefResult> run(List<PPCardRequest> requests) {
        List<PPEventBriefResult> results = new List<PPEventBriefResult>();
        for (PPCardRequest req : requests) {
            PPEventBriefResult r = new PPEventBriefResult();
            r.card = PPEventBriefService.build('events', 'PP_Event_Brief', req);
            r.summary = r.card.headline != null ? r.card.headline : r.card.title;
            if (r.card.textOnly == true) {
                List<String> parts = new List<String>{ r.summary };
                if (r.card.sections != null) for (PPSection s : r.card.sections) parts.addAll(s.bullets);
                if (r.card.nextStep != null) parts.add(r.card.nextStep);
                r.summary = String.join(parts, ' ');
            }
            results.add(r);
        }
        return results;
    }
}