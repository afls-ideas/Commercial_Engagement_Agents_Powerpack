# Field Sales HCP Power Agent

An Agentforce employee agent for pharmaceutical field sales reps built on the Atlas Reasoning Engine using Agent Script. The agent provides account intelligence, visit schedules, and daily briefings — accessible from both the Agentforce desktop panel and mobile SDK.

Ten country-specific agent variants deliver localized content with country-appropriate regulatory framing.

## What It Does

| Topic | Trigger Examples | Backing Action |
|-------|-----------------|----------------|
| **Account Summary** | "Summarize Dr. Sullivan", "Tell me about this HCP", "What are the product guidances?" | `FSRAskAboutAccountAction` |
| **Account Brief (rich card)** | "Overview of Dr. Kim", "Brief me on Stanford Health Care", "Recap this account" | `FSRAccountBriefAction` |
| **Visit Schedule** | "Show my schedule", "My visits this week" | `FSRMyScheduleAction` |
| **Daily Briefing** | "Give me my daily briefing", "Morning update" | `FSRDailyBriefAction` |

## Account Intelligence Data

The account summary action gathers and passes the following context to the LLM:

- Account profile (name, title, email, phone, location, owner)
- Contacts (via AccountContactRelation)
- Previous and planned visits (with visit IDs for navigation)
- Product detailing records (priority, off-label flag, notes, next visit objectives)
- Product messages delivered with HCP reactions (Positive/Neutral/Negative)
- Medical insights with related products (HCP beliefs, clinical preferences, treatment philosophy)
- Recent events and meetings
- Open and completed tasks
- Activity plan progress (plan name, time period, goal vs actual vs scheduled, attainment %)
- Open cases

The prompt template (`FSR_AcctSummary_{countryCode}`) instructs the LLM to analyze this data like a top-performing sales rep — focusing on actionable insights, message effectiveness, visit cadence, HCP beliefs from medical insights, and strategy recommendations.

## Rich Responses (Custom Lightning Types)

Summary/overview/brief requests can render as a **structured card** instead of free text —
clean section headings, bullet lists, and a highlighted next step, rendered by a Lightning
Web Component rather than inconsistent markdown. This is backed by the `FSRAccountBriefAction`
action and the `fsrAccountBrief` custom Lightning type.

See **[docs/LIGHTNING_TYPES.md](docs/LIGHTNING_TYPES.md)** for how CLTs are wired
(Apex type → invocable action → lightningType → LWC), the conventions that make the
`@apexClassType` binding resolve, the runtime permission requirement, and the roadmap for
tables, timelines, and charts.

## Power Pack: Five Persona Agents

Five scenario agents show how Agentforce augments pharma and medtech reps in specific business situations. Each is a thin agent over a shared layer; **the behaviour lives in prompt templates and scenario-fact records the customer can edit**, not in Apex.

| Agent | Persona | Card (custom Lightning type) |
|-------|---------|------------------------------|
| `PP_Myeloma_Launch_Agent` | Oncology launch rep, relapsed/refractory multiple myeloma, REMS + certified-center referral | `ppLaunchFunnel` funnel stepper |
| `PP_Cardio_Regional_Agent` | Cardiology rep in a high-prevalence, low-specialist region | `ppRegionalOpportunity` ranked opportunity list |
| `PP_Health_System_Agent` | Rep managing a health system that follows a clinical protocol / committee process | `ppHealthSystemProtocol` stakeholder + protocol status |
| `PP_Medtech_Cath_Agent` | Medtech cath-lab / structural heart rep | `ppCaseDay` case-day checklist + learning curve |
| `PP_Rare_Disease_Agent` | Rare-disease rep finding undiagnosed patients | `ppDiagnosticJourney` journey stepper |

**How it fits together**
- Apex action (`PP*Action`) -> gathers account context (`PPContext`) + scenario facts -> runs the persona prompt template (`PP_*_Brief`) -> template returns JSON -> parsed to `PPCard` -> rendered by the persona LWC on the shared `ppCardView`, with one-tap buttons (create task, copy text, open record, escalate).
- **Change personality / outcomes:** edit the prompt template in Setup (persona, priorities, compliance rules, output shape).
- **Change facts:** edit `Power Pack Scenario Fact` custom metadata (product, label, REMS, protocol, centers, per-account status). All shipped facts are fictional demo data.
- Every agent has a `compliance_check` topic backed by `PP_Compliance_Guardrails` (on-label / off-label / adverse event / diagnostic suggestion routing).
- `tools/` holds the generators (`gen_template.py`, `gen_facts.py`, `gen_persona_ui.py`, `gen_agent.py`) and the source text/TSV/JSON for each persona; re-run them to regenerate metadata.

