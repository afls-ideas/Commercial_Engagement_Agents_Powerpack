/** Output of the account-plan action; `card` is bound to the ppAccountPlan custom Lightning type. */
@JsonAccess(serializable='always' deserializable='always')
global class PPAccountPlanResult {
    @InvocableVariable(label='Account Plan' description='Structured plan canvas rendered by the account-plan custom Lightning type')
    global PPAccountPlan card;

    @InvocableVariable(label='Summary' description='One-line plain-text summary of the plan for the planner')
    global String summary;
}
