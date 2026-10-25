/**
 * Event Planner: gathers org history and budgets, asks the prompt template for a proposal, then resolves ids,
 * totals the cost and runs the compliance preflight in Apex. The model chooses and words; Apex decides pass / warn / block.
 */
public with sharing class PPEventPlannerService {

    /** Event types a commercial rep may propose. Medical, grant and internal types are out of scope. */
    @TestVisible
    private static final Set<String> COMMERCIAL_TYPES = new Set<String>{ 'Speaker Program', 'Promotional Speaker Program', 'Webinar', 'Advisory Board' };
    @TestVisible private static final Integer BLOCK_LEAD_DAYS = 14;
    @TestVisible private static final Integer WARN_LEAD_DAYS = 21;
    @TestVisible private static final Decimal MEAL_CAP_PER_HEAD = 125;
    public static final Decimal SPEAKER_FEE_CAP = 3000;

    public static PPEventProposal build(String persona, String templateName, PPCardRequest req) {
        try {
            Map<String, String> inputs = new Map<String, String>{
                'Question' => String.isNotBlank(req.question) ? req.question : 'Suggest an event I should run.',
                'Today' => Date.today().format() + ' (' + String.valueOf(Date.today()) + ')',
                'BudgetsAndLists' => history() + '\n' + budgetsAndLists(),
                'TerritoryContext' => PPContext.territorySnapshot(),
                'ScenarioFacts' => PPContext.scenarioFacts(persona, null)
            };
            String body = PPViewRunner.runJson(templateName, inputs);
            if (body == null) return message('Could not read the proposal', 'The model returned a response I could not parse. Please ask again.');
            PPEventProposal p = (PPEventProposal) JSON.deserialize(body, PPEventProposal.class);
            complete(p);
            return p;
        } catch (Exception e) {
            return message('Could not plan the event', e.getMessage());
        }
    }

    /** Resolves ids from names, totals the cost, runs the checks and sets the badge. Used for the first proposal and again on every edit and on create. */
    public static void complete(PPEventProposal p) {
        if (p.expenses == null) p.expenses = new List<PPEventExpense>();
        if (p.products == null) p.products = new List<String>();
        if (p.attendees == null || p.attendees < 1) p.attendees = 1;

        Map<String, Id> typeIds = new Map<String, Id>();
        for (MngEventType t : [SELECT Id, Name FROM MngEventType WHERE Name IN :COMMERCIAL_TYPES]) typeIds.put(t.Name, t.Id);
        p.eventTypeId = typeIds.containsKey(nz(p.eventType)) ? String.valueOf(typeIds.get(p.eventType)) : null;

        Map<String, Id> expTypeIds = new Map<String, Id>();
        for (ExpenseType et : [SELECT Id, Name FROM ExpenseType LIMIT 200]) expTypeIds.put(et.Name.toLowerCase(), et.Id);
        Decimal total = 0;
        for (PPEventExpense x : p.expenses) {
            x.amount = x.amount == null ? 0 : x.amount;
            if (x.label != null) x.label = x.label.replaceAll('<[^>]*>', '').trim();
            total += x.amount;
            Id eid = expTypeIds.get(nz(x.expenseType).toLowerCase());
            x.expenseTypeId = eid == null ? null : String.valueOf(eid);
        }
        p.totalCost = total;
        p.costPerAttendee = (total / p.attendees).setScale(0, System.RoundingMode.HALF_UP);

        p.budgetRemaining = null;
        Budget b = pickBudget(p.budgetName, total);
        if (b != null) {
            p.budgetId = String.valueOf(b.Id);
            p.budgetName = b.Name;
            p.budgetRemaining = remaining(b);
        } else {
            p.budgetId = null;
        }

        p.checks = checks(p);
        Boolean block = false;
        Boolean warn = false;
        for (PPEventCheck c : p.checks) {
            if (c.level == 'block') block = true;
            else if (c.level == 'warn') warn = true;
        }
        p.canCreate = !block;
        p.badge = block ? 'Blocked' : (warn ? 'Review needed' : 'Ready to create');
        p.badgeTone = block ? 'critical' : (warn ? 'warning' : 'positive');
    }

    @TestVisible
    private static List<PPEventCheck> checks(PPEventProposal p) {
        List<PPEventCheck> out = new List<PPEventCheck>();
        Date start = PPViewRunner.parseDate(p.startDate);

        if (p.eventTypeId == null) {
            out.add(new PPEventCheck('Event type', 'block', nz(p.eventType) + ' is not a commercial event type you can propose.'));
        } else {
            out.add(new PPEventCheck('Event type', 'pass', p.eventType + ' is a commercial event type.'));
        }

        if (start == null) {
            out.add(new PPEventCheck('Lead time', 'block', 'No valid start date.'));
        } else {
            Integer lead = Date.today().daysBetween(start);
            if (lead < BLOCK_LEAD_DAYS) out.add(new PPEventCheck('Lead time', 'block', lead + ' days notice; ' + BLOCK_LEAD_DAYS + ' are required for compliance review.'));
            else if (lead < WARN_LEAD_DAYS) out.add(new PPEventCheck('Lead time', 'warn', lead + ' days notice; ' + WARN_LEAD_DAYS + ' or more is recommended.'));
            else out.add(new PPEventCheck('Lead time', 'pass', lead + ' days notice.'));
        }

        Integer missing = 0;
        for (PPEventExpense x : p.expenses) if (x.expenseTypeId == null) missing++;
        if (p.expenses.isEmpty()) out.add(new PPEventCheck('Expenses', 'block', 'No estimated expenses; add at least one.'));
        else if (missing > 0) out.add(new PPEventCheck('Expenses', 'block', missing + ' expense line(s) use an expense type that does not exist.'));

        if (p.budgetId == null) {
            out.add(new PPEventCheck('Budget', 'block', 'No budget with enough funds was found.'));
        } else if (p.totalCost > p.budgetRemaining) {
            out.add(new PPEventCheck('Budget', 'block', 'Cost $' + fmt(p.totalCost) + ' exceeds the $' + fmt(p.budgetRemaining) + ' left in ' + p.budgetName + '.'));
        } else if (p.totalCost > p.budgetRemaining * 0.5) {
            out.add(new PPEventCheck('Budget', 'warn', 'Uses ' + (p.totalCost * 100 / p.budgetRemaining).setScale(0) + '% of the $' + fmt(p.budgetRemaining) + ' left in ' + p.budgetName + '.'));
        } else {
            out.add(new PPEventCheck('Budget', 'pass', '$' + fmt(p.totalCost) + ' of $' + fmt(p.budgetRemaining) + ' left in ' + p.budgetName + '.'));
        }

        Decimal mealPerHead = 0;
        Decimal speakerFee = 0;
        for (PPEventExpense x : p.expenses) {
            String t = nz(x.expenseType).toLowerCase();
            if (t == 'dinner' || t == 'lunch' || t == 'catering') mealPerHead += x.amount / p.attendees;
            if (t == 'speaker fee') speakerFee += x.amount;
        }
        if (mealPerHead > MEAL_CAP_PER_HEAD) out.add(new PPEventCheck('Meal cap', 'warn', 'Meals are $' + mealPerHead.setScale(0) + ' per head; the cap is $' + MEAL_CAP_PER_HEAD + '.'));
        else if (mealPerHead > 0) out.add(new PPEventCheck('Meal cap', 'pass', 'Meals are $' + mealPerHead.setScale(0) + ' per head (cap $' + MEAL_CAP_PER_HEAD + ').'));
        if (speakerFee > SPEAKER_FEE_CAP) out.add(new PPEventCheck('Speaker fee', 'warn', 'Speaker fees of $' + fmt(speakerFee) + ' are above $' + fmt(SPEAKER_FEE_CAP) + ' and need Compliance review of fair market value.'));

        if (p.eventType == 'Promotional Speaker Program') {
            out.add(new PPEventCheck('Speaker', 'warn', 'Needs an approved speaker. Use Speaker Search after creating the draft.'));
        }

        if (p.eventTypeId != null && start != null) {
            Datetime lo = Datetime.newInstance(start.addDays(-3), Time.newInstance(0, 0, 0, 0));
            Datetime hi = Datetime.newInstance(start.addDays(4), Time.newInstance(0, 0, 0, 0));
            Id typeId = Id.valueOf(p.eventTypeId);
            List<MngEvent> dup = [SELECT Name FROM MngEvent WHERE MngEventTypeId = :typeId AND Status != 'Cancelled'
                                  AND StartDateTime >= :lo AND StartDateTime < :hi LIMIT 3];
            if (!dup.isEmpty()) out.add(new PPEventCheck('Duplicate', 'warn', 'A ' + p.eventType + ' already exists within 3 days: ' + dup[0].Name + '.'));
            else out.add(new PPEventCheck('Duplicate', 'pass', 'No similar event within 3 days.'));
        }
        return out;
    }

    private static Decimal remaining(Budget b) {
        Decimal used = Math.max(b.UtilizedAmount == null ? 0 : b.UtilizedAmount, b.EstimatedUtilizationAmount == null ? 0 : b.EstimatedUtilizationAmount);
        return (b.Amount == null ? 0 : b.Amount) - used;
    }

    /** The named budget if it exists, otherwise the one with the most room. Null when no budget has any funds. */
    private static Budget pickBudget(String name, Decimal need) {
        Budget best = null;
        for (Budget b : [SELECT Id, Name, Amount, UtilizedAmount, EstimatedUtilizationAmount FROM Budget WHERE Status != 'Closed' LIMIT 50]) {
            if (remaining(b) <= 0) continue;
            if (String.isNotBlank(name) && b.Name == name) return b;
            if (best == null || remaining(b) > remaining(best)) best = b;
        }
        return best;
    }

    private static String history() {
        List<String> out = new List<String>{ 'HISTORY BY EVENT TYPE (non-cancelled events in the org):' };
        for (AggregateResult ar : [SELECT MngEventType.Name n, COUNT(Id) c, AVG(EstimatedBudget) b, AVG(EstimatedParticipantCount) p
                                   FROM MngEvent WHERE Status != 'Cancelled' AND MngEventType.Name IN :COMMERCIAL_TYPES GROUP BY MngEventType.Name]) {
            Decimal b = (Decimal) ar.get('b');
            Decimal pc = (Decimal) ar.get('p');
            out.add('- ' + ar.get('n') + ': ' + ar.get('c') + ' events | avg budget $' + (b == null ? 'n/a' : String.valueOf(b.setScale(0)))
                + ' | avg attendees ' + (pc == null ? 'n/a' : String.valueOf(pc.setScale(0))));
        }
        return String.join(out, '\n');
    }

    private static String budgetsAndLists() {
        List<String> out = new List<String>{ 'COMMERCIAL EVENT TYPES: ' + String.join(new List<String>(COMMERCIAL_TYPES), ', ') };
        List<String> bl = new List<String>();
        for (Budget b : [SELECT Name, Amount, UtilizedAmount, EstimatedUtilizationAmount FROM Budget WHERE Status != 'Closed' LIMIT 50]) {
            if (remaining(b) > 0) bl.add(b.Name + ' (remaining $' + fmt(remaining(b)) + ')');
        }
        out.add('BUDGETS WITH FUNDS: ' + (bl.isEmpty() ? 'none' : String.join(bl, '; ')));
        List<String> et = new List<String>();
        for (ExpenseType e : [SELECT Name FROM ExpenseType ORDER BY Name LIMIT 50]) et.add(e.Name);
        out.add('EXPENSE TYPES: ' + String.join(et, ', '));
        List<String> pr = new List<String>();
        for (Product2 p : [SELECT Name FROM Product2 WHERE IsActive = true AND Id IN (SELECT ProductReferenceRecordId FROM MngEventProduct) ORDER BY Name LIMIT 30]) pr.add(p.Name);
        out.add('PRODUCTS: ' + String.join(pr, ', '));
        return String.join(out, '\n');
    }

    private static String fmt(Decimal d) { return d == null ? '0' : d.setScale(0).format(); }
    private static String nz(String s) { return s == null ? '' : s; }

    private static PPEventProposal message(String headline, String body) {
        PPEventProposal c = new PPEventProposal();
        c.title = 'Event proposal';
        c.headline = headline;
        c.canCreate = false;
        c.sections = new List<PPSection>{ PPViewRunner.section('Details', body) };
        return c;
    }
}
