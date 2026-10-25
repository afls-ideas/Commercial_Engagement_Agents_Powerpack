/**
 * Write-back for the Event Planner card. Runs as the rep (with sharing, USER_MODE), so object and field access and sharing apply.
 * The proposal is re-validated here: ids are resolved from names and the preflight is re-run, so a client cannot bypass a block.
 */
public with sharing class PPEventDraftController {

    /** Re-runs the preflight after the rep edits the date or attendees. */
    @AuraEnabled
    public static PPEventDraftResult check(String proposalJson) {
        try {
            PPEventProposal p = (PPEventProposal) JSON.deserialize(proposalJson, PPEventProposal.class);
            PPEventPlannerService.complete(p);
            PPEventDraftResult r = new PPEventDraftResult();
            r.proposalJson = JSON.serialize(p);
            return r;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static PPEventDraftResult createDraft(String proposalJson) {
        Savepoint sp = Database.setSavepoint();
        try {
            PPEventProposal p = (PPEventProposal) JSON.deserialize(proposalJson, PPEventProposal.class);
            PPEventPlannerService.complete(p);
            if (p.canCreate != true) {
                List<String> why = new List<String>();
                for (PPEventCheck c : p.checks) if (c.level == 'block') why.add(c.label + ': ' + c.detail);
                throw new AuraHandledException('Cannot create this event. ' + String.join(why, ' '));
            }
            Date start = PPViewRunner.parseDate(p.startDate);
            Time t = parseTime(p.startTime);
            Datetime startDt = Datetime.newInstance(start, t);
            Integer hours = p.durationHours == null || p.durationHours < 1 ? 2 : p.durationHours;

            MngEvent ev = new MngEvent(
                Name = String.isBlank(p.eventName) ? p.eventType : p.eventName.left(80),
                MngEventTypeId = p.eventTypeId,
                Status = 'Draft',
                Mode = validMode(p.mode),
                LocationType = validLocation(p.locationType),
                StartDateTime = startDt,
                EndDateTime = startDt.addHours(hours),
                EstimatedParticipantCount = p.attendees,
                Description = describe(p));
            List<String> dropped = insertUser(new List<SObject>{ ev });

            List<EstimatedExpense> lines = new List<EstimatedExpense>();
            for (PPEventExpense x : p.expenses) {
                lines.add(new EstimatedExpense(Name = (x.label == null ? x.expenseType : x.label).left(80), Amount = x.amount,
                    ExpenseTypeId = x.expenseTypeId, ExpenseSourceId = ev.Id));
            }
            insertUser(lines);

            insertUser(new List<SObject>{ new MngEventBudget(Name = (p.budgetName + ' allocation').left(80), MngEventId = ev.Id,
                BudgetId = p.budgetId, AllocatedAmount = p.totalCost) });

            List<MngEventProduct> prods = new List<MngEventProduct>();
            Set<String> names = new Set<String>(p.products);
            for (Product2 pr : [SELECT Id, Name FROM Product2 WHERE Name IN :names AND IsActive = true]) {
                prods.add(new MngEventProduct(Name = pr.Name.left(80), MngEventId = ev.Id, ProductReferenceRecordId = pr.Id));
            }
            if (!prods.isEmpty()) insertUser(prods);

            PPEventDraftResult r = new PPEventDraftResult();
            r.eventId = ev.Id;
            r.eventName = ev.Name;
            r.message = 'Draft event created with ' + lines.size() + ' estimated expense line(s)' + (prods.isEmpty() ? '' : ' and ' + prods.size() + ' product(s)') + '. Nothing has been sent for approval.'
                + (dropped.isEmpty() ? '' : ' Not set (no access): ' + String.join(dropped, ', ') + '.');
            return r;
        } catch (AuraHandledException e) {
            Database.rollback(sp);
            throw e;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    /** Undo: a draft the rep just created is cancelled, not deleted, so the audit trail stays. */
    @AuraEnabled
    public static PPEventDraftResult cancelDraft(Id eventId) {
        try {
            MngEvent ev = [SELECT Id, Name, Status FROM MngEvent WHERE Id = :eventId WITH USER_MODE];
            if (ev.Status != 'Draft') throw new AuraHandledException('Only a Draft event can be cancelled here. This one is ' + ev.Status + '.');
            ev.Status = 'Cancelled';
            Database.update(ev, AccessLevel.USER_MODE);
            PPEventDraftResult r = new PPEventDraftResult();
            r.eventId = ev.Id;
            r.eventName = ev.Name;
            r.message = 'Draft cancelled.';
            return r;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /** Inserts with the rep's access. Fields the rep cannot create are dropped (and reported) instead of failing the whole draft. */
    private static List<String> insertUser(List<SObject> rows) {
        SObjectAccessDecision d = Security.stripInaccessible(AccessType.CREATABLE, rows);
        List<SObject> clean = d.getRecords();
        for (Database.SaveResult sr : Database.insert(clean, true, AccessLevel.USER_MODE)) {
            if (!sr.isSuccess()) throw new AuraHandledException(sr.getErrors()[0].getMessage());
        }
        for (Integer i = 0; i < rows.size(); i++) rows[i].Id = clean[i].Id;
        List<String> dropped = new List<String>();
        for (Set<String> names : d.getRemovedFields().values()) dropped.addAll(names);
        return dropped;
    }

    private static Time parseTime(String s) {
        try {
            List<String> parts = String.isBlank(s) ? new List<String>{ '18', '00' } : s.trim().split(':');
            return Time.newInstance(Integer.valueOf(parts[0]), parts.size() > 1 ? Integer.valueOf(parts[1]) : 0, 0, 0);
        } catch (Exception e) {
            return Time.newInstance(18, 0, 0, 0);
        }
    }

    private static String validMode(String m) {
        return (m == 'Virtual' || m == 'Hybrid' || m == 'InPerson') ? m : 'InPerson';
    }

    private static String validLocation(String l) {
        return (l == 'CompanyLocation' || l == 'CustomerLocation' || l == 'PartnerLocation' || l == 'ThirdPartyLocation') ? l : 'ThirdPartyLocation';
    }

    /** MngEvent.Description holds 255 characters: purpose first, then the audience and city. */
    private static String describe(PPEventProposal p) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(p.description)) parts.add(p.description);
        if (String.isNotBlank(p.audience)) parts.add('Audience: ' + p.audience);
        parts.add('Via PP Event Planner.');
        return String.join(parts, ' ').left(255);
    }
}
