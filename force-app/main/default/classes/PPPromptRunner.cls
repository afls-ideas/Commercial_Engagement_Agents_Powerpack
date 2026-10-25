/** Thin wrapper over ConnectApi prompt-template generation. All persona behaviour lives in the template. */
public with sharing class PPPromptRunner {
    public static String run(String templateName, Map<String, String> inputs) {
        ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        input.isPreview = false;
        Map<String, ConnectApi.WrappedValue> params = new Map<String, ConnectApi.WrappedValue>();
        for (String key : inputs.keySet()) {
            ConnectApi.WrappedValue v = new ConnectApi.WrappedValue();
            v.value = inputs.get(key);
            params.put('Input:' + key, v);
        }
        input.inputParams = params;
        input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        input.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';
        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result =
            ConnectApi.EinsteinLlm.generateMessagesForPromptTemplate(templateName, input);
        return result.generations[0].text;
    }
}
