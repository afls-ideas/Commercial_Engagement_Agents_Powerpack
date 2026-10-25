/** Output of the formulary action; `card` is bound to the ppFormularyMap custom Lightning type. */
@JsonAccess(serializable='always' deserializable='always')
global class PPFormularyMapResult {
    @InvocableVariable(label='Formulary Map' description='Structured heatmap rendered by the formulary-map custom Lightning type')
    global PPFormularyMap card;

    @InvocableVariable(label='Summary' description='One-line plain-text summary for the planner')
    global String summary;
}
