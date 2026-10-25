/**
 * Write-back for the Speaker Search card. Runs as the rep (with sharing, USER_MODE). The speaker is re-evaluated here,
 * so a blocked speaker cannot be added by editing the client.
 */
public with sharing class PPSpeakerController {

    @AuraEnabled
    public static PPEventDraftResult addSpeaker(Id eventId, Id expertId) {
        Savepoint sp = Database.setSavepoint();
        try {
            PPCardRequest req = new PPCardRequest();
            req.accountId = eventId;
            PPSpeakerSearchService.EventCtx ctx = PPSpeakerSearchService.findEvent(req);
            if (ctx == null || ctx.ev.Id != eventId) throw new AuraHandledException('Event not found.');
            if (ctx.ev.Status != 'Draft') throw new AuraHandledException('Speakers can only be added to a Draft event. This one is ' + ctx.ev.Status + '.');
            if (!ctx.canEdit) throw new AuraHandledException('You do not have edit access to this event.');
            List<PPSpeakerCandidate> r = PPSpeakerSearchService.evaluate(ctx, new Set<Id>{ expertId }, null);
            if (r.isEmpty()) throw new AuraHandledException('That expert is not an Approved, active speaker.');
            if (r[0].canAdd != true) {
                List<String> why = new List<String>();
                for (PPEventCheck k : r[0].checks) if (k.level == 'block') why.add(k.label + ': ' + k.detail);
                throw new AuraHandledException('Cannot add ' + r[0].name + '. ' + String.join(why, ' '));
            }
            List<EventMgmtPtcpTypeRoleMap> maps = [SELECT Id FROM EventMgmtPtcpTypeRoleMap WHERE MngEventTypeId = :ctx.ev.MngEventTypeId
                                                   AND EventMgmtParticipantType.Name = 'AFLS Expert Type' AND IsActive = true LIMIT 1];
            if (maps.isEmpty()) throw new AuraHandledException('This event type has no speaker role configured.');
            MngEventParticipant p = new MngEventParticipant(Name = (r[0].name + ' - Speaker').left(80), MngEventId = eventId,
                ParticipantId = expertId, EventMgmtPtcpTypeRoleMapId = maps[0].Id);
            SObjectAccessDecision d = Security.stripInaccessible(AccessType.CREATABLE, new List<SObject>{ p });
            Database.SaveResult sr = Database.insert(d.getRecords()[0], true, AccessLevel.USER_MODE);
            if (!sr.isSuccess()) throw new AuraHandledException(sr.getErrors()[0].getMessage());
            PPEventDraftResult out = new PPEventDraftResult();
            out.eventId = p.Id;
            out.eventName = r[0].name;
            out.message = r[0].name + ' added as speaker. No invitation has been sent.';
            return out;
        } catch (AuraHandledException e) {
            Database.rollback(sp);
            throw e;
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    /** Undo: removes the speaker row the rep just added. */
    @AuraEnabled
    public static PPEventDraftResult removeSpeaker(Id participantId) {
        try {
            MngEventParticipant p = [SELECT Id, Name, MngEvent.Status FROM MngEventParticipant WHERE Id = :participantId WITH USER_MODE];
            if (p.MngEvent.Status != 'Draft') throw new AuraHandledException('Only speakers on a Draft event can be removed here.');
            Database.delete(p, true, AccessLevel.USER_MODE);
            PPEventDraftResult out = new PPEventDraftResult();
            out.message = 'Speaker removed.';
            return out;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
