/** Scenario facts -> prompt template -> JSON -> heatmap. Tier counts, days-to-decision and ordering are computed here, not by the model. */
public with sharing class PPFormularyMapService {

    public static PPFormularyMap build(String persona, String templateName, PPCardRequest req) {
        try {
            String facts = PPContext.scenarioFacts(persona, '') + '\n' + PPContext.accountFactsForTerritory(persona);
            Map<String, String> inputs = new Map<String, String>{
                'Question' => String.isNotBlank(req.question) ? req.question : 'Where do we stand on formulary across my accounts?',
                'Focus' => String.isNotBlank(req.accountName) ? req.accountName : 'all accounts',
                'Today' => Date.today().format(),
                'ScenarioFacts' => facts
            };
            String body = PPViewRunner.runJson(templateName, inputs);
            if (body == null) return message('Could not read the formulary status', 'The model returned a response I could not parse. Please ask again.');
            PPFormularyMap card = (PPFormularyMap) JSON.deserialize(body, PPFormularyMap.class);
            if (card.rows == null || card.rows.isEmpty()) return message('No formulary data', card.headline != null ? card.headline : 'No accounts with formulary status are configured.');
            enrich(card);
            return card;
        } catch (Exception e) {
            return message('Could not build the formulary status', e.getMessage());
        }
    }

    @TestVisible
    private static void enrich(PPFormularyMap card) {
        mergeRows(card);
        Date today = Date.today();
        Integer preferred = 0, alternate = 0, restricted = 0, notReviewed = 0, soon = 0;
        for (PPFormularyRow r : card.rows) {
            Date due = PPViewRunner.parseDate(r.decisionDue);
            Date sub = PPViewRunner.parseDate(r.submitted);
            r.daysToDecision = due == null ? null : today.daysBetween(due);
            r.daysSinceSubmission = sub == null ? null : sub.daysBetween(today);
            if (r.daysToDecision != null && r.daysToDecision >= 0 && r.daysToDecision <= 60) soon++;
            r.recordId = PPViewRunner.linkAccount(r.account);
            if (r.action != null && String.isBlank(r.action.recordId)) r.action.recordId = r.recordId;
            if (r.cells != null) for (PPFormularyCell c : r.cells) {
                String t = c.tier == null ? '' : c.tier.toLowerCase();
                if (t.contains('prefer')) preferred++;
                else if (t.contains('altern')) alternate++;
                else if (t.contains('restrict') || t.contains('not covered')) restricted++;
                else notReviewed++;
            }
        }
        // soonest decision first; accounts with no date last
        List<PPFormularyRow> sorted = new List<PPFormularyRow>();
        List<PPFormularyRow> undated = new List<PPFormularyRow>();
        Map<Integer, List<PPFormularyRow>> byDays = new Map<Integer, List<PPFormularyRow>>();
        for (PPFormularyRow r : card.rows) {
            if (r.daysToDecision == null || r.daysToDecision < 0) { undated.add(r); continue; }
            if (!byDays.containsKey(r.daysToDecision)) byDays.put(r.daysToDecision, new List<PPFormularyRow>());
            byDays.get(r.daysToDecision).add(r);
        }
        List<Integer> keys = new List<Integer>(byDays.keySet());
        keys.sort();
        for (Integer k : keys) sorted.addAll(byDays.get(k));
        sorted.addAll(undated);
        card.rows = sorted;
        card.metrics = new List<PPMetric>{
            metric('Preferred', String.valueOf(preferred), 'positive'),
            metric('Alternate', String.valueOf(alternate), 'neutral'),
            metric('Restricted', String.valueOf(restricted), restricted > 0 ? 'critical' : 'neutral'),
            metric('Not reviewed', String.valueOf(notReviewed), 'warning'),
            metric('Decisions in 60 days', String.valueOf(soon), soon > 0 ? 'warning' : 'neutral')
        };
    }

    /** The model sometimes returns one row per account x product; fold them into one row per account with a cell per product. */
    @TestVisible
    private static void mergeRows(PPFormularyMap card) {
        Map<String, PPFormularyRow> byAcct = new Map<String, PPFormularyRow>();
        List<PPFormularyRow> merged = new List<PPFormularyRow>();
        List<String> products = new List<String>();
        for (PPFormularyRow r : card.rows) {
            if (r.cells == null) r.cells = new List<PPFormularyCell>();
            for (PPFormularyCell c : r.cells) if (c.product != null && !products.contains(c.product)) products.add(c.product);
            String k = PPViewRunner.bareName(r.account);
            PPFormularyRow m = byAcct.get(k);
            if (m == null) { byAcct.put(k, r); merged.add(r); continue; }
            for (PPFormularyCell c : r.cells) {
                Boolean have = false;
                for (PPFormularyCell e : m.cells) if (e.product == c.product) have = true;
                if (!have) m.cells.add(c);
            }
            Date a = PPViewRunner.parseDate(m.decisionDue), b = PPViewRunner.parseDate(r.decisionDue);
            if (a == null || (b != null && b < a)) { m.decisionDue = r.decisionDue; m.risk = r.risk != null ? r.risk : m.risk; m.riskTone = r.riskTone != null ? r.riskTone : m.riskTone; }
            Date sa = PPViewRunner.parseDate(m.submitted), sb = PPViewRunner.parseDate(r.submitted);
            if (sa == null || (sb != null && sb < sa)) m.submitted = r.submitted;
            if (m.action == null) m.action = r.action;
        }
        for (PPFormularyRow m : merged) {
            for (String prod : products) {
                Boolean have = false;
                for (PPFormularyCell e : m.cells) if (e.product == prod) have = true;
                if (!have) { PPFormularyCell c = new PPFormularyCell(); c.product = prod; c.tier = 'Not reviewed'; m.cells.add(c); }
            }
        }
        card.rows = merged;
    }

    private static PPMetric metric(String label, String value, String tone) {
        PPMetric m = new PPMetric();
        m.label = label; m.value = value; m.tone = tone;
        return m;
    }

    private static PPFormularyMap message(String headline, String body) {
        PPFormularyMap c = new PPFormularyMap();
        c.title = 'Formulary and pathway status';
        c.headline = headline;
        c.sections = new List<PPSection>{ PPViewRunner.section('Details', body) };
        return c;
    }
}