**Setup:** assign the agent's `PP_*_Access` permission set plus `EinsteinGPTPromptTemplateUser` to the rep. Publish with `sf agent publish authoring-bundle --api-name <Agent>` then `sf agent activate`.

## Multi-Country Agents

| Country | Agent | Language | Regulatory Framework | Territory Example |
|---------|-------|----------|---------------------|-------------------|
| US | `Field_Sales_HCP_Agent_US` | English | FDA, PDMA, formulary/payer | US-W-San Francisco |
| GB | `Field_Sales_HCP_Agent_GB` | English | MHRA, NICE, NHS, ABPI Code | GB-England-London |
| FR | `Field_Sales_HCP_Agent_FR` | French | ANSM, HAS, CEPS, AMM, Charte visite médicale | FR-Ile-de-France-Paris |
| DE | `Field_Sales_HCP_Agent_DE` | German | BfArM, G-BA, IQWiG, AMNOG | DE-Bayern-Munich |
| IT | `Field_Sales_HCP_Agent_IT` | Italian | AIFA, Farmindustria Code, Registro AIFA | IT-Lazio-Rome |
| ES | `Field_Sales_HCP_Agent_ES` | Spanish | AEMPS, SNS, Farmaindustria Code | ES-Madrid-Madrid |
| JP | `Field_Sales_HCP_Agent_JP` | Japanese | PMDA, MHLW, NHI, JPMA Code | JP-Kanto-Tokyo |
| KR | `Field_Sales_HCP_Agent_KR` | Korean | MFDS, HIRA, NHIS, KRPIA Code, Kim Young-ran Act | KR-Seoul-Seoul |
| BR | `Field_Sales_HCP_Agent_BR` | Portuguese | ANVISA, SUS, Interfarma Code | BR-Sudeste-São Paulo |
| MX | `Field_Sales_HCP_Agent_MX` | Spanish | COFEPRIS, IMSS, CANIFARMA Code | MX-CDMX-Mexico City |

The country code is resolved at runtime from the user's active territory name via `TerritoryPreferenceReader`. Each agent has country-specific system instructions with the applicable regulatory framework.

The schedule action (`FSRMyScheduleAction`) supports localized labels for en_US, fr, de, it, es, ja, and ko.

## Test Results

| Country | Tests | Status | Key Regulatory Content Verified |
|---------|-------|--------|-------------------------------|
| [US](tests/US_TEST_RESULTS.md) | 6/6 | PASSED | NRx/TRx, FDA label, formulary, prior auth, PDMA, samples |
| [GB](tests/GB_TEST_RESULTS.md) | 6/6 | PASSED | NHS, NICE TA, MHRA, traffic-light, ICB, QOF, shared-care, Blueteq, ABPI |
| [FR](tests/FR_TEST_RESULTS.md) | 6/6 | PASSED | HAS, ANSM, CEPS, ASMR, AMM, PMSI, GHT, COMEDIMS, livret thérapeutique |
| [IT](tests/IT_TEST_RESULTS.md) | 6/6 | PASSED | AIFA, Registro AIFA, PTR, PTO, ASL, DD/DPC, SSN, IRCCS, MMG |
| [KR](tests/KR_TEST_RESULTS.md) | 5/6 | 5 PASSED, 1 BLOCKED | MFDS, NHIS, HIRA, KCR, MDT, RSA, biosimilar, 약사위원회 |
| BR | — | Not yet tested | |
| DE | — | Not yet tested | |
| ES | — | Not yet tested | |
| JP | — | Not yet tested | |
| MX | — | Not yet tested | |

Each test suite validates: correct prompt template invocation, native language responses, country-specific regulatory terminology, no cross-country language contamination, account resolution, message effectiveness analysis with dates/reactions, and safety compliance.

## Project Structure

