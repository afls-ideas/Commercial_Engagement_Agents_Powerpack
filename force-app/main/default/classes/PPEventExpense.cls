/** One estimated expense line on an event proposal. Ids are resolved from the names on the server, never trusted from the client. */
@JsonAccess(serializable='always' deserializable='always')
global class PPEventExpense {
    @AuraEnabled global String label;
    @AuraEnabled global String expenseType;
    @AuraEnabled global String expenseTypeId;
    @AuraEnabled global Decimal amount;
}
