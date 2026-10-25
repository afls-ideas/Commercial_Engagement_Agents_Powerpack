/** One ranked speaker on the Speaker Search card. Score, fit and checks are computed in Apex; `why` is worded by the model. */
@JsonAccess(serializable='always' deserializable='always')
global class PPSpeakerCandidate {
    @AuraEnabled global String expertId;
    @AuraEnabled global String accountId;
    @AuraEnabled global String name;
    @AuraEnabled global String specialty;
    @AuraEnabled global String city;
    @AuraEnabled global Integer tier;
    @AuraEnabled global Decimal fee;
    @AuraEnabled global String trained;
    @AuraEnabled global Integer programsYtd;
    @AuraEnabled global Integer score;
    @AuraEnabled global String fit;
    @AuraEnabled global String why;
    @AuraEnabled global Boolean canAdd;
    @AuraEnabled global Boolean added;
    @AuraEnabled global List<PPEventCheck> checks;
}
