#!/usr/bin/env python3
"""Generate a Power Pack Agent Script bundle + access permission set from a JSON spec.
Usage: gen_agent.py <spec.json>
Spec keys: dev, label, description, persona, system, welcome, main_topic, main_topic_desc, main_action_class,
           main_action_desc, clt, card_label, router_hints (list of [phrase-list, topic-desc]), main_instructions"""
import sys, json, os
s = json.load(open(sys.argv[1]))
base = 'force-app/main/default'
d = f"{base}/aiAuthoringBundles/{s['dev']}"; os.makedirs(d, exist_ok=True)
mt = s['main_topic']
extra = s.get('extra_topics', [])
extra_router = ''.join(f"            - {e['router']} -> use go_to_{e['topic']}\n" for e in extra)
extra_trans = ''.join(f'''            go_to_{e['topic']}: @utils.transition to @topic.{e['topic']}
                description: "{e['desc']}"
''' for e in extra)
def extra_topic(e):
    return f'''
topic {e['topic']}:
    description: "{e['desc']}"

    actions:
        build_card:
            description: "{e['action_desc']} The output is always renderable; always use show_command to display it."
            require_user_confirmation: False
            include_in_progress_indicator: True
            progress_indicator_message: "Building your {e['card_label']}..."
            target: "apex://{e['class']}"
            inputs:
                question: string
                    description: "The user's message. Pass it word-for-word."
                accountId: string
                    description: "The Account record ID from page context. Leave blank to auto-detect."
                accountName: string
                    description: "The account, HCP or health system named by the user"
            outputs:
                card: object
                    description: "The structured {e['card_label']}. The output is always renderable; always use show_command to display it to the user."
                    label: "{e['card_label']}"
                    complex_data_type_name: "c__{e['clt']}"
                    is_displayable: True
                    filter_from_agent: False
                summary: string
                    description: "Plain-text one-line summary of the card, for the planner."
                    filter_from_agent: False

    reasoning:
        instructions: ->
            | The current record ID is {{!@variables.record_id}}
              IMMEDIATELY call the {{!@actions.build}} action. Do NOT ask for more information first.
              - question: pass the user's EXACT message word-for-word.
              - accountName: if the user names a person or organisation, pass it. Never pass "this account" or similar.
              - accountId: if the user says "this account" or names nobody, pass the record_id value.
              {e['instructions']}
              The result is ALWAYS renderable. ALWAYS use show_command to display the returned card.
              NEVER say a card is shown or displayed without actually calling the action first. Call it every time.
              Do NOT re-list, summarize or describe the card in text. Do NOT call the action again after results.

        actions:
            build: @actions.build_card
                description: "{e['action_desc']}"
                with question = ...
                with accountId = @variables.record_id
                with accountName = ...

            back_to_router: @utils.transition to @topic.agent_router
                description: "Go back to ask about a different topic"
'''
extra_topics = ''.join(extra_topic(e) for e in extra)
agent = f'''system:
    instructions: |
        {s['system']}
        You are an AI assistant, not a human.
        Always base your answers on data returned by your actions. Never fabricate account, clinical, patient or certification information.
        Never discuss off-label use or give medical advice; route those to the compliance check.
    messages:
        welcome: "{s['welcome']}"
        error: "Sorry, something went wrong. Please try again."

config:
    developer_name: "{s['dev']}"
    agent_label: "{s['label']}"
    description: "{s['description']}"
    agent_type: "AgentforceEmployeeAgent"

variables:
    record_id: mutable string = ""
        description: "The record ID from the current page context"

language:
    default_locale: "en_US"
    additional_locales: ""
    all_additional_locales: False

start_agent agent_router:
    description: "Route the user to the appropriate topic"
    reasoning:
        instructions: |
            You are a router. Do NOT answer questions directly. Always use a transition action to route immediately.
            - {s['router_main']} -> use go_to_{mt}
{extra_router}            - Any question about whether something can be said, off-label use, an unapproved claim, an adverse event, or "can I tell the doctor..." -> use go_to_compliance_check
            - A general question about an account or HCP that is not the main brief -> use go_to_account_qa
            - Unclear or vague request -> use go_to_ambiguous_question
            - Off-topic request unrelated to the rep's accounts and work -> use go_to_off_topic
        actions:
            go_to_{mt}: @utils.transition to @topic.{mt}
                description: "{s['main_topic_desc']}"
{extra_trans}            go_to_compliance_check: @utils.transition to @topic.compliance_check
                description: "When the user asks whether something is allowed to be said, mentions off-label use, an unapproved claim, or a possible adverse event"
            go_to_account_qa: @utils.transition to @topic.account_qa
                description: "For general questions about an account or HCP, visits, messages or objectives"
            go_to_ambiguous_question: @utils.transition to @topic.ambiguous_question
                description: "When the user request is unclear or vague"
            go_to_off_topic: @utils.transition to @topic.off_topic
                description: "When the request is unrelated to the rep's accounts and work"

topic {mt}:
    description: "{s['main_topic_desc']}"

    actions:
        build_card:
            description: "{s['main_action_desc']} The output is always renderable; always use show_command to display it."
            require_user_confirmation: False
            include_in_progress_indicator: True
            progress_indicator_message: "Building your {s['card_label']}..."
            target: "apex://{s['main_action_class']}"
            inputs:
                question: string
                    description: "The user's message. Pass it word-for-word."
                accountId: string
                    description: "The Account record ID from page context. Leave blank to auto-detect."
                accountName: string
                    description: "The account, HCP or health system named by the user"
            outputs:
                card: object
                    description: "The structured {s['card_label']}. The output is always renderable; always use show_command to display it to the user."
                    label: "{s['card_label']}"
                    complex_data_type_name: "c__{s['clt']}"
                    is_displayable: True
                    filter_from_agent: False
                summary: string
                    description: "Plain-text one-line summary of the card, for the planner."
                    filter_from_agent: False

    reasoning:
        instructions: ->
            | The current record ID is {{!@variables.record_id}}
              IMMEDIATELY call the {{!@actions.build}} action. Do NOT ask for more information first.
              - question: pass the user's EXACT message word-for-word.
              - accountName: if the user names a person or organisation, pass it. Never pass "this account", "this HCP" or similar.
              - accountId: if the user says "this account" or names nobody, pass the record_id value.
              {s['main_instructions']}
              The result is ALWAYS renderable. ALWAYS use show_command to display the returned card.
              NEVER say a card is shown or displayed without actually calling the action first. Call it every time, even for a short or vague request.
              Do NOT re-list, summarize or describe the card in text. Do NOT call the action again after results.

        actions:
            build: @actions.build_card
                description: "{s['main_action_desc']}"
                with question = ...
                with accountId = @variables.record_id
                with accountName = ...

            back_to_router: @utils.transition to @topic.agent_router
                description: "Go back to ask about a different topic"
{extra_topics}
topic compliance_check:
    description: "Classify a question as on-label, off-label, adverse event or promotional claim and give the compliant way to respond"

    actions:
        check:
            description: "Classifies the question and returns the compliant response and escalation steps."
            target: "apex://PPComplianceAction"
            inputs:
                question: string
                    description: "The question exactly as the user asked it, including what the HCP asked"
                accountName: string
                    description: "Optional HCP or account name"
                persona: string
                    description: "Always '{s['persona']}'"
            outputs:
                response: string
                    description: "Classification and compliant response"
                    filter_from_agent: False

    reasoning:
        instructions: ->
            | IMMEDIATELY call the {{!@actions.check_it}} action. Pass the user's question word-for-word, any account name, and persona="{s['persona']}".
              Present the action output directly as plain text. Do NOT add medical advice, do NOT answer off-label or adverse-event questions yourself, and do NOT soften the escalation steps.

        actions:
            check_it: @actions.check
                description: "Run the compliance check"
                with question = ...
                with accountName = ...
                with persona = "{s['persona']}"

            back_to_router: @utils.transition to @topic.agent_router
                description: "Go back to ask about a different topic"

topic account_qa:
    description: "Answer general questions about an account or HCP using visit history, messages and insights"

    actions:
        ask_about_account:
            description: "Ask any question about an account or HCP. Gathers sales context and returns an AI-generated summary."
            target: "apex://FSRAskAboutAccountAction"
            inputs:
                question: string
                    description: "The user's question about the account or HCP"
                accountId: string
                    description: "The Account record ID. Leave blank to auto-detect."
                accountName: string
                    description: "The account or HCP name mentioned by the user"
            outputs:
                output: string
                    description: "AI-generated sales intelligence about the account"
                    filter_from_agent: False

    reasoning:
        instructions: ->
            | The current record ID is {{!@variables.record_id}}
              IMMEDIATELY call the {{!@actions.ask}} action. question = the user's exact message; accountName = any person or organisation named; accountId = the record_id value if no name is given.
              Present the output directly, preserving its line breaks. Remove any "=== VISIT LINKS ===" section. Do NOT call the action again.

        actions:
            ask: @actions.ask_about_account
                description: "Get account or HCP intelligence"
                with question = ...
                with accountId = @variables.record_id
                with accountName = ...

            back_to_router: @utils.transition to @topic.agent_router
                description: "Go back to ask about a different topic"

topic off_topic:
    description: "Redirect off-topic requests"
    reasoning:
        instructions: ->
            | The user asked about something outside your scope. You can help with: {s['scope']}. Politely redirect and suggest what you can do.

        actions:
            back_to_router: @utils.transition to @topic.agent_router
                description: "Return to the main router"

topic ambiguous_question:
    description: "Ask for clarification when the request is unclear"
    reasoning:
        instructions: ->
            | The request was unclear. Ask the user to clarify. You can help with: {s['scope']}.

        actions:
            back_to_router: @utils.transition to @topic.agent_router
                description: "Return to the main router"
'''
open(f"{d}/{s['dev']}.agent", 'w').write(agent)
open(f"{d}/{s['dev']}.bundle-meta.xml", 'w').write('<?xml version="1.0" encoding="UTF-8"?>\n<AiAuthoringBundle xmlns="http://soap.sforce.com/2006/04/metadata">\n  <bundleType>AGENT</bundleType>\n</AiAuthoringBundle>\n')
classes = [s['main_action_class']] + [e['class'] for e in extra] + [c for e in extra for c in e.get('support_classes', [])] + s.get('main_support_classes', []) + [ 'PPComplianceAction', 'PPCardRequest', 'PPCardResult', 'PPCard', 'PPMetric', 'PPSection', 'PPRow', 'PPAction',
           'PPCardService', 'PPCardActionController', 'PPContext', 'PPPromptRunner', 'FSRAskAboutAccountAction', 'TerritoryPreferenceReader']
