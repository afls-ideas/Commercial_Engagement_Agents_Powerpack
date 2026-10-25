# Scenario: Suggest and draft an event (Event Planner agent)

**Persona:** Sales rep planning a speaker program, webinar or advisory board. **Agent:** `PP_Event_Planner_Agent` · **Lightning type:** `ppEventPlanner`

This is the first Power Pack agent that **writes** to the org. It follows a *propose, confirm, write* pattern: the agent never inserts records by itself. The rep confirms with a button on the card, and the write runs as the rep.

## The story
The rep asks for an event. The agent looks at the org's event history (average cost and attendees by type), the budgets with funds left, the expense types and the products already used on events, then proposes one commercial event with a cost breakdown, a budget fit, who to invite and two alternative formats. A compliance preflight runs in Apex, not in the model. The rep can adjust the date and attendees (the checks re-run), then creates the Draft event, with an Undo.

## Script
1. As the rep, choose **PP Event Planner Agent**.
2. Say: *"Plan an event to engage oncology KOLs in Chicago about Immunexis next month"*
3. Review the card, adjust the date if you like, then choose **Create draft event**.
4. Choose **Open event** to see it, or **Undo (cancel draft)**.

## Expected outcome
![Proposal](images/event-planner-1.png)
![Created](images/event-planner-2.png)

- Proposal with total cost, cost per attendee, budget left, estimated expenses and **Who to invite**.
- **Compliance preflight** (pass / warn / block): commercial event type only, lead time (block under 14 days, warn under 21), budget fit, meal cap per head, speaker fee cap, speaker required for a Promotional Speaker Program, duplicate within 3 days.
- On create: a `MngEvent` in **Draft**, its `EstimatedExpense` lines, a `MngEventBudget` allocation and `MngEventProduct` rows. Nothing is sent for approval.

## How the write is kept safe
- `PPEventDraftController` is `with sharing` and inserts in user mode, so the rep's object and field access apply. Fields the rep cannot set (for example `Mode`) are skipped and reported on the card.
- The proposal is re-validated on the server at create time. Ids are resolved from names there, so a blocked proposal cannot be created by editing the client.
- All inserts are in one transaction (rolled back on any error). Undo sets the status to Cancelled instead of deleting.

## What to customize
Prompt template `PP_Event_Planner`, facts `EV_*` (event rules and type guide), LWC `ppEventPlannerCard`, thresholds and the commercial type list in `PPEventPlannerService`.

## Notes
- Next in this family: Invitee Finder (adds `MngEventParticipant`), Speaker Search (adds an `Expert`), Compliance Check and Closeout.
- Screenshots show the demo org and the test rep user.
