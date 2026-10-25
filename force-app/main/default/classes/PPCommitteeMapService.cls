/** Resolve account -> gather context + scenario facts -> run the committee-map prompt template -> parse its JSON. */
public with sharing class PPCommitteeMapService {

    public static PPCommitteeMap build(String persona, String templateName, PPCardRequest req) {
        try {
            Id acctId = PPContext.resolveAccountId(req.accountId, req.accountName);
            if (acctId == null) return message('Which health system?', 'Tell me the health system name (or open its account record) and I will map the committee.');
            String name = [SELECT Name FROM Account WHERE Id = :acctId].Name;
            Map<String, String> inputs = new Map<String, String>{
                'Question' => String.isNotBlank(req.question) ? req.question : 'Map the committee that decides on our product.',
                'AccountContext' => PPContext.forAccount(acctId),
                'ScenarioFacts' => PPContext.scenarioFacts(persona, name)
            };
            PPCommitteeMap card = tryParse(PPPromptRunner.run(templateName, inputs));
            if (card == null) card = tryParse(PPPromptRunner.run(templateName, inputs)); // LLM JSON is occasionally malformed; one retry
            if (card == null) return message('Could not read the committee map', 'The model returned a response I could not parse. Please ask again.');
            if (card.actions != null) for (PPAction a : card.actions) if (String.isBlank(a.recordId)) a.recordId = acctId;
            if (card.members != null) for (PPCommitteeMember m : card.members) {
                if (m.action != null && String.isBlank(m.action.recordId)) m.action.recordId = acctId;
            }
            linkMembers(card);
            tally(card);
            return card;
        } catch (Exception e) {
            return message('Could not build the committee map', e.getMessage());
        }
    }

    /** Link members to person Accounts when one matches by name (title and credentials stripped); otherwise leave unlinked. */
    @TestVisible
    private static void linkMembers(PPCommitteeMap card) {
        if (card.members == null) return;
        Map<String, PPCommitteeMember> byName = new Map<String, PPCommitteeMember>();
        for (PPCommitteeMember m : card.members) {
            if (String.isBlank(m.name)) continue;
            String n = m.name.replaceFirst('^(Dr\\.|Prof\\.)\\s*', '');
            Integer comma = n.indexOf(',');
            if (comma > 0) n = n.substring(0, comma);
            byName.put(n.trim().toLowerCase(), m);
        }
        Set<String> lookup = byName.keySet();
        for (Account a : [SELECT Id, Name FROM Account WHERE IsPersonAccount = true AND Name != null LIMIT 2000]) {
            if (lookup.contains(a.Name.toLowerCase())) byName.get(a.Name.toLowerCase()).recordId = a.Id;
        }
    }

    /** Vote count is arithmetic, not judgement: derive it from member stance so the headline numbers are always right. */
    @TestVisible
    private static void tally(PPCommitteeMap card) {
        if (card.members == null) return;
        Integer voters = 0, with = 0, open = 0, against = 0;
        for (PPCommitteeMember m : card.members) {
            if (m.isVoter == false) continue;
            voters++;
            String st = m.stance == null ? '' : m.stance.toLowerCase();
            if (st == 'champion' || st == 'supporter') with++;
            else if (st == 'skeptic' || st == 'blocker') against++;
            else open++;
        }
        if (voters == 0) return;
        Integer majority = voters / 2 + 1;
        card.votesNeeded = majority + ' of ' + voters + ' votes needed: ' + with + ' with us, ' + open + ' persuadable, ' + against + ' against';
        card.badge = with >= majority ? 'On track' : (with + open >= majority ? 'At risk' : 'Not yet there');
        card.badgeTone = with >= majority ? 'positive' : (with + open >= majority ? 'warning' : 'critical');
    }

    private static PPCommitteeMap tryParse(String raw) {
        String s = raw == null ? '' : raw.trim();
        Integer a = s.indexOf('{');
        Integer b = s.lastIndexOf('}');
        if (a < 0 || b <= a) return null;
        try {
            PPCommitteeMap c = (PPCommitteeMap) JSON.deserialize(s.substring(a, b + 1), PPCommitteeMap.class);
            return c != null && c.members != null && !c.members.isEmpty() ? c : null;
        } catch (Exception e) {
            return null;
        }
    }

    @TestVisible
    private static PPCommitteeMap parse(String raw) {
        String s = raw == null ? '' : raw.trim();
        Integer a = s.indexOf('{');
        Integer b = s.lastIndexOf('}');
        if (a >= 0 && b > a) {
            try {
                PPCommitteeMap c = (PPCommitteeMap) JSON.deserialize(s.substring(a, b + 1), PPCommitteeMap.class);
                if (c != null) return c;
            } catch (Exception e) { /* fall through to plain message */ }
        }
        return message(s.length() > 140 ? s.substring(0, 140) : s, s);
    }

    private static PPCommitteeMap message(String headline, String body) {
        PPCommitteeMap c = new PPCommitteeMap();
        c.title = 'Committee map';
        c.headline = headline;
        PPSection sec = new PPSection();
        sec.heading = 'Details';
        sec.bullets = new List<String>{ body };
        c.sections = new List<PPSection>{ sec };
        return c;
    }
}
