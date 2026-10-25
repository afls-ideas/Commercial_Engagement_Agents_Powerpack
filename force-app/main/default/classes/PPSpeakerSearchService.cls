/**
 * Speaker Search: finds the target event (the record the rep is on, else their latest draft), evaluates every Approved expert
 * against it in Apex (qualification, location, availability, annual cap, training, fee) and ranks them. The model only words the "why".
 */
public with sharing class PPSpeakerSearchService {

    @TestVisible private static final Integer ANNUAL_CAP = 4;
    @TestVisible private static final Integer TRAINING_MONTHS = 12;

    public class EventCtx {
        public MngEvent ev;
        public String typeName;
        public Set<String> products = new Set<String>();
        public String text = '';
        public String source;
        public Boolean canEdit = true;
    }

    public static PPSpeakerSearch build(String persona, String templateName, PPCardRequest req) {
        try {
            EventCtx ctx = findEvent(req);
            List<PPSpeakerCandidate> all = evaluate(ctx, null, req.question);
            if (all.isEmpty()) return message(ctx, 'No approved speakers found', 'There are no Approved, active experts in the speaker pool.');
            List<PPSpeakerCandidate> top = new List<PPSpeakerCandidate>();
            for (PPSpeakerCandidate c : all) { if (top.size() < 5) top.add(c); }

            List<String> lines = new List<String>();
            for (PPSpeakerCandidate c : top) {
                List<String> cs = new List<String>();
                for (PPEventCheck k : c.checks) cs.add(k.label + '=' + k.level + ' (' + k.detail + ')');
                lines.add(c.name + ' | ' + c.fit + ' (score ' + c.score + ') | ' + c.specialty + ' | ' + nz(c.city) + ' | tier ' + c.tier
                    + ' | fee $' + c.fee + ' | programs this year ' + c.programsYtd + ' | ' + String.join(cs, '; '));
            }
            Map<String, String> inputs = new Map<String, String>{
                'Question' => String.isNotBlank(req.question) ? req.question : 'Recommend a speaker.',
                'Today' => Date.today().format() + ' (' + String.valueOf(Date.today()) + ')',
                'EventContext' => eventText(ctx),
                'Candidates' => String.join(lines, '\n'),
                'ScenarioFacts' => PPContext.scenarioFacts(persona, null)
            };
            String body = PPViewRunner.runJson(templateName, inputs);
            PPSpeakerSearch card = new PPSpeakerSearch();
            Map<String, String> why = new Map<String, String>();
            if (body != null) {
                Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(body);
                card.headline = (String) m.get('headline');
                card.nextStep = (String) m.get('nextStep');
                if (m.get('picks') != null) for (Object o : (List<Object>) m.get('picks')) {
                    Map<String, Object> pm = (Map<String, Object>) o;
                    why.put(((String) pm.get('name')).toLowerCase(), (String) pm.get('why'));
                }
            }
            for (PPSpeakerCandidate c : top) c.why = why.get(c.name.toLowerCase());
            card.candidates = top;
            card.title = 'Speaker shortlist';
            fill(card, ctx);
            return card;
        } catch (Exception e) {
            return message(null, 'Could not search speakers', e.getMessage());
        }
    }

    /** Event to work on: the MngEvent record page the rep is on, else an event named in the request, else their newest draft. Null when none. */
    public static EventCtx findEvent(PPCardRequest req) {
        MngEvent ev = null;
        String source = 'latest draft';
        if (String.isNotBlank(req.accountId)) {
            try {
                Id i = Id.valueOf(req.accountId);
                if (i.getSobjectType() == MngEvent.SObjectType) { ev = loadEvent(i); source = 'record page'; }
            } catch (Exception e) { /* not an id */ }
        }
        if (ev == null && String.isNotBlank(req.accountName)) {
            Id best = bestNameMatch(req.accountName);
            if (best != null) { ev = loadEvent(best); source = 'named'; }
        }
        if (ev == null) {
            List<MngEvent> mine = [SELECT Id FROM MngEvent WHERE CreatedById = :UserInfo.getUserId() AND Status = 'Draft'
                                   ORDER BY CreatedDate DESC LIMIT 1];
            if (!mine.isEmpty()) ev = loadEvent(mine[0].Id);
        }
        if (ev == null) return null;
        EventCtx c = new EventCtx();
        c.ev = ev;
        c.source = source;
        List<UserRecordAccess> ura = [SELECT RecordId, HasEditAccess FROM UserRecordAccess WHERE UserId = :UserInfo.getUserId() AND RecordId = :ev.Id];
        c.canEdit = !ura.isEmpty() && ura[0].HasEditAccess;
        c.typeName = ev.MngEventType.Name;
        for (MngEventProduct p : [SELECT Name FROM MngEventProduct WHERE MngEventId = :ev.Id]) c.products.add(p.Name);
        c.text = nz(ev.Name) + ' ' + nz(ev.Description);
        return c;
    }

    private static final Set<String> STOP = new Set<String>{ 'event', 'events', 'speaker', 'speakers', 'recommend', 'current', 'this', 'that', 'with', 'from', 'for', 'program', 'my' };

    /** The visible event whose name shares the most words with the text, newest first on a tie. Null when no word matches. */
    @TestVisible
    private static Id bestNameMatch(String text) {
        Set<String> words = new Set<String>();
        for (String w : text.toLowerCase().replaceAll('[^a-z0-9 ]', ' ').split(' ')) if (w.length() >= 3 && !STOP.contains(w)) words.add(w);
        Id best = null;
        Integer bestScore = 0;
        for (MngEvent e : [SELECT Id, Name FROM MngEvent WHERE Status != 'Cancelled' ORDER BY StartDateTime DESC NULLS LAST LIMIT 200]) {
            String n = e.Name.toLowerCase();
            Integer sc = 0;
            for (String w : words) if (n.contains(w)) sc++;
            if (sc > bestScore) { bestScore = sc; best = e.Id; }
        }
        return best;
    }

    /** Names of the rep's open events, so the card can offer them when no event could be resolved. */
    private static String openEvents() {
        List<String> n = new List<String>();
        for (MngEvent e : [SELECT Name, Status, StartDateTime FROM MngEvent WHERE CreatedById = :UserInfo.getUserId() AND Status != 'Cancelled'
                           ORDER BY CreatedDate DESC LIMIT 8]) n.add(e.Name + ' (' + e.Status + ')');
        return n.isEmpty() ? 'You have no events yet. Ask the planner to propose one.' : 'Your recent events: ' + String.join(n, '; ') + '. Say which one to use.';
    }

    private static MngEvent loadEvent(Id i) {
        List<MngEvent> l = [SELECT Id, Name, Status, StartDateTime, Description, MngEventTypeId, MngEventType.Name FROM MngEvent WHERE Id = :i LIMIT 1];
        return l.isEmpty() ? null : l[0];
    }

    /** Evaluates Approved experts (or only `onlyIds`) against the event, best first. Blocked candidates sort last. */
    public static List<PPSpeakerCandidate> evaluate(EventCtx ctx, Set<Id> onlyIds, String question) {
        Date evDate = ctx == null || ctx.ev.StartDateTime == null ? Date.today().addDays(21) : ctx.ev.StartDateTime.date();
        String locText = (ctx == null ? '' : ctx.text) + ' ' + nz(question);
        String evText = locText.toLowerCase();

        List<Expert> experts = onlyIds == null
            ? [SELECT Id, Name, AccountId, Account.PersonMailingCity, Account.PersonMailingState, AdditionalInformation FROM Expert WHERE Status = 'Approved' AND IsActive = true LIMIT 200]
            : [SELECT Id, Name, AccountId, Account.PersonMailingCity, Account.PersonMailingState, AdditionalInformation FROM Expert WHERE Id IN :onlyIds AND Status = 'Approved' AND IsActive = true];
        Set<Id> ids = new Map<Id, Expert>(experts).keySet();

        Map<Id, List<ExpertSubject>> subs = new Map<Id, List<ExpertSubject>>();
        for (ExpertSubject s : [SELECT ExpertId, Subject.Name, EffectiveDateTime, ExpirationDateTime FROM ExpertSubject WHERE ExpertId IN :ids]) {
            if (!subs.containsKey(s.ExpertId)) subs.put(s.ExpertId, new List<ExpertSubject>());
            subs.get(s.ExpertId).add(s);
        }
        Date yearStart = Date.newInstance(evDate.year(), 1, 1);
        Datetime yS = Datetime.newInstance(yearStart, Time.newInstance(0, 0, 0, 0));
        Datetime yE = Datetime.newInstance(yearStart.addYears(1), Time.newInstance(0, 0, 0, 0));
        Map<Id, Integer> ytd = new Map<Id, Integer>();
        Map<Id, String> clash = new Map<Id, String>();
        Set<Id> onThis = new Set<Id>();
        Datetime dayLo = Datetime.newInstance(evDate.addDays(-1), Time.newInstance(0, 0, 0, 0));
        Datetime dayHi = Datetime.newInstance(evDate.addDays(2), Time.newInstance(0, 0, 0, 0));
        for (MngEventParticipant p : [SELECT ParticipantId, MngEventId, MngEvent.Name, MngEvent.StartDateTime FROM MngEventParticipant
                                      WHERE ParticipantId IN :ids AND MngEvent.Status != 'Cancelled' AND MngEvent.StartDateTime >= :yS AND MngEvent.StartDateTime < :yE]) {
            ytd.put(p.ParticipantId, (ytd.containsKey(p.ParticipantId) ? ytd.get(p.ParticipantId) : 0) + 1);
            if (ctx != null && p.MngEventId == ctx.ev.Id) onThis.add(p.ParticipantId);
            else if (p.MngEvent.StartDateTime >= dayLo && p.MngEvent.StartDateTime < dayHi) clash.put(p.ParticipantId, p.MngEvent.Name);
        }

        List<PPSpeakerCandidate> out = new List<PPSpeakerCandidate>();
        for (Expert e : experts) {
            Map<String, String> info = parse(e.AdditionalInformation);
            PPSpeakerCandidate c = new PPSpeakerCandidate();
            c.expertId = e.Id;
            c.accountId = e.AccountId;
            c.name = e.Name.replace(' Speaker Profile', '').replace(' Faculty Profile', '').replace(' Congress', '').replace(' Advisory', '');
            c.specialty = info.get('SPECIALTY');
            c.city = e.Account.PersonMailingCity;
            c.tier = info.containsKey('TIER') ? Integer.valueOf(info.get('TIER')) : null;
            c.fee = info.containsKey('FEE') ? Decimal.valueOf(info.get('FEE')) : null;
            c.trained = info.get('TRAINED');
            c.programsYtd = ytd.containsKey(e.Id) ? ytd.get(e.Id) : 0;
            c.checks = new List<PPEventCheck>();
            Integer score = 0;

            // Product qualification
            Boolean qualified = false;
            String sub = '';
            for (ExpertSubject s : subs.containsKey(e.Id) ? subs.get(e.Id) : new List<ExpertSubject>()) {
                String sn = s.Subject.Name.toLowerCase();
                Boolean relevant = evText.contains(sn);
                for (String pn : ctx == null ? new Set<String>() : ctx.products) if (pn.toLowerCase().contains(sn)) relevant = true;
                Boolean current = s.EffectiveDateTime.date() <= evDate && (s.ExpirationDateTime == null || s.ExpirationDateTime.date() > evDate);
                if (relevant && current) { qualified = true; sub = s.Subject.Name; }
            }
            if (qualified) { score += 40; c.checks.add(new PPEventCheck('Qualified', 'pass', 'Qualified to speak on ' + sub + '.')); }
            else c.checks.add(new PPEventCheck('Qualified', 'block', 'Not qualified on the product for this event.'));

            // Location
            String city = nz(c.city).toLowerCase();
            String state = nz(e.Account.PersonMailingState).toLowerCase();
            if (city != '' && evText.contains(city)) { score += 25; c.checks.add(new PPEventCheck('Location', 'pass', 'Based in ' + c.city + '.')); }
            else if (state != '' && evText.contains(state)) { score += 10; c.checks.add(new PPEventCheck('Location', 'pass', 'Same state, ' + nz(c.city) + '.')); }
            else c.checks.add(new PPEventCheck('Location', 'warn', nz(c.city) == '' ? 'Location unknown.' : 'Based in ' + c.city + '; travel needed.'));

            // Availability
            if (onThis.contains(e.Id)) c.checks.add(new PPEventCheck('Availability', 'block', 'Already on this event.'));
            else if (clash.containsKey(e.Id)) c.checks.add(new PPEventCheck('Availability', 'block', 'Booked for ' + clash.get(e.Id) + ' around that date.'));
            else { score += 10; c.checks.add(new PPEventCheck('Availability', 'pass', 'No other program within a day.')); }

            // Annual cap
            if (c.programsYtd >= ANNUAL_CAP) c.checks.add(new PPEventCheck('Annual cap', 'block', c.programsYtd + ' programs this year; the cap is ' + ANNUAL_CAP + '.'));
            else if (c.programsYtd == ANNUAL_CAP - 1) { score += 5; c.checks.add(new PPEventCheck('Annual cap', 'warn', c.programsYtd + ' of ' + ANNUAL_CAP + ' programs used this year.')); }
            else { score += 15; c.checks.add(new PPEventCheck('Annual cap', 'pass', c.programsYtd + ' of ' + ANNUAL_CAP + ' programs used this year.')); }

            // Training
            Date tr = PPViewRunner.parseDate(c.trained);
            if (tr != null && tr.addMonths(TRAINING_MONTHS) > evDate) { score += 10; c.checks.add(new PPEventCheck('Training', 'pass', 'Trained ' + c.trained + '.')); }
            else c.checks.add(new PPEventCheck('Training', 'warn', tr == null ? 'No speaker training on file.' : 'Training from ' + c.trained + ' is over ' + TRAINING_MONTHS + ' months old.'));

            // Fee
            if (c.fee != null && c.fee > PPEventPlannerService.SPEAKER_FEE_CAP) {
                score -= 5;
                c.checks.add(new PPEventCheck('Fee', 'warn', 'Rate $' + c.fee.setScale(0).format() + ' is above $' + PPEventPlannerService.SPEAKER_FEE_CAP.setScale(0).format() + ' and needs fair-market-value review.'));
            } else if (c.fee != null) c.checks.add(new PPEventCheck('Fee', 'pass', 'Rate $' + c.fee.setScale(0).format() + ' (tier ' + c.tier + ').'));

            Boolean block = false;
            for (PPEventCheck k : c.checks) if (k.level == 'block') block = true;
            c.score = block ? 0 : Math.max(0, Math.min(100, score));
            c.fit = block ? 'Not eligible' : (c.score >= 80 ? 'Strong fit' : (c.score >= 55 ? 'Good fit' : 'Possible'));
            c.canAdd = !block && ctx != null && ctx.ev.Status == 'Draft' && ctx.canEdit;
            c.added = onThis.contains(e.Id);
            out.add(c);
        }
        List<PPSpeakerCandidate> sorted = new List<PPSpeakerCandidate>();
        for (Integer s = 100; s >= 0; s--) for (PPSpeakerCandidate c : out) if (c.score == s) sorted.add(c);
        return sorted;
    }

    private static void fill(PPSpeakerSearch card, EventCtx ctx) {
        Integer eligible = 0;
        for (PPSpeakerCandidate c : card.candidates) if (c.fit != 'Not eligible') eligible++;
        if (ctx == null) {
            card.subtitle = 'No event selected';
            card.badge = 'No event';
            card.badgeTone = 'warning';
            card.sections = new List<PPSection>{ PPViewRunner.section('No event selected', openEvents()) };
        } else {
            card.eventId = ctx.ev.Id;
            card.eventName = ctx.ev.Name;
            card.subtitle = ctx.ev.Name + (ctx.ev.StartDateTime == null ? '' : ' - ' + ctx.ev.StartDateTime.format('yyyy-MM-dd')) + ' (' + ctx.source + ')';
            card.badge = eligible + ' eligible';
            card.badgeTone = eligible == 0 ? 'critical' : 'positive';
            if (!ctx.canEdit) card.sections = new List<PPSection>{ PPViewRunner.section('View only', 'You can see this event but not edit it, so you cannot add a speaker here. Ask the event owner, or pick one of your own events.') };
            else if (ctx.ev.Status != 'Draft') card.sections = new List<PPSection>{ PPViewRunner.section('Event is ' + ctx.ev.Status, 'Speakers can only be added to a Draft event.') };
        }
    }

    private static String eventText(EventCtx ctx) {
        if (ctx == null) return 'No event selected. Rank generally.';
        return 'EVENT: ' + ctx.ev.Name + ' | type ' + ctx.typeName + ' | status ' + ctx.ev.Status + ' | start '
            + (ctx.ev.StartDateTime == null ? 'n/a' : ctx.ev.StartDateTime.format('yyyy-MM-dd HH:mm')) + ' | products '
            + (ctx.products.isEmpty() ? 'none' : String.join(new List<String>(ctx.products), ', ')) + ' | ' + nz(ctx.ev.Description);
    }

    /** "KEY: value | KEY: value" -> map. */
    @TestVisible
    private static Map<String, String> parse(String s) {
        Map<String, String> m = new Map<String, String>();
        if (s == null) return m;
        for (String part : s.split('\\|')) {
            Integer i = part.indexOf(':');
            if (i > 0) m.put(part.substring(0, i).trim().toUpperCase(), part.substring(i + 1).trim());
        }
        return m;
    }

    private static String nz(String s) { return s == null ? '' : s; }

    private static PPSpeakerSearch message(EventCtx ctx, String headline, String body) {
        PPSpeakerSearch c = new PPSpeakerSearch();
        c.title = 'Speaker shortlist';
        c.headline = headline;
        c.candidates = new List<PPSpeakerCandidate>();
        c.sections = new List<PPSection>{ PPViewRunner.section('Details', body) };
        return c;
    }
}
