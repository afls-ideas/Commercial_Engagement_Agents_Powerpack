/** Resolve account -> CRM context + QBR facts -> prompt template -> JSON -> storyboard. Attainment, status and days-to-milestone are arithmetic, so they are computed here. */
public with sharing class PPQbrService {

    public static PPQbr build(String persona, String templateName, PPCardRequest req) {
        try {
            Id acctId = PPContext.resolveAccountId(req.accountId, req.accountName);
            if (acctId == null) return message('Which account?', 'Tell me the account name (or open its record) and I will prep the business review.');
            String name = [SELECT Name FROM Account WHERE Id = :acctId].Name;
            Map<String, String> inputs = new Map<String, String>{
                'Question' => String.isNotBlank(req.question) ? req.question : 'Prep the quarterly business review.',
                'Today' => Date.today().format(),
                'AccountContext' => PPContext.forAccount(acctId),
                'PlanContext' => PPContext.planContext(acctId),
                'ScenarioFacts' => PPContext.scenarioFacts(persona, name)
            };
            String body = PPViewRunner.runJson(templateName, inputs);
            if (body == null) return message('Could not read the QBR', 'The model returned a response I could not parse. Please ask again.');
            PPQbr card = (PPQbr) JSON.deserialize(body, PPQbr.class);
            PPViewRunner.defaultRecord(card.actions, acctId);
            if (card.decisions != null) for (PPQbrDecision d : card.decisions) if (d.action != null && String.isBlank(d.action.recordId)) d.action.recordId = acctId;
            enrich(card);
            return card;
        } catch (Exception e) {
            return message('Could not build the QBR', e.getMessage());
        }
    }

    /** Ahead >= 105 percent of plan, On plan 90-104, Behind 75-89, Off plan below 75. */
    @TestVisible
    private static String status(Integer pct) {
        return pct >= 105 ? 'Ahead' : (pct >= 90 ? 'On plan' : (pct >= 75 ? 'Behind' : 'Off plan'));
    }

    @TestVisible
    private static void enrich(PPQbr card) {
        Date today = Date.today();
        Integer behind = 0;
        if (card.scorecard != null) for (PPQbrScore s : card.scorecard) {
            if (s.plan == null || s.plan == 0 || s.actual == null) { s.attainment = null; s.status = 'No data'; continue; }
            s.attainment = Integer.valueOf((s.actual * 100 / s.plan).round(System.RoundingMode.HALF_UP));
            s.status = status(s.attainment);
            if (s.attainment < 90) behind++;
        }
        if (card.milestones != null) for (PPQbrMilestone m : card.milestones) {
            Date d = PPViewRunner.parseDate(m.eventDate);
            m.daysFromToday = d == null ? null : today.daysBetween(d);
            if (m.status == null) m.status = d != null && d < today ? 'done' : 'next';
        }
        Integer open = card.decisions == null ? 0 : card.decisions.size();
        card.badge = behind >= 2 ? 'Difficult QBR' : (behind == 1 || open >= 3 ? 'Prepare carefully' : 'On track');
        card.badgeTone = card.badge == 'On track' ? 'positive' : (card.badge == 'Prepare carefully' ? 'warning' : 'critical');
    }

    private static PPQbr message(String headline, String body) {
        PPQbr c = new PPQbr();
        c.title = 'Business review';
        c.headline = headline;
        c.sections = new List<PPSection>{ PPViewRunner.section('Details', body) };
        return c;
    }
}
