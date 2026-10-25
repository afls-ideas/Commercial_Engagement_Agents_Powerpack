/** Scenario facts -> prompt template -> JSON -> bubble matrix. Quadrant, gap and ordering are arithmetic, so they are computed here, not by the model. */
public with sharing class PPWhitespaceMapService {

    public static PPWhitespaceMap build(String persona, String templateName, PPCardRequest req) {
        try {
            Map<String, String> inputs = new Map<String, String>{
                'Question' => String.isNotBlank(req.question) ? req.question : 'Where is the whitespace in my top accounts?',
                'Focus' => String.isNotBlank(req.accountName) ? req.accountName : 'all accounts',
                'ScenarioFacts' => PPContext.scenarioFacts(persona, '') + '\n' + PPContext.accountFactsForTerritory(persona)
            };
            String body = PPViewRunner.runJson(templateName, inputs);
            if (body == null) return message('Could not read the whitespace map', 'The model returned a response I could not parse. Please ask again.');
            PPWhitespaceMap card = (PPWhitespaceMap) JSON.deserialize(body, PPWhitespaceMap.class);
            if (card.accounts == null || card.accounts.isEmpty()) return message('No account data', card.headline != null ? card.headline : 'No accounts with potential and share data are configured.');
            enrich(card);
            return card;
        } catch (Exception e) {
            return message('Could not build the whitespace map', e.getMessage());
        }
    }

    /** Potential >= 50 and share < 50 = Grow; both high = Defend; both low = Develop; low potential, high share = Maintain. */
    @TestVisible
    private static String quadrant(Integer potential, Integer share) {
        Boolean hiP = potential >= 50, hiS = share >= 50;
        return hiP ? (hiS ? 'Defend' : 'Grow') : (hiS ? 'Maintain' : 'Develop');
    }

    @TestVisible
    private static void enrich(PPWhitespaceMap card) {
        Map<String, Integer> counts = new Map<String, Integer>{ 'Grow' => 0, 'Defend' => 0, 'Develop' => 0, 'Maintain' => 0 };
        Integer totalRev = 0, growRev = 0;
        for (PPWhitespaceAccount a : card.accounts) {
            a.potential = Math.max(0, Math.min(100, a.potential == null ? 0 : a.potential));
            a.share = Math.max(0, Math.min(100, a.share == null ? 0 : a.share));
            a.revenue = a.revenue == null ? 0 : a.revenue;
            a.gap = Math.max(0, a.potential - a.share);
            a.quadrant = quadrant(a.potential, a.share);
            counts.put(a.quadrant, counts.get(a.quadrant) + 1);
            totalRev += a.revenue;
            if (a.quadrant == 'Grow') growRev += a.revenue;
            a.recordId = PPViewRunner.linkAccount(a.account);
            if (a.action != null && String.isBlank(a.action.recordId)) a.action.recordId = a.recordId;
        }
        // biggest gap first (selection sort; lists are small)
        List<PPWhitespaceAccount> src = card.accounts.clone();
        List<PPWhitespaceAccount> out = new List<PPWhitespaceAccount>();
        while (!src.isEmpty()) {
            Integer best = 0;
            for (Integer i = 1; i < src.size(); i++) if (src[i].gap > src[best].gap) best = i;
            out.add(src.remove(best));
        }
        card.accounts = out;
        card.metrics = new List<PPMetric>{
            m('Grow', counts.get('Grow'), 'warning'), m('Defend', counts.get('Defend'), 'positive'),
            m('Develop', counts.get('Develop'), 'neutral'), m('Maintain', counts.get('Maintain'), 'neutral')
        };
        PPMetric rev = new PPMetric();
        rev.label = 'Revenue in Grow accounts';
        rev.value = '$' + growRev + 'K of $' + totalRev + 'K';
        rev.tone = 'warning';
        card.metrics.add(rev);
    }

    private static PPMetric m(String label, Integer n, String tone) {
        PPMetric x = new PPMetric();
        x.label = label; x.value = String.valueOf(n); x.tone = tone;
        return x;
    }

    private static PPWhitespaceMap message(String headline, String body) {
        PPWhitespaceMap c = new PPWhitespaceMap();
        c.title = 'Whitespace and opportunity';
        c.headline = headline;
        c.sections = new List<PPSection>{ PPViewRunner.section('Details', body) };
        return c;
    }
}
