/** Shared input for every Power Pack persona action. */
@JsonAccess(serializable='always' deserializable='always')
global class PPCardRequest {
    @InvocableVariable(label='Question' description='The rep\'s message, word for word')
    global String question;

    @InvocableVariable(label='Account Id' description='Optional. Account record Id from page context.')
    global String accountId;

    @InvocableVariable(label='Account Name' description='Optional. Account, HCP or health system named by the rep.')
    global String accountName;
}
