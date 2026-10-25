/**
 * Orchestrates one persona action: resolve account -> gather context + scenario facts -> run the persona prompt
 * template -> parse the JSON card the template returns. No persona-specific logic lives here.
 */
public with sharing class PPCardService {

    public static PPCard build(String persona, String templateName, PPCardRequest req, Boolean territoryLevel) {
        try {
            Id acctId = PPContext.resolveAccountId(req.accountId, req.accountName);
            String ctx;
            String facts;
            if (acctId != null) {
                ctx = PPContext.forAccount(acctId);
                String name = [SELECT Name FROM Account WHERE Id = :acctId].Name;
                facts = PPContext.scenarioFacts(persona, name);
            } else if (territoryLevel) {
                ctx = PPContext.territorySnapshot();
                facts = PPContext.scenarioFacts(persona, null) + '\n' + PPContext.accountFactsForTerritory(persona);
            } else {
                return message(persona, 'Which account?', 'Tell me the HCP or health system name (or open the account record) and I will build this.');
            }
            Map<String, String> inputs = new Map<String, String>{
                'Question' => String.isNotBlank(req.question) ? req.question : 'Give me the brief for this scenario.',
                'AccountContext' => ctx,
                'ScenarioFacts' => facts
            };
            String raw = PPPromptRunner.run(templateName, inputs);
            PPCard card = tryParse(raw);
            if (card == null) card = tryParse(PPPromptRunner.run(templateName, inputs)); // LLM JSON is occasionally malformed or cut off; one retry
            if (card == null) card = parse(raw, persona);
            card.variant = persona;
            if (acctId != null) {
                if (card.actions != null) for (PPAction act : card.actions) if (String.isBlank(act.recordId)) act.recordId = acctId;
                if (card.rows != null) for (PPRow row : card.rows) if (row.action != null && String.isBlank(row.action.recordId)) row.action.recordId = acctId;
            }
            return card;
        } catch (Exception e) {
            return message(persona, 'Could not build the card', e.getMessage());
        }
    }

    private static PPCard tryParse(String raw) {
        String s = raw == null ? '' : raw.trim();
        Integer a = s.indexOf('{');
        Integer b = s.lastIndexOf('}');
        if (a < 0 || b <= a) return null;
        try {
            return (PPCard) JSON.deserialize(s.substring(a, b + 1), PPCard.class);
        } catch (Exception e) {
            return null;
        }
    }

    @TestVisible
    private static PPCard parse(String raw, String persona) {
        String s = raw == null ? '' : raw.trim();
        Integer a = s.indexOf('{');
        Integer b = s.lastIndexOf('}');
        if (a >= 0 && b > a) {
            try {
                PPCard c = (PPCard) JSON.deserialize(s.substring(a, b + 1), PPCard.class);
                if (c != null) return c;
            } catch (Exception e) { /* fall through to plain-text card */ }
        }
        return message(persona, s.length() > 140 ? s.substring(0, 140) : s, s);
    }

    private static PPCard message(String persona, String headline, String body) {
        PPCard c = new PPCard();
        c.variant = persona;
        c.title = 'Power Pack';
        c.headline = headline;
        PPSection sec = new PPSection();
        sec.heading = 'Details';
        sec.bullets = new List<String>{ body };
        c.sections = new List<PPSection>{ sec };
        return c;
    }
}
