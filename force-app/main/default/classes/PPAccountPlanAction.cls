/** Power Pack action: draft or review a key account plan. All behaviour lives in prompt template PP_Account_Plan. */
@JsonAccess(serializable='always' deserializable='always')
global class PPAccountPlanAction {
    @InvocableMethod(label='PP Account Plan Builder' description='Drafts or reviews the annual account plan for a key account: objectives with owner, KPI target versus actual, status, SWOT and the plan health.')
    global static List<PPAccountPlanResult> run(List<PPCardRequest> requests) {
        List<PPAccountPlanResult> results = new List<PPAccountPlanResult>();
        for (PPCardRequest req : requests) {
            PPAccountPlanResult r = new PPAccountPlanResult();
            r.card = PPAccountPlanService.build('account_plan', 'PP_Account_Plan', req);
            r.summary = r.card.headline != null ? r.card.headline : r.card.title;
            results.add(r);
        }
        return results;
    }
}