```
force-app/main/default/
├── aiAuthoringBundles/
│   ├── Field_Sales_HCP_Agent_US/
│   ├── Field_Sales_HCP_Agent_GB/
│   ├── Field_Sales_HCP_Agent_FR/
│   ├── Field_Sales_HCP_Agent_DE/
│   ├── Field_Sales_HCP_Agent_IT/
│   ├── Field_Sales_HCP_Agent_ES/
│   ├── Field_Sales_HCP_Agent_JP/
│   ├── Field_Sales_HCP_Agent_KR/
│   ├── Field_Sales_HCP_Agent_BR/
│   └── Field_Sales_HCP_Agent_MX/
├── classes/
│   ├── FSRAskAboutAccountAction.cls       # Account intelligence (Apex + LLM)
│   ├── FSRAccountBriefAction.cls          # Account Brief rich card (Apex + LLM + parser)
│   ├── FSRAccountBrief*.cls               # CLT data/invocable types (see docs/LIGHTNING_TYPES.md)
│   ├── FSRDailyBriefAction.cls            # Daily briefing (Apex + LLM)
│   └── FSRMyScheduleAction.cls            # Visit schedule (Apex, HTML output)
├── lightningTypes/
│   └── fsrAccountBrief/                   # CLT: schema + desktop renderer binding
├── lwc/
│   └── fsrAccountBriefCard/               # LWC that renders the Account Brief card
├── genAiPromptTemplates/
│   ├── FSR_AcctSummary_{US,GB,FR,DE,IT,ES,JP,KR,BR,MX}
│   └── FSR_DailyBrief_{US,GB,FR,DE,IT,ES,JP,KR,BR,MX}
├── permissionsets/
│   ├── Demo_FSR_Power_Agent_{CC}.permissionset-meta.xml
│   └── Field_Sales_HCP_Agent_{CC}_Access.permissionset-meta.xml
└── tests/
    ├── US_TEST_RESULTS.md
    ├── GB_TEST_RESULTS.md
    ├── FR_TEST_RESULTS.md
    ├── IT_TEST_RESULTS.md
    └── KR_TEST_RESULTS.md
```

## Deployment

```bash
# Set target org
sf config set target-org <your-org-alias>

# Deploy all metadata
sf project deploy start --source-dir force-app

# Publish and activate an agent (repeat per country)
sf agent publish authoring-bundle --api-name Field_Sales_HCP_Agent_US
sf agent activate --api-name Field_Sales_HCP_Agent_US
```

## Permission Setup

Each country has its own permission sets. Assign to users who need agent access:

- **Field_Sales_HCP_Agent_{CC}_Access** — grants access to the agent and all backing Apex classes
- **Demo_FSR_Power_Agent_{CC}** — includes the above plus RunFlow permission

Both permission sets grant access to: `FSRAskAboutAccountAction`, `FSRDailyBriefAction`, `FSRMyScheduleAction`, and `TerritoryPreferenceReader`.

The Account Brief rich card additionally requires the `FSRAccountBrief*` classes (granted in `Demo_FSR_Power_Agent_US`) and, because its action invokes a prompt template, the `ExecutePromptTemplates` user permission. Assign the standard **`EinsteinGPTPromptTemplateUser`** permission set to reps — this cannot be granted via a bare `<userPermissions>` entry (it is license-gated). See [docs/LIGHTNING_TYPES.md](docs/LIGHTNING_TYPES.md#runtime-permission-requirement).

## Dependencies

- Life Sciences Cloud with Visits, Provider Visit Product Detailing, and Activity Plans
- Einstein Generative AI (for prompt template invocation via `ConnectApi.EinsteinLlm`)
- Territory Management (for territory-aware account filtering and country resolution)
- `TerritoryPreferenceReader` Apex class (deployed separately in the org)

## Scenario walk-throughs

Each walk-through has a script, the expected card in the Agentforce panel, and what to customize:

- [Myeloma launch](docs/scenarios/myeloma-launch.md)
- [Cardio regional opportunity](docs/scenarios/cardio-regional-opportunity.md)
- [Health system committee buy-in (P&T map)](docs/scenarios/health-system-committee-buy-in.md)
- [Medtech case-day readiness](docs/scenarios/medtech-case-day.md)
- [Rare disease diagnostic journey](docs/scenarios/rare-disease-diagnostic-journey.md)

Commercial account-planning agents (each with its own visualization):

- [Account plan builder](docs/scenarios/account-plan-builder.md): goal tree, plan-health gauge, SWOT
- [Formulary and pathway status](docs/scenarios/formulary-pathway-status.md): tier heatmap, decision timeline
- [Whitespace and opportunity](docs/scenarios/whitespace-opportunity.md): bubble matrix with Grow / Defend / Develop / Maintain
- [Stakeholder coverage](docs/scenarios/stakeholder-coverage.md): org-chart network with strength rings and gaps
- [Cross-functional QBR huddle](docs/scenarios/qbr-account-huddle.md): timeline, scorecard vs plan, decisions, actions by function

### Managed Events agents (read and write)
- [Event Planner](docs/scenarios/event-planner.md): suggests an event, runs a compliance preflight, creates the Draft event after the rep confirms, recommends speakers for an existing event, and answers questions about an event or a person (speakers, attendees, who showed up at earlier events, other events invited to), record-page aware

Screenshots show org and user details; review before publishing.
