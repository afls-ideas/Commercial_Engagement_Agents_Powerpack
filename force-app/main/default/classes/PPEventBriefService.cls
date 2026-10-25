/**
 * Event Brief: answers questions about an existing Managed Event (the record the rep is on, one they name, or their latest draft):
 * speakers, attendees, colleagues, budget, and each person's history on earlier events (invited, responded, attended, no-show).
 * With an Account record in context it shows that one person's event history instead. Everything is computed in Apex; the model only words the answer.
 */
public with sharing class PPEventBriefService {

    private static final Set<String> DONE = new Set<String>{ 'Concluded', 'Closed' };
    private static final Integer MAX_ATTENDEES = 30;
    private static final Integer MAX_PAST = 6;

    public static PPEventBrief build(String persona, String templateName, PPCardRequest req) {
        try {
            Account acct = personContext(req);
            PPSpeakerSearchService.EventCtx ctx = acct == null ? PPSpeakerSearchService.findEvent(req) : null;
            if (acct == null && ctx == null) return message('No event selected', 'Open an event record, or name the event. ' + PPSpeakerSearchService.openEvents());
            PPEventBrief card = acct != null ? personCard(acct, req) : eventCard(ctx, req);
            narrate(card, persona, templateName, req, ctx);
            return card;
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

    // ---------- event mode ----------

    private static PPEventBrief eventCard(PPSpeakerSearchService.EventCtx ctx, PPCardRequest req) {
        MngEvent ev = [SELECT Id, Name, Status, StartDateTime, EndDateTime, Mode, LocationType, EstimatedParticipantCount, EstimatedBudget,
                              TotalEstimatedExpenseAmount, TotalActualExpenseAmount, ComplianceAgreementStatus, PrimaryOwner.Name, MngEventType.Name
                       FROM MngEvent WHERE Id = :ctx.ev.Id LIMIT 1];
        String q = req.question;
        String focus = focusOf(q);

        List<MngEventParticipant> parts = [
            SELECT Id, ParticipantId, Participant.Name, EventMgmtParticipantType.Name, EventMgmtParticipantRole.Name,
                   ParticipantResponse, AttendanceStatus, InvitationSentStatus
            FROM MngEventParticipant WHERE MngEventId = :ev.Id ORDER BY Participant.Name LIMIT 500];

        Set<Id> pids = new Set<Id>();
        for (MngEventParticipant p : parts) if (p.ParticipantId != null) pids.add(p.ParticipantId);
        Map<Id, List<PPEventPast>> hist = history(pids, ev.Id);
        Map<Id, Expert> experts = new Map<Id, Expert>([SELECT Id, Name, AccountId, AdditionalInformation FROM Expert WHERE Id IN :pids]);
        Map<Id, Integer> ytd = speakerYtd(experts.keySet(), ev.StartDateTime);

        List<PPEventPerson> speakers = new List<PPEventPerson>();
        List<PPEventPerson> attendees = new List<PPEventPerson>();
        List<PPEventPerson> colleagues = new List<PPEventPerson>();
        Integer accepted = 0, declined = 0, noReply = 0, attendedNow = 0, noShowNow = 0, repeat = 0, riskNoShow = 0;
        String lowerQ = nz(q).toLowerCase();

        for (MngEventParticipant p : parts) {
            String type = p.EventMgmtParticipantType == null ? '' : nz(p.EventMgmtParticipantType.Name);
            PPEventPerson x = new PPEventPerson();
            x.name = clean(p.Participant == null ? null : p.Participant.Name);
            x.role = p.EventMgmtParticipantRole == null ? null : p.EventMgmtParticipantRole.Name.replace('AFLS ', '').replace(' Attendee Role', '').replace(' Participant Role', '').replace(' Role', '');
            x.response = label(p.ParticipantResponse);
            x.attendance = label(p.AttendanceStatus);
            x.highlight = x.name != null && nameMentioned(lowerQ, x.name);
            Id pid = p.ParticipantId;
            if (pid != null && pid.getSobjectType() == Account.SObjectType) x.accountId = pid;
            List<PPEventPast> past = pid != null && hist.containsKey(pid) ? hist.get(pid) : new List<PPEventPast>();
            summarize(x, past);
            if (type.contains('Expert')) {
                x.kind = 'Speaker';
                Expert e = pid == null ? null : experts.get(pid);
                if (e != null) {
                    x.accountId = e.AccountId;
                    Map<String, String> info = PPSpeakerSearchService.parse(e.AdditionalInformation);
                    x.specialty = info.get('SPECIALTY');
                    x.tier = info.containsKey('TIER') ? Integer.valueOf(info.get('TIER')) : null;
                    x.fee = info.containsKey('FEE') ? Decimal.valueOf(info.get('FEE')) : null;
                    x.trained = info.get('TRAINED');
                    x.programsYtd = ytd.containsKey(e.Id) ? ytd.get(e.Id) : 0;
                    x.notes = speakerNotes(x);
                }
                speakers.add(x);
            } else if (type.contains('Colleague')) {
                x.kind = 'Colleague';
                colleagues.add(x);
            } else {
                x.kind = type.contains('WriteIn') ? 'Write-in' : (type.contains('NonProfiled') ? 'Non-profiled' : 'Attendee');
                attendees.add(x);
                if (p.ParticipantResponse == 'Accepted') accepted++;
                else if (p.ParticipantResponse == 'Declined') declined++;
                else noReply++;
                if (p.AttendanceStatus == 'Attended' || p.AttendanceStatus == 'CheckInComplete') attendedNow++;
                if (p.AttendanceStatus == 'NoShow') noShowNow++;
                if (x.invited > 0) repeat++;
                if (x.noShows > 0) riskNoShow++;
            }
        }
        sortAttendees(attendees, lowerQ);

        PPEventBrief c = new PPEventBrief();
        c.title = 'Event brief';
        c.eventId = ev.Id;
        c.eventName = ev.Name;
        c.focus = focus;
        c.subtitle = ev.Name + (ev.StartDateTime == null ? '' : ' - ' + ev.StartDateTime.format('yyyy-MM-dd')) + ' (' + ctx.source + ')';
        c.badge = ev.Status;
        c.badgeTone = ev.Status == 'Cancelled' ? 'critical' : (DONE.contains(ev.Status) ? 'neutral' : (ev.Status == 'Draft' || ev.Status == 'PendingApproval' ? 'warning' : 'positive'));

        c.metrics = new List<PPMetric>{
            metric('Speakers', String.valueOf(speakers.size()), speakers.isEmpty() ? 'warning' : 'positive'),
            metric('Attendees', String.valueOf(attendees.size()) + (ev.EstimatedParticipantCount == null ? '' : ' of ' + ev.EstimatedParticipantCount), 'neutral'),
            metric('Accepted', String.valueOf(accepted), 'positive'),
            metric('No reply', String.valueOf(noReply), noReply > 0 ? 'warning' : 'neutral')
        };
        if (DONE.contains(ev.Status) || attendedNow > 0 || noShowNow > 0) {
            c.metrics.add(metric('Attended', String.valueOf(attendedNow), 'positive'));
            c.metrics.add(metric('No-shows', String.valueOf(noShowNow), noShowNow > 0 ? 'critical' : 'neutral'));
        }
        c.metrics.add(metric('Repeat invitees', String.valueOf(repeat), 'neutral'));
        if (riskNoShow > 0) c.metrics.add(metric('Missed an earlier event', String.valueOf(riskNoShow), 'warning'));

        c.facts = new List<PPMetric>();
        c.facts.add(metric('Type', ev.MngEventType == null ? '-' : ev.MngEventType.Name, 'neutral'));
        c.facts.add(metric('When', ev.StartDateTime == null ? '-' : ev.StartDateTime.format('EEE d MMM yyyy HH:mm') + (ev.EndDateTime == null ? '' : ' to ' + ev.EndDateTime.format('HH:mm')), 'neutral'));
        c.facts.add(metric('Format', nz(ev.Mode) + (ev.LocationType == null ? '' : ' - ' + ev.LocationType), 'neutral'));
        c.facts.add(metric('Owner', ev.PrimaryOwner == null ? '-' : ev.PrimaryOwner.Name, 'neutral'));
        List<String> prods = new List<String>(ctx.products);
        c.facts.add(metric('Products', prods.isEmpty() ? 'None' : String.join(prods, ', '), prods.isEmpty() ? 'warning' : 'neutral'));
        c.facts.add(metric('Budget', money(ev.EstimatedBudget) + ' budget, ' + money(ev.TotalEstimatedExpenseAmount) + ' estimated, ' + money(ev.TotalActualExpenseAmount) + ' actual',
            ev.TotalEstimatedExpenseAmount != null && ev.EstimatedBudget != null && ev.TotalEstimatedExpenseAmount > ev.EstimatedBudget ? 'critical' : 'neutral'));
        c.facts.add(metric('Compliance agreement', nz(ev.ComplianceAgreementStatus), 'neutral'));

        c.speakers = speakers;
        c.colleagues = colleagues;
        c.moreAttendees = attendees.size() > MAX_ATTENDEES ? attendees.size() - MAX_ATTENDEES : 0;
        c.attendees = new List<PPEventPerson>();
        for (PPEventPerson a : attendees) if (c.attendees.size() < MAX_ATTENDEES) c.attendees.add(a);
        c.sections = new List<PPSection>();
        return c;
    }

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

    // ---------- person mode ----------

    private static PPEventBrief personCard(Account acct, PPCardRequest req) {
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
        x.past = new List<PPEventPast>();
        for (PPEventPast p : all) if (x.past.size() < 15) x.past.add(p);

        PPEventBrief c = new PPEventBrief();
        c.title = 'Event history';
        c.subtitle = acct.Name;
        c.focus = 'history';
        c.badge = x.invited + ' events';
        c.badgeTone = x.noShows > 0 ? 'warning' : 'neutral';
        c.metrics = new List<PPMetric>{
            metric('Invited to', String.valueOf(x.invited), 'neutral'),
            metric('Attended', String.valueOf(x.attended), 'positive'),
            metric('No-shows', String.valueOf(x.noShows), x.noShows > 0 ? 'critical' : 'neutral'),
            metric('Events held', String.valueOf(x.completed), 'neutral')
        };
        c.attendees = new List<PPEventPerson>{ x };
        c.speakers = new List<PPEventPerson>();
        c.colleagues = new List<PPEventPerson>();
        c.facts = new List<PPMetric>();
        c.sections = new List<PPSection>();
        return c;
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

    private static void sortAttendees(List<PPEventPerson> l, String q) {
        Boolean byMiss = has(q, new List<String>{ 'no-show', 'no show', 'noshow', 'missed', 'didn\'t show', 'did not show', 'unreliable', 'risk' });
        Boolean byGood = has(q, new List<String>{ 'attended', 'reliable', 'engaged', 'regular', 'loyal', 'best' });
        List<PPEventPerson> out = new List<PPEventPerson>();
        for (Integer rank = 0; rank <= 3; rank++) {
            for (PPEventPerson a : l) if (rankOf(a, byMiss, byGood) == rank) out.add(a);
        }
        l.clear();
        l.addAll(out);
    }

    private static Integer rankOf(PPEventPerson a, Boolean byMiss, Boolean byGood) {
        if (a.highlight == true) return 0;
        if (byMiss) return a.noShows > 0 ? 1 : (a.invited > 0 ? 2 : 3);
        if (byGood) return a.attended > 0 ? 1 : (a.invited > 0 ? 2 : 3);
        return a.invited > 0 ? 1 : 2;
    }

    // ---------- narration ----------

    private static void narrate(PPEventBrief card, String persona, String templateName, PPCardRequest req, PPSpeakerSearchService.EventCtx ctx) {
        List<String> lines = new List<String>();
        for (PPEventPerson x : people(card)) {
            List<String> ev = new List<String>();
            for (PPEventPast h : x.past == null ? new List<PPEventPast>() : x.past) {
                if (ev.size() < 4) ev.add(h.name + ' (' + nz(h.eventDate) + ', ' + h.status + ', ' + nz(h.attendance) + (h.attendance == null ? nz(h.response) : '') + ')');
            }
            lines.add(x.name + ' | ' + x.kind + (x.role == null ? '' : ' / ' + x.role) + ' | response ' + nz(x.response) + ' | attendance ' + nz(x.attendance)
                + ' | ' + nz(x.flag) + (ev.isEmpty() ? '' : ' | earlier: ' + String.join(ev, '; ')));
        }
        List<String> facts = new List<String>();
        for (PPMetric m : card.facts == null ? new List<PPMetric>() : card.facts) facts.add(m.label + ': ' + m.value);
        for (PPMetric m : card.metrics == null ? new List<PPMetric>() : card.metrics) facts.add(m.label + ' = ' + m.value);
        Map<String, String> inputs = new Map<String, String>{
            'Question' => String.isNotBlank(req.question) ? req.question : 'Summarize this event.',
            'Today' => Date.today().format() + ' (' + String.valueOf(Date.today()) + ')',
            'EventContext' => (card.eventName == null ? 'PERSON HISTORY: ' + card.subtitle : 'EVENT: ' + card.eventName + ' | status ' + card.badge) + '\n' + String.join(facts, '\n'),
            'Roster' => lines.isEmpty() ? 'Nobody is on this event yet.' : String.join(lines, '\n'),
            'ScenarioFacts' => PPContext.scenarioFacts(persona, null)
        };
        String body = PPViewRunner.runJson(templateName, inputs);
        if (body == null) return;
        Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(body);
        card.headline = (String) m.get('headline');
        card.nextStep = (String) m.get('nextStep');
        if (m.get('insights') != null) {
            for (Object o : (List<Object>) m.get('insights')) {
                Map<String, Object> im = (Map<String, Object>) o;
                if (im.get('title') != null && im.get('detail') != null) card.sections.add(PPViewRunner.section((String) im.get('title'), (String) im.get('detail')));
            }
        }
    }

    private static List<PPEventPerson> people(PPEventBrief c) {
        List<PPEventPerson> l = new List<PPEventPerson>();
        if (c.speakers != null) l.addAll(c.speakers);
        if (c.attendees != null) l.addAll(c.attendees);
        if (c.colleagues != null) l.addAll(c.colleagues);
        return l;
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

    @TestVisible
    private static String focusOf(String q) {
        String s = nz(q).toLowerCase();
        Boolean attendeeWords = has(s, new List<String>{ 'attendee', 'invitee', 'invited', 'invite', 'guest', 'coming', 'rsvp', 'accepted', 'declined', 'responded', 'audience', 'colleague', 'who is on', 'participant' });
        if (has(s, new List<String>{ 'budget', 'cost', 'spend', 'expense', 'money', 'afford' })) return 'budget';
        if (has(s, new List<String>{ 'speaker', 'presenter', 'faculty', 'presenting', 'speaking' }) && !attendeeWords) return 'speakers';
        if (has(s, new List<String>{ 'previous', 'earlier', 'other event', 'past event', 'before', 'history', 'no-show', 'no show', 'show up', 'showed', 'attend', 'missed', 'repeat', 'regular', 'track record' })) return 'history';
        if (attendeeWords) return 'attendees';
        return 'overview';
    }

    private static Boolean has(String s, List<String> words) {
        for (String w : words) if (s.contains(w)) return true;
        return false;
    }

    private static Boolean nameMentioned(String lowerQ, String name) {
        String n = name.toLowerCase();
        if (lowerQ.contains(n)) return true;
        List<String> parts = n.split(' ');
        return parts.size() > 1 && parts[parts.size() - 1].length() >= 4 && lowerQ.contains(parts[parts.size() - 1]);
    }

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

    private static PPMetric metric(String label, String value, String tone) {
        PPMetric m = new PPMetric();
        m.label = label;
        m.value = value;
        m.tone = tone;
        return m;
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
