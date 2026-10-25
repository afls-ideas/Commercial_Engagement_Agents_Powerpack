/** Shared compliance responder: classifies a rep's question (on-label / off-label / adverse event / other) and drafts the permitted response. Rules live in template PP_Compliance_Guardrails. */
global class PPComplianceAction {
    global class Req {
        @InvocableVariable(label='Question' description='The rep\'s question or what an HCP asked them' required=true)
        global String question;
        @InvocableVariable(label='Account Name' description='Optional HCP or account the question relates to')
        global String accountName;
        @InvocableVariable(label='Persona' description='Persona key: myeloma_launch, cardio_regional, health_system, medtech_cath or rare_disease')
        global String persona;
    }
    global class Res {
        @InvocableVariable(label='Response' description='Classification and compliant response guidance')
        global String response;
    }
    @InvocableMethod(label='PP Compliance Check' description='Classifies a question as on-label, off-label, adverse event or other, and returns the compliant way to respond or escalate.')
    global static List<Res> run(List<Req> requests) {
        List<Res> out = new List<Res>();
        for (Req r : requests) {
            Res res = new Res();
            try {
                res.response = PPPromptRunner.run('PP_Compliance_Guardrails', new Map<String, String>{
                    'Question' => r.question,
                    'ScenarioFacts' => PPContext.scenarioFacts(String.isNotBlank(r.persona) ? r.persona : 'shared', r.accountName)
                        + '\n' + PPContext.scenarioFacts('shared', null),
                    'AccountContext' => 'Account: ' + (r.accountName == null ? 'not specified' : r.accountName)
                });
            } catch (Exception e) {
                res.response = 'Could not run the compliance check: ' + e.getMessage();
            }
            out.add(res);
        }
        return out;
    }
}