fp = ''.join(f'    <fieldPermissions>\n        <editable>true</editable>\n        <field>Task.{f}</field>\n        <readable>true</readable>\n    </fieldPermissions>\n' for f in ['ActivityDate', 'Description'])
cx = ''.join(f'    <classAccesses>\n        <apexClass>{c}</apexClass>\n        <enabled>true</enabled>\n    </classAccesses>\n' for c in classes)
open(f"{base}/permissionsets/{s['dev']}_Access.permissionset-meta.xml", 'w').write(f'''<?xml version="1.0" encoding="UTF-8"?>
<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">
    <agentAccesses>
        <agentName>{s['dev']}</agentName>
        <enabled>true</enabled>
    </agentAccesses>
{cx}    <description>Grants access to the {s['label']} agent and its backing Apex classes.</description>
    <hasActivationRequired>false</hasActivationRequired>
{fp}    <objectPermissions>
        <allowCreate>true</allowCreate>
        <allowDelete>false</allowDelete>
        <allowEdit>true</allowEdit>
        <allowRead>true</allowRead>
        <modifyAllRecords>false</modifyAllRecords>
        <object>Task</object>
        <viewAllRecords>false</viewAllRecords>
    </objectPermissions>
    <objectPermissions>
        <allowCreate>false</allowCreate>
        <allowDelete>false</allowDelete>
        <allowEdit>false</allowEdit>
        <allowRead>true</allowRead>
        <modifyAllRecords>false</modifyAllRecords>
        <object>PP_Scenario_Fact__mdt</object>
        <viewAllRecords>true</viewAllRecords>
    </objectPermissions>
    <label>{s['label']} Access</label>
</PermissionSet>
''')
