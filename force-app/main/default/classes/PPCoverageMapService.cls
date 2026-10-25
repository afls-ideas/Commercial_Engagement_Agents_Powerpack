/** Resolve account -> CRM context + stakeholder facts -> prompt template -> JSON -> network. Days since contact, status and coverage % are computed here, not by the model. */
public with sharing class PPCoverageMapService {

    public static PPCoverageMap build(String persona, String templateName, PPCardRequest req) {
        try {
            Id acctId = PPContext.resolveAccountId(req.accountId, req.accountName);
            if (acctId == null) return message('Which account?', 'Tell me the account name (or open its record) and I will map who we cover.');
            String name = [SELECT Name FROM Account WHERE Id = :acctId].Name;
            Map<String, String> inputs = new Map<String, String>{
                'Question' => String.isNotBlank(req.question) ? req.question : 'Who have we not spoken to recently?',
                'Today' => Date.today().format(),
                'AccountContext' => PPContext.forAccount(acctId),
                'PlanContext' => PPContext.planContext(acctId),
                'ScenarioFacts' => PPContext.scenarioFacts(persona, name)
            };
            String body = PPViewRunner.runJson(templateName, inputs);
            if (body == null) return message('Could not read the coverage map', 'The model returned a response I could not parse. Please ask again.');
            PPCoverageMap card = (PPCoverageMap) JSON.deserialize(body, PPCoverageMap.class);
            if (card.nodes == null || card.nodes.isEmpty()) return message('No stakeholders mapped', card.headline != null ? card.headline : 'No stakeholders are mapped for this account yet.');
            PPViewRunner.defaultRecord(card.actions, acctId);
            enrich(card, acctId);
            return card;
        } catch (Exception e) {
            return message('Could not build the coverage map', e.getMessage());
        }
    }

    /** Covered: contact within 60 days and strength >= 50. Gap: no contact, or more than 90 days. Everything else is Cooling. */
    @TestVisible
    private static String status(Integer days, Integer strength) {
        if (days == null || days > 90) return 'Gap';
        if (days <= 60 && strength >= 50) return 'Covered';
        return 'Cooling';
    }

    @TestVisible
    private static void enrich(PPCoverageMap card, Id acctId) {
        Date today = Date.today();
        Integer covered = 0, cooling = 0, gaps = 0, sum = 0;
        Map<String, PPCoverageNode> byName = new Map<String, PPCoverageNode>();
        for (PPCoverageNode n : card.nodes) {
            n.strength = Math.max(0, Math.min(100, n.strength == null ? 0 : n.strength));
            Date last = PPViewRunner.parseDate(n.lastContact);
            n.daysSince = last == null ? null : last.daysBetween(today);
            n.status = status(n.daysSince, n.strength);
            if (n.status == 'Covered') covered++; else if (n.status == 'Cooling') cooling++; else gaps++;
            sum += n.strength;
            if (n.action != null && String.isBlank(n.action.recordId)) n.action.recordId = acctId;
            if (String.isNotBlank(n.name)) byName.put(PPViewRunner.bareName(n.name), n);
        }
        // link people to person accounts by name when one exists
        Set<String> lookup = byName.keySet();
        for (Account a : [SELECT Id, Name FROM Account WHERE IsPersonAccount = true AND Name != null LIMIT 2000]) {
            if (lookup.contains(a.Name.toLowerCase())) byName.get(a.Name.toLowerCase()).recordId = a.Id;
        }
        Integer total = card.nodes.size();
        Integer pct = (covered * 100) / total;
        card.metrics = new List<PPMetric>{
            m('Covered', covered + ' of ' + total, pct >= 70 ? 'positive' : 'warning'),
            m('Cooling', String.valueOf(cooling), cooling > 0 ? 'warning' : 'neutral'),
            m('Gaps', String.valueOf(gaps), gaps > 0 ? 'critical' : 'positive'),
            m('Avg strength', String.valueOf(sum / total), 'neutral')
        };
        card.badge = gaps >= 3 || pct < 40 ? 'Coverage gaps' : (gaps > 0 || cooling > 0 ? 'Needs attention' : 'Well covered');
        card.badgeTone = card.badge == 'Well covered' ? 'positive' : (card.badge == 'Needs attention' ? 'warning' : 'critical');
    }

    private static PPMetric m(String label, String value, String tone) {
        PPMetric x = new PPMetric();
        x.label = label; x.value = value; x.tone = tone;
        return x;
    }

    private static PPCoverageMap message(String headline, String body) {
        PPCoverageMap c = new PPCoverageMap();
        c.title = 'Stakeholder coverage';
        c.headline = headline;
        c.sections = new List<PPSection>{ PPViewRunner.section('Details', body) };
        return c;
    }
}
