# Agentforce custom Lightning type cards: desktop, iPad/iPhone and record links

Knowledge-base write-up. Tested in a Winter '27 org (API 68.0) with Agent Script employee agents, custom Lightning types (CLTs) and LWCs, in the desktop Agentforce panel and the Salesforce mobile app on iPad.

## 1. How a card gets on screen
Apex invocable returns an Apex class (`@AuraEnabled global` fields, `@JsonAccess`) -> the agent action declares `complex_data_type_name: "c__<cltName>"` -> the CLT bundle `lightningTypes/<cltName>/` (`schema.json` = `@apexClassType/c__<ApexClass>`) -> `lightningDesktopGenAi/renderer.json` and `lightningMobileGenAi/renderer.json`, each `{"renderer":{"componentOverrides":{"$":{"definition":"c/<lwc>"}}}}` -> the LWC.

## 2. What the LWC must do to render on mobile
1. Meta file: targets `lightning__AgentforceOutput` **and `lightning__UrlAddressable`**. Without UrlAddressable the card is blank on mobile with no error. This was the last missing piece after everything else was correct.
2. Meta file: `<supportedFormFactors>` with `Small` and `Large` inside the `lightning__AgentforceOutput` targetConfig (the deploy fails without it), and `<sourceType name="c__<cltName>"/>`.
3. Data: desktop passes the object to `@api value`. Mobile does not. Mobile passes each field as a page-reference state param `c__<field>`, only when `c__channel === 'Mobile'`. Lists and objects arrive as JSON strings and must be `JSON.parse`d. Read them with `@wire(CurrentPageReference)`. Keep both paths:
   - `@api get/set value` stores `_val` (desktop).
   - the wire stores `_mob` (mobile), and the `value` getter returns `_val || _mob`.
4. A mobile renderer can point at the same rich component as desktop. A separate stripped-down mobile card is not needed.
5. Deploy `lightningMobileGenAi/renderer.json`; the `lightningTypes` folder must contain it.

## 3. Troubleshooting a blank or wrong card
- Blank on iPad, fine on desktop: check UrlAddressable, then form factors, then that the `c__` params are read. Force-quit the app and test in a **new** chat; an old chat keeps the old render.
- Text shows but no card: the renderer or sourceType is not matched. Check the `complex_data_type_name`, CLT folder name and `sourceType` all agree.
- Wrong card shown, or card missing its fields: **every action in the agent needs a unique name.** When three topics all named their action `build_card`, the data of one topic rendered in another topic's card. Use `build_<topic>_card`.
- To see which component rendered, in Playwright check `page.locator('c-your-card').count()` and `getRootNode().host.tagName`. A debug line in the template that never appears means a different component rendered.
- Org content can differ from local even after "Changed" in the deploy table; query the Tooling API (`LightningComponentResource.Source`) to confirm what is deployed.
- Apex imports (`@salesforce/apex/...`) in a card are a suspect for blank mobile cards. An Apex-free variant is being tested; see the project notes.

## 4. Record links from a card (Open event, open record)
Use one shared Apex-free helper, `c/ppOpenRecord` (`openRecord(cmp, recordId, mobile)`).
- Mobile app: set `window.location.href = lsc://deeplink/lightning/r/<Object>/<id>/view`. An unhandled scheme does not throw, so also start a 1.2 second timer; if the page has not fired `pagehide`/`visibilitychange`, fall back to `NavigationMixin.Navigate`.
- Everywhere else: `NavigationMixin.Navigate` only. **Never** set an `lsc://` location on desktop; Safari shows "Safari cannot open the page because the address is invalid" and then navigates.
- Object name comes from the id key prefix (`001` Account, `003` Contact, `00T` Task, `500` Case, `006` Opportunity, `1PO` MngEvent); unknown prefixes use plain navigation.
- How the card knows it is on mobile: desktop never receives the `c__` page-reference params. The card treats itself as mobile when `!this._val && !!this._mob`. Child components (for example the shared card view) take a `mobile` property from the parent. User-agent sniffing is not needed.
- All Power Pack cards use this helper. `fsrAccountList` uses its own `mobileUrl` and is separate.

## 5. Record-page context in the agent (so the agent does not ask "which account?")
Declare `currentRecordId`, `currentObjectApiName`, `currentPageType` as External mutable string variables, and bind them in the action with `with accountId = @variables.currentRecordId`. The instruction tells the agent to pass the record id as the account or event id and never ask first. The same variable works for any object, so the action decides whether the id is an Account or an event.

## 6. Routing between topics in one agent
- Put the specific topic's router line first and word it as a priority, with explicit "not for" lines on the neighbours.
- The topic descriptions are used by the router as well as the router instructions. A sentence such as "if the event already has a speaker it summarises that instead" in one topic's description will attract questions meant for another.
- A request to plan a NEW thing on an existing record page must be carved out in the existing-record topic.

## 7. Data the model narrates versus data Apex computes
Counts, flags, rosters and history are computed in Apex. The model writes only the headline, insights and next step. Put explicit wording rules in the prompt for things the model overstates, for example "attended" only when the outcome is Attended, and "no attendance recorded" is not a no-show.
