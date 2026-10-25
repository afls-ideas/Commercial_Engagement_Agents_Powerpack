/**
 * A one-tap next action rendered as a button on a Power Pack card.
 * kind: task (create a follow-up Task from `text`) | open (navigate to `recordId`) | copy (copy `text`, e.g. a drafted email)
 *       | escalate (create a Task for Medical Info / Safety / Market Access with `text`).
 * recordId (optional) is the Account/Visit the action relates to.
 */
@JsonAccess(serializable='always' deserializable='always')
global class PPAction {
    @AuraEnabled global String label;
    @AuraEnabled global String kind;
    @AuraEnabled global String text;
    @AuraEnabled global String recordId;
}
