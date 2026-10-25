/** Output of the coverage action; `card` is bound to the ppCoverageMap custom Lightning type. */
@JsonAccess(serializable='always' deserializable='always')
global class PPCoverageMapResult {
    @InvocableVariable(label='Coverage Map' description='Structured relationship network rendered by the coverage-map custom Lightning type')
    global PPCoverageMap card;

    @InvocableVariable(label='Summary' description='One-line plain-text summary for the planner')
    global String summary;
}
