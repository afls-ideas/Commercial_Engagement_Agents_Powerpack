/** Resolve account -> CRM plan data + scenario facts -> prompt template -> JSON -> plan canvas. Plan health is computed here, not by the model. */
public with sharing class PPAccountPlanService {

    public static PPAccountPlan build(String persona, String templateName, PPCardRequest req) {
        try {
            Id acctId = PPContext.resolveAccountId(req.accountId, req.accountName);
            if (acctId == null) return message('Which account?', 'Tell me the account name (or open its record) and I will draft the plan.');
            String name = [SELECT Name FROM Account WHERE Id = :acctId].Name;
            Map<String, String> inputs = new Map<String, String>{
                'Question' => String.isNotBlank(req.question) ? req.question : 'Draft the annual account plan.',
                'AccountContext' => PPContext.forAccount(acctId),
                'PlanContext' => PPContext.planContext(acctId),
                'ScenarioFacts' => PPContext.scenarioFacts(persona, name)
            };
            String body = PPViewRunner.runJson(templateName, inputs);
            if (body == null) return message('Could not read the plan', 'The model returned a response I could not parse. Please ask again.');
            PPAccountPlan card = (PPAccountPlan) JSON.deserialize(body, PPAccountPlan.class);
            if (card.objectives == null || card.objectives.isEmpty()) return message('No objectives found', card.headline != null ? card.headline : 'There are no plan objectives for this account yet.');
            PPViewRunner.defaultRecord(card.actions, acctId);
            for (PPPlanObjective o : card.objectives) if (o.action != null && String.isBlank(o.action.recordId)) o.action.recordId = acctId;
            applyFacts(card, PPContext.factTexts(persona, name, 'Plan objective'));
            health(card);
            return card;
        } catch (Exception e) {
            return message('Could not build the plan', e.getMessage());
        }
    }

    /** Plan health = average objective progress; the badge and status counts follow from it so the numbers are always consistent. */
    @TestVisible
    private static void health(PPAccountPlan card) {
        Integer total = 0, onTrack = 0, atRisk = 0, off = 0;
        for (PPPlanObjective o : card.objectives) {
            Integer p = o.progress == null ? 0 : Math.max(0, Math.min(100, o.progress));
            o.progress = p;
            total += p;
            String st = o.status == null ? '' : o.status.toLowerCase();
            if (st.contains('off')) off++;
            else if (st.contains('risk')) atRisk++;
            else if (st.contains('track') || st.contains('complete')) onTrack++;
        }
        Integer n = card.objectives.size();
        card.planHealth = total / n;
        card.healthSummary = onTrack + ' on track, ' + atRisk + ' at risk, ' + off + ' off track';
        card.badge = off > 0 || card.planHealth < 35 ? 'Needs attention' : (atRisk > 0 || card.planHealth < 65 ? 'Watch' : 'Healthy');
        card.badgeTone = card.badge == 'Healthy' ? 'positive' : (card.badge == 'Watch' ? 'warning' : 'critical');
    }

    /** Progress and status are recorded facts, not judgement: copy them from the best-matching objective fact (by shared words in the title). */
    @TestVisible
    private static void applyFacts(PPAccountPlan card, List<String> facts) {
        for (PPPlanObjective o : card.objectives) {
            Set<String> words = words(o.title);
            Integer bestScore = 0;
            String best;
            for (String f : facts) {
                Integer score = 0;
                for (String w : words(field(f, 'OBJECTIVE'))) if (words.contains(w)) score++;
                if (score > bestScore) { bestScore = score; best = f; }
            }
            if (best == null || bestScore < 2) continue;
            String p = field(best, 'PROGRESS');
            if (String.isNotBlank(p) && p.isNumeric()) o.progress = Integer.valueOf(p);
            String s = field(best, 'STATUS');
            if (String.isNotBlank(s)) o.status = s;
        }
    }

    private static String field(String fact, String key) {
        for (String part : fact.split('\\|')) {
            String t = part.trim();
            if (t.startsWith(key + ':')) return t.substring(key.length() + 1).trim();
        }
        return '';
    }

    private static Set<String> words(String s) {
        Set<String> out = new Set<String>();
        if (s == null) return out;
        for (String w : s.toLowerCase().split('[^a-z0-9]+')) if (w.length() > 3) out.add(w);
        return out;
    }

    private static PPAccountPlan message(String headline, String body) {
        PPAccountPlan c = new PPAccountPlan();
        c.title = 'Account plan';
        c.headline = headline;
        c.sections = new List<PPSection>{ PPViewRunner.section('Details', body) };
        return c;
    }
}
