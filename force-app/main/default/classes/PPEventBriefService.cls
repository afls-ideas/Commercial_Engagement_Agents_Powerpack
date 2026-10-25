/**
 * Event assistant: loads everything about a Managed Event (fields, products, budget, expenses, every participant with their profile,
 * invitation, response and attendance, and each person's earlier events) or about one person's event history, and hands it to the
 * PP_Event_Brief prompt template together with the rep's question. The template decides what matters and shapes the answer
 * (headline, metrics, sections, which people to show and what to say about them); Apex only fetches, flattens and links names back to records.
 */
public with sharing class PPEventBriefService {

    private static final Set<String> DONE = new Set<String>{ 'Concluded', 'Closed' };
    private static final Integer MAX_ROSTER = 150;
    private static final Integer MAX_PAST = 8;
    private static final Integer MAX_SHOWN = 40;
    private static final Set<String> TONES = new Set<String>{ 'positive', 'warning', 'critical', 'neutral' };

    public static PPEventBrief build(String persona, String templateName, PPCardRequest req) {
        try {
            Account acct = personContext(req);
            PPSpeakerSearchService.EventCtx ctx = acct == null ? PPSpeakerSearchService.findEvent(req) : null;
            if (acct == null && ctx == null) return message('No event selected', 'Open an event record, or name the event. ' + PPSpeakerSearchService.openEvents());
            Dump d = acct != null ? personDump(acct) : eventDump(ctx);
            return answer(d, persona, templateName, req);
        } catch (Exception e) {
            return message('Could not load the event', e.getMessage());
        }
    }

    /** The Account the rep is on, or names when it is not an event; null when the question is about an event. */
    private static Account personContext(PPCardRequest req) {
        Id aid = null;
        if (String.isNotBlank(req.accountId)) {
            try {
                Id i = Id.valueOf(req.accountId);
                if (i.getSobjectType() == Account.SObjectType) aid = i;
            } catch (Exception e) { /* not an id */ }
        }
        if (aid == null && String.isNotBlank(req.accountName) && PPSpeakerSearchService.bestNameMatch(req.accountName) == null) {
            aid = PPContext.resolveAccountId(null, req.accountName);
        }
        if (aid == null) return null;
        return [SELECT Id, Name FROM Account WHERE Id = :aid LIMIT 1];
    }

    /** Everything loaded for the question: the text sent to the model plus the people, keyed by lower-case name, to link answers back to records. */
    private class Dump {
        String title;
        String subtitle;
        String eventId;
        String eventName;
        String status;
        String eventText;
        String rosterText;
        Map<String, PPEventPerson> byName = new Map<String, PPEventPerson>();
        List<PPEventPerson> all = new List<PPEventPerson>();
    }

    // ---------- load: event ----------

    private static Dump eventDump(PPSpeakerSearchService.EventCtx ctx) {
        MngEvent ev = [SELECT Id, Name, Status, Description, StartDateTime, EndDateTime, Mode, LocationType, EstimatedParticipantCount, EstimatedBudget,
                              TotalEstimatedExpenseAmount, TotalActualExpenseAmount, ComplianceAgreementStatus, PrimaryOwner.Name, MngEventType.Name
                       FROM MngEvent WHERE Id = :ctx.ev.Id LIMIT 1];
        Dump d = new Dump();
        d.title = 'Event brief';
        d.eventId = ev.Id;
        d.eventName = ev.Name;
        d.status = ev.Status;
        d.subtitle = ev.Name + (ev.StartDateTime == null ? '' : ' - ' + ev.StartDateTime.format('yyyy-MM-dd')) + ' (' + ctx.source + ')';

        List<String> e = new List<String>();
        e.add('EVENT: ' + ev.Name + ' | status ' + ev.Status + ' | type ' + (ev.MngEventType == null ? '-' : ev.MngEventType.Name));
        e.add('When: ' + (ev.StartDateTime == null ? 'not set' : ev.StartDateTime.format('yyyy-MM-dd HH:mm')) + (ev.EndDateTime == null ? '' : ' to ' + ev.EndDateTime.format('yyyy-MM-dd HH:mm')));
        e.add('Format: ' + nz(ev.Mode) + ' | location type ' + nz(ev.LocationType) + ' | owner ' + (ev.PrimaryOwner == null ? '-' : ev.PrimaryOwner.Name));
        e.add('Expected participants: ' + (ev.EstimatedParticipantCount == null ? 'not set' : String.valueOf(ev.EstimatedParticipantCount)));
        e.add('Budget: ' + money(ev.EstimatedBudget) + ' | estimated expenses ' + money(ev.TotalEstimatedExpenseAmount) + ' | actual expenses ' + money(ev.TotalActualExpenseAmount));
        e.add('Compliance agreement: ' + nz(ev.ComplianceAgreementStatus));
        e.add('Products: ' + (ctx.products.isEmpty() ? 'none' : String.join(new List<String>(ctx.products), ', ')));
        if (ev.Description != null) e.add('Description: ' + ev.Description.left(500));
        try {
            for (MngEventBudget b : [SELECT Name, Budget.Name, AllocatedAmount, TotalEstimatedExpenseAmount FROM MngEventBudget WHERE MngEventId = :ev.Id LIMIT 20]) {
                e.add('Event budget (the Managed Event Budget record shown on the event): "' + b.Name + '" | allocated ' + money(b.AllocatedAmount) + ' | total estimated expenses ' + money(b.TotalEstimatedExpenseAmount) + ' | drawn from the funding budget "' + (b.Budget == null ? '-' : b.Budget.Name) + '"');
            }
            for (EstimatedExpense x : [SELECT Name, Amount, ExpenseType.Name FROM EstimatedExpense WHERE ExpenseSourceId = :ev.Id LIMIT 50]) {
                e.add('Expense line: ' + x.Name + ' | ' + (x.ExpenseType == null ? '-' : x.ExpenseType.Name) + ' | ' + money(x.Amount));
            }
        } catch (Exception ex) { e.add('Budget and expense detail unavailable.'); }
        d.eventText = String.join(e, '\n');

        List<MngEventParticipant> parts = [
            SELECT ParticipantId, Participant.Name, EventMgmtParticipantType.Name, EventMgmtParticipantRole.Name,
                   ParticipantResponse, AttendanceStatus, InvitationSentStatus
            FROM MngEventParticipant WHERE MngEventId = :ev.Id ORDER BY Participant.Name LIMIT 1000];
        Set<Id> pids = new Set<Id>();
        for (MngEventParticipant p : parts) if (p.ParticipantId != null) pids.add(p.ParticipantId);
        Map<Id, List<PPEventPast>> hist = history(pids, ev.Id);
        Map<Id, Expert> experts = new Map<Id, Expert>([SELECT Id, Name, AccountId, AdditionalInformation FROM Expert WHERE Id IN :pids]);
        Map<Id, Integer> ytd = speakerYtd(experts.keySet(), ev.StartDateTime);
        Map<Id, List<String>> subjects = new Map<Id, List<String>>();
        for (ExpertSubject s : [SELECT ExpertId, Subject.Name, EffectiveDateTime, ExpirationDateTime FROM ExpertSubject WHERE ExpertId IN :experts.keySet()]) {
            if (!subjects.containsKey(s.ExpertId)) subjects.put(s.ExpertId, new List<String>());
            subjects.get(s.ExpertId).add(s.Subject.Name + (s.ExpirationDateTime == null ? '' : ' (expires ' + s.ExpirationDateTime.format('yyyy-MM-dd') + ')'));
        }

        Map<String, Integer> tally = new Map<String, Integer>();
        List<String> lines = new List<String>();
        Integer n = 0;
        for (MngEventParticipant p : parts) {
            String type = p.EventMgmtParticipantType == null ? '' : nz(p.EventMgmtParticipantType.Name);
            PPEventPerson x = new PPEventPerson();
            x.name = clean(p.Participant == null ? null : p.Participant.Name);
            x.role = p.EventMgmtParticipantRole == null ? null : p.EventMgmtParticipantRole.Name.replace('AFLS ', '').replace(' Attendee Role', '').replace(' Participant Role', '').replace(' Role', '');
            x.response = label(p.ParticipantResponse);
            x.attendance = label(p.AttendanceStatus);
            Id pid = p.ParticipantId;
            if (pid != null && pid.getSobjectType() == Account.SObjectType) x.accountId = pid;
            List<PPEventPast> past = pid != null && hist.containsKey(pid) ? hist.get(pid) : new List<PPEventPast>();
            summarize(x, past);
            String profile = '';
            if (type.contains('Expert')) {
                x.kind = 'Speaker';
                Expert ex = pid == null ? null : experts.get(pid);
                if (ex != null) {
                    x.accountId = ex.AccountId;
                    Map<String, String> info = PPSpeakerSearchService.parse(ex.AdditionalInformation);
                    x.specialty = info.get('SPECIALTY');
                    x.tier = info.containsKey('TIER') ? Integer.valueOf(info.get('TIER')) : null;
                    x.fee = info.containsKey('FEE') ? Decimal.valueOf(info.get('FEE')) : null;
                    x.trained = info.get('TRAINED');
                    x.programsYtd = ytd.containsKey(ex.Id) ? ytd.get(ex.Id) : 0;
                    x.notes = speakerNotes(x);
                    profile = ' | profile: ' + nz(ex.AdditionalInformation).left(400) + (subjects.containsKey(ex.Id) ? ' | subjects: ' + String.join(subjects.get(ex.Id), ', ') : '')
                        + ' | programs this year incl. this one ' + x.programsYtd + ' (annual cap ' + PPSpeakerSearchService.ANNUAL_CAP + ', fee review above $' + PPEventPlannerService.SPEAKER_FEE_CAP.setScale(0).format() + ')';
                }
            } else if (type.contains('Colleague')) {
                x.kind = 'Colleague';
            } else {
                x.kind = type.contains('WriteIn') ? 'Write-in' : (type.contains('NonProfiled') ? 'Non-profiled' : 'Attendee');
            }
            String key = x.kind + ' | response ' + nz(x.response) + ' | attendance ' + nz(x.attendance);
            tally.put(key, (tally.containsKey(key) ? tally.get(key) : 0) + 1);
            d.all.add(x);
            if (x.name != null) d.byName.put(x.name.toLowerCase(), x);
            if (n < MAX_ROSTER) {
                lines.add('- ' + x.name + ' | ' + x.kind + (x.role == null ? '' : ' / ' + x.role) + ' | invitation ' + nz(label(p.InvitationSentStatus)) + ' | response ' + nz(x.response)
                    + ' | attendance ' + nz(x.attendance) + profile + ' | earlier events: ' + earlier(x));
            }
            n++;
        }
        List<String> t = new List<String>{ 'ROSTER TOTALS (' + parts.size() + ' participants; counts by kind, response and attendance on THIS event):' };
        List<String> keys = new List<String>(tally.keySet());
        keys.sort();
        for (String k : keys) t.add('  ' + k + ': ' + tally.get(k));
        if (parts.isEmpty()) t.add('  Nobody is on this event yet.');
        if (n > MAX_ROSTER) t.add('  Only the first ' + MAX_ROSTER + ' participants are listed below.');
        d.rosterText = String.join(t, '\n') + '\nROSTER:\n' + (lines.isEmpty() ? 'none' : String.join(lines, '\n'));
        return d;
    }

    /** "Name (date, status, outcome); ..." for the person's earlier events, or none. */
    private static String earlier(PPEventPerson x) {
        if (x.past == null || x.past.isEmpty()) return 'none';
        List<String> l = new List<String>();
        for (PPEventPast h : x.past) {
            l.add(h.name + ' (' + nz(h.eventDate) + ', event ' + h.status + ', as ' + h.role + ', response ' + nz(h.response) + ', attendance ' + nz(h.attendance) + ')');
        }
        return String.join(l, '; ') + (x.invited > x.past.size() ? '; plus ' + (x.invited - x.past.size()) + ' older' : '');
    }

    // ---------- load: person ----------

    private static Dump personDump(Account acct) {
        Set<Id> pids = new Set<Id>{ acct.Id };
        for (Expert e : [SELECT Id FROM Expert WHERE AccountId = :acct.Id]) pids.add(e.Id);
        Map<Id, List<PPEventPast>> hist = history(pids, null);
        List<PPEventPast> all = new List<PPEventPast>();
        for (Id i : hist.keySet()) all.addAll(hist.get(i));
        all.sort(new PastByDate());
        PPEventPerson x = new PPEventPerson();
        x.name = acct.Name;
        x.accountId = acct.Id;
        x.kind = 'Person';
        x.highlight = true;
        summarize(x, all);
        List<PPEventPast> shown = new List<PPEventPast>();
        for (PPEventPast p : all) if (shown.size() < 40) shown.add(p);
        x.past = shown;
        Dump d = new Dump();
        d.title = 'Event history';
        d.subtitle = acct.Name;
        d.eventText = 'PERSON: ' + acct.Name + ' | ' + all.size() + ' events they were invited to (excluding drafts and cancelled)';
        List<String> lines = new List<String>();
        for (PPEventPast h : shown) {
            lines.add('- ' + h.name + ' | ' + nz(h.eventDate) + ' | event ' + h.status + ' | as ' + h.role + ' | response ' + nz(h.response) + ' | attendance ' + nz(h.attendance));
        }
        d.rosterText = lines.isEmpty() ? 'No earlier events.' : 'EVENTS:\n' + String.join(lines, '\n');
        d.all.add(x);
        d.byName.put(acct.Name.toLowerCase(), x);
        return d;
    }

    // ---------- answer: the prompt template decides, Apex links names to records ----------

    private static PPEventBrief answer(Dump d, String persona, String templateName, PPCardRequest req) {
        Map<String, String> inputs = new Map<String, String>{
            'Question' => String.isNotBlank(req.question) ? req.question : 'Summarize this event.',
            'Today' => Date.today().format() + ' (' + String.valueOf(Date.today()) + ')',
            'EventContext' => d.eventText,
            'Roster' => d.rosterText,
            'ScenarioFacts' => PPContext.scenarioFacts(persona, null)
        };
        String body = PPViewRunner.runJson(templateName, inputs);
        if (body != null) body = body.replace('&#124;', '-');
        PPEventBrief c = new PPEventBrief();
        c.title = d.title;
        c.subtitle = d.subtitle;
        c.eventId = d.eventId;
        c.eventName = d.eventName;
        c.badge = d.status;
        c.badgeTone = 'neutral';
        c.focus = 'overview';
        c.metrics = new List<PPMetric>();
        c.facts = new List<PPMetric>();
        c.sections = new List<PPSection>();
        c.speakers = new List<PPEventPerson>();
        c.attendees = new List<PPEventPerson>();
        c.colleagues = new List<PPEventPerson>();
        if (body == null) {
            c.headline = 'I could not put that answer together. Please ask again.';
            return c;
        }
        Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(body);
        if (m.get('title') != null) c.title = (String) m.get('title');
        if (m.get('badge') != null) c.badge = (String) m.get('badge');
        c.badgeTone = tone((String) m.get('badgeTone'));
        if (m.get('focus') != null) c.focus = (String) m.get('focus');
        c.headline = (String) m.get('headline');
        c.nextStep = (String) m.get('nextStep');
        c.textOnly = 'text' == (String) m.get('display');
        c.metrics = metrics(m.get('metrics'));
        c.facts = metrics(m.get('facts'));
        if (m.get('sections') != null) {
            for (Object o : (List<Object>) m.get('sections')) {
                Map<String, Object> sm = (Map<String, Object>) o;
                PPSection s = new PPSection();
                s.heading = (String) sm.get('heading');
                s.bullets = new List<String>();
                if (sm.get('bullets') != null) for (Object b : (List<Object>) sm.get('bullets')) s.bullets.add(String.valueOf(b));
                if (s.heading != null && !s.bullets.isEmpty()) c.sections.add(s);
            }
        }
        Integer shown = 0, skipped = 0;
        if (m.get('people') != null) {
            for (Object o : (List<Object>) m.get('people')) {
                Map<String, Object> pm = (Map<String, Object>) o;
                String nm = (String) pm.get('name');
                PPEventPerson src = nm == null ? null : d.byName.get(nm.toLowerCase());
                if (src == null) continue; // a name the data does not contain is dropped, never shown
                if (shown >= MAX_SHOWN) { skipped++; continue; }
                shown++;
                PPEventPerson x = copy(src);
                if (pm.get('note') != null) x.flag = (String) pm.get('note');
                if (pm.get('tone') != null) x.tone = tone((String) pm.get('tone'));
                x.highlight = pm.get('expand') == true;
                if (x.kind == 'Speaker') c.speakers.add(x);
                else if (x.kind == 'Colleague') c.colleagues.add(x);
                else c.attendees.add(x);
            }
        }
        c.moreAttendees = skipped;
        return c;
    }

    private static PPEventPerson copy(PPEventPerson s) {
        PPEventPerson x = new PPEventPerson();
        x.name = s.name; x.accountId = s.accountId; x.kind = s.kind; x.role = s.role; x.response = s.response; x.attendance = s.attendance;
        x.specialty = s.specialty; x.tier = s.tier; x.fee = s.fee; x.trained = s.trained; x.programsYtd = s.programsYtd;
        x.invited = s.invited; x.completed = s.completed; x.attended = s.attended; x.noShows = s.noShows; x.lastAttended = s.lastAttended;
        x.flag = s.flag; x.tone = s.tone; x.highlight = s.highlight; x.notes = s.notes; x.past = s.past;
        return x;
    }

    private static List<PPMetric> metrics(Object o) {
        List<PPMetric> out = new List<PPMetric>();
        if (o == null) return out;
        for (Object i : (List<Object>) o) {
            Map<String, Object> mm = (Map<String, Object>) i;
            if (mm.get('label') == null || mm.get('value') == null) continue;
            PPMetric x = new PPMetric();
            x.label = (String) mm.get('label');
            x.value = String.valueOf(mm.get('value'));
            x.tone = tone((String) mm.get('tone'));
            out.add(x);
        }
        return out;
    }

    private static String tone(String t) { return t != null && TONES.contains(t) ? t : 'neutral'; }

    private static List<String> speakerNotes(PPEventPerson x) {
        List<String> n = new List<String>();
        if (x.specialty != null) n.add(x.specialty + (x.tier == null ? '' : ', tier ' + x.tier));
        if (x.fee != null) n.add('Rate $' + x.fee.setScale(0).format() + (x.fee > PPEventPlannerService.SPEAKER_FEE_CAP ? ' (above the $' + PPEventPlannerService.SPEAKER_FEE_CAP.setScale(0).format() + ' review threshold)' : ''));
        Date tr = PPViewRunner.parseDate(x.trained);
        if (x.trained != null) n.add(tr != null && tr.addMonths(PPSpeakerSearchService.TRAINING_MONTHS) > Date.today() ? 'Trained ' + x.trained : 'Training dated ' + x.trained + ' may be out of date');
        if (x.programsYtd != null) n.add(x.programsYtd + (x.programsYtd > PPSpeakerSearchService.ANNUAL_CAP ? ' programs this year, over the cap of ' : ' of ') + PPSpeakerSearchService.ANNUAL_CAP + (x.programsYtd > PPSpeakerSearchService.ANNUAL_CAP ? '' : ' programs this year'));
        return n;
    }

    /** Speaker programs per expert in the event's calendar year (including this event). */
    private static Map<Id, Integer> speakerYtd(Set<Id> expertIds, Datetime evStart) {
        Map<Id, Integer> out = new Map<Id, Integer>();
        if (expertIds.isEmpty()) return out;
        Date d = evStart == null ? Date.today() : evStart.date();
        Datetime lo = Datetime.newInstance(Date.newInstance(d.year(), 1, 1), Time.newInstance(0, 0, 0, 0));
        Datetime hi = Datetime.newInstance(Date.newInstance(d.year() + 1, 1, 1), Time.newInstance(0, 0, 0, 0));
        for (MngEventParticipant p : [SELECT ParticipantId FROM MngEventParticipant WHERE ParticipantId IN :expertIds AND MngEvent.Status != 'Cancelled'
                                      AND MngEvent.StartDateTime >= :lo AND MngEvent.StartDateTime < :hi]) {
            out.put(p.ParticipantId, (out.containsKey(p.ParticipantId) ? out.get(p.ParticipantId) : 0) + 1);
        }
        return out;
    }

    // ---------- history ----------

    /** Earlier (non-draft, non-cancelled) events each participant was invited to, newest first. */
    private static Map<Id, List<PPEventPast>> history(Set<Id> pids, Id exceptEvent) {
        Map<Id, List<PPEventPast>> out = new Map<Id, List<PPEventPast>>();
        if (pids.isEmpty()) return out;
        for (MngEventParticipant p : [
            SELECT ParticipantId, MngEventId, MngEvent.Name, MngEvent.StartDateTime, MngEvent.Status, AttendanceStatus, ParticipantResponse,
                   EventMgmtParticipantType.Name
            FROM MngEventParticipant
            WHERE ParticipantId IN :pids AND MngEventId != :exceptEvent AND MngEvent.Status NOT IN ('Draft', 'Cancelled')
            ORDER BY MngEvent.StartDateTime DESC LIMIT 2000]) {
            PPEventPast h = new PPEventPast();
            h.eventId = p.MngEventId;
            h.name = p.MngEvent.Name;
            h.eventDate = p.MngEvent.StartDateTime == null ? null : p.MngEvent.StartDateTime.format('yyyy-MM-dd');
            h.status = p.MngEvent.Status;
            String t = p.EventMgmtParticipantType == null ? '' : nz(p.EventMgmtParticipantType.Name);
            h.role = t.contains('Expert') ? 'Speaker' : (t.contains('Colleague') ? 'Colleague' : 'Attendee');
            h.response = label(p.ParticipantResponse);
            h.attendance = label(p.AttendanceStatus);
            if (!out.containsKey(p.ParticipantId)) out.put(p.ParticipantId, new List<PPEventPast>());
            out.get(p.ParticipantId).add(h);
        }
        return out;
    }

    private class PastByDate implements Comparator<PPEventPast> {
        public Integer compare(PPEventPast a, PPEventPast b) {
            String x = nz(a.eventDate), y = nz(b.eventDate);
            return x == y ? 0 : (x < y ? 1 : -1);
        }
    }

    /** Counts and a one-line flag from the earlier events. */
    private static void summarize(PPEventPerson x, List<PPEventPast> past) {
        x.invited = past.size();
        x.completed = 0;
        x.attended = 0;
        x.noShows = 0;
        for (PPEventPast h : past) {
            if (DONE.contains(h.status)) x.completed++;
            if (h.attendance == 'Attended' || h.attendance == 'Check in complete') {
                x.attended++;
                if (x.lastAttended == null) x.lastAttended = h.name + ' (' + nz(h.eventDate) + ')';
            }
            if (h.attendance == 'No show') x.noShows++;
        }
        x.past = new List<PPEventPast>();
        for (PPEventPast h : past) if (x.past.size() < MAX_PAST) x.past.add(h);
        if (x.invited == 0) { x.flag = 'No earlier events'; x.tone = 'neutral'; }
        else if (x.noShows > 0) { x.flag = 'Missed ' + x.noShows + ' of ' + Math.max(x.completed, x.noShows) + ' earlier events'; x.tone = 'warning'; }
        else if (x.attended > 0) { x.flag = 'Attended ' + x.attended + ' of ' + Math.max(x.completed, x.attended) + ' earlier events'; x.tone = 'positive'; }
        else { x.flag = 'Invited to ' + x.invited + ' earlier event' + (x.invited == 1 ? '' : 's') + ', no attendance recorded'; x.tone = 'neutral'; }
    }

    // ---------- shared with Speaker Search ----------

    /** One summary line per speaker already on the event, for the "already has a speaker" answer. Empty when there is none. */
    public static List<String> speakerSummary(Id eventId, Datetime evStart) {
        List<MngEventParticipant> parts = [SELECT ParticipantId, Participant.Name, AttendanceStatus, ParticipantResponse FROM MngEventParticipant
                                           WHERE MngEventId = :eventId AND EventMgmtParticipantType.Name = 'AFLS Expert Type'];
        List<String> out = new List<String>();
        if (parts.isEmpty()) return out;
        Set<Id> pids = new Set<Id>();
        for (MngEventParticipant p : parts) pids.add(p.ParticipantId);
        Map<Id, List<PPEventPast>> hist = history(pids, eventId);
        Map<Id, Expert> experts = new Map<Id, Expert>([SELECT Id, AdditionalInformation FROM Expert WHERE Id IN :pids]);
        Map<Id, Integer> ytd = speakerYtd(pids, evStart);
        for (MngEventParticipant p : parts) {
            PPEventPerson x = new PPEventPerson();
            x.name = clean(p.Participant.Name);
            x.attendance = label(p.AttendanceStatus);
            summarize(x, hist.containsKey(p.ParticipantId) ? hist.get(p.ParticipantId) : new List<PPEventPast>());
            Expert e = experts.get(p.ParticipantId);
            if (e != null) {
                Map<String, String> info = PPSpeakerSearchService.parse(e.AdditionalInformation);
                x.specialty = info.get('SPECIALTY');
                x.tier = info.containsKey('TIER') ? Integer.valueOf(info.get('TIER')) : null;
                x.fee = info.containsKey('FEE') ? Decimal.valueOf(info.get('FEE')) : null;
                x.trained = info.get('TRAINED');
                x.programsYtd = ytd.containsKey(e.Id) ? ytd.get(e.Id) : 0;
            }
            List<String> n = speakerNotes(x);
            n.add(x.flag);
            out.add(x.name + ': ' + String.join(n, '; ') + '.');
        }
        return out;
    }

    // ---------- helpers ----------

    /** "Sarah Verma Advisory Faculty Profile" -> "Sarah Verma". */
    private static String clean(String n) {
        if (n == null) return null;
        return n.replace(' Speaker Profile', '').replace(' Faculty Profile', '').replace(' Congress', '').replace(' Advisory', '').trim();
    }

    /** Picklist API value -> readable words ("NoShow" -> "No show"). */
    private static String label(String v) {
        if (v == null) return null;
        return v.replaceAll('([a-z])([A-Z])', '$1 $2').replace('No Response', 'No response').replace('No Show', 'No show').replace('Check In Complete', 'Check in complete').replace('Sign Up Complete', 'Signed up');
    }

    private static String money(Decimal d) { return d == null ? '$0' : '$' + d.setScale(0).format(); }
    private static String nz(String s) { return s == null ? '' : s; }

    private static PPEventBrief message(String headline, String body) {
        PPEventBrief c = new PPEventBrief();
        c.title = 'Event brief';
        c.headline = headline;
        c.metrics = new List<PPMetric>();
        c.facts = new List<PPMetric>();
        c.speakers = new List<PPEventPerson>();
        c.attendees = new List<PPEventPerson>();
        c.colleagues = new List<PPEventPerson>();
        c.sections = new List<PPSection>{ PPViewRunner.section('Details', body) };
        return c;
    }
}
