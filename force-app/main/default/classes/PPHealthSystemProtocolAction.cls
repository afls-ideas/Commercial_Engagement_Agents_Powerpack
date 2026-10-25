/** Power Pack persona action: PP Health System Protocol Brief. All behaviour lives in prompt template PP_Health_System_Brief; this class only wires it up. */
@JsonAccess(serializable='always' deserializable='always')
global class PPHealthSystemProtocolAction {
    @InvocableMethod(label='PP Health System Protocol Brief' description='Returns a stakeholder and protocol-status CARD for an integrated health system that follows a clinical protocol.')
    global static List<PPCardResult> run(List<PPCardRequest> requests) {
        List<PPCardResult> results = new List<PPCardResult>();
        for (PPCardRequest req : requests) {
            PPCardResult r = new PPCardResult();
            r.card = PPCardService.build('health_system', 'PP_Health_System_Brief', req, false);
            r.summary = r.card.headline != null ? r.card.headline : r.card.title;
            results.add(r);
        }
        return results;
    }
}