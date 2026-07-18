# ElectraHub GDPR Readiness Audit

**Assessment date:** 2026-07-17  
**Scope:** ElectraHub public web pages, iOS and Android driver applications, driver/admin portals, API gateway, backend services, Kubernetes configuration, observability configuration, simulator, notifications, Sparky AI support, and the current repository evidence.  
**Assessment type:** Technical and operational readiness audit. It is not a legal opinion, a certification, or a substitute for advice from a Netherlands/EU privacy lawyer.

## Decision

**ElectraHub must not claim that it is GDPR compliant today, and it is not ready for a public EU production launch handling real drivers and CPOs.**

The application has useful privacy and security foundations, but the audit found material gaps in accountability, data-subject rights, retention, processor governance, AI controls, tenant isolation proof, and sensitive-data handling. Several published statements are broader than the controls that can presently be demonstrated from source and configuration.

This is a remediation roadmap, not a request to stop the demo environment. The demo must be clearly labeled as such, must not use real customer/driver data, and must be separated from future production data.

## What GDPR Requires

GDPR requires more than an HTTPS site and a privacy page. The controller must be able to demonstrate lawful, fair, transparent, purpose-limited, data-minimized, accurate, time-limited, and secure processing. See [GDPR Article 5](https://eur-lex.europa.eu/eli/reg/2016/679/oj).

For a Netherlands launch, the organization must also be able to show its processing record, processor arrangements, security measures, incident process, and data-subject rights workflow. The Dutch regulator explains that an ongoing customer database normally requires a written processing register even for a small organization. See the [Autoriteit Persoonsgegevens GDPR guide](https://www.autoriteitpersoonsgegevens.nl/uploads/imported/handleiding_avg.pdf).

The key sources used for this review are:

- [Regulation (EU) 2016/679 - GDPR](https://eur-lex.europa.eu/eli/reg/2016/679/oj), especially Articles 5, 12-22, 28, 30, 32-35, and 44-49.
- [European Commission: information that must be provided to individuals](https://commission.europa.eu/law/law-topic/data-protection/information-business-and-organisations/principles-gdpr/what-information-must-be-given-individuals-whose-data-collected_en).
- [European Commission: personal-data breach response](https://commission.europa.eu/law/law-topic/data-protection/information-business-and-organisations/obligations/what-data-breach-and-what-do-we-have-do-case-data-breach_en).
- [Autoriteit Persoonsgegevens: privacy-law framework](https://autoriteitpersoonsgegevens.nl/nl/over-privacy/wetten).

## Scope and Limitations

### Reviewed

- Public privacy notice and terms pages.
- Source/configuration for `api-gateway`, `auth-service`, `user-service`, `session-service`, `payment-service`, `billing-service`, `subscription-service`, `notification-service`, `ai-support-service`, `ocpp-service`, `ocpi-simulator`, `driver-portal-ios`, `driver-portal-android`, driver web portal, admin portal, and platform charts.
- Evidence of data flows to PostgreSQL, Redis, Kafka/RabbitMQ, Elasticsearch, Splunk, Firebase, the simulator, Ollama, and optional OpenAI support.
- Authentication, notification device registration, user deletion, AI streaming, logging, and service-to-service access patterns.

### Not Proven by This Review

The following must be verified separately. Their absence from the reviewed source does **not** prove they do not exist in infrastructure or contracts.

- Legal entity registration, controller address, DPO appointment/assessment, and EU representative assessment.
- Cloud/provider contracts, data-processing agreements (DPAs), subprocessor terms, Standard Contractual Clauses (SCCs), transfer impact assessments (TIAs), and data-residency commitments.
- Production database/storage encryption, backup encryption, backup deletion, restore testing, operational access logs, and disaster recovery evidence.
- Payment-card scope and PCI DSS evidence. Do not assume masked application fields prove that no PAN, CVV, or payment data enters another system.
- Live production gateway behavior that strips/replaces trusted identity headers and prevents direct service access.
- Actual production network exposure and Kubernetes RBAC policies.

## Executive Findings

| Area | Status | Conclusion |
|---|---|---|
| Privacy notice | Partial | A public notice exists, but it lacks controller identity, specific lawful bases, clear retention periods, transfer information, complaint route, and a processor role explanation per service. |
| Lawful basis and consent | Gap | Terms acceptance is versioned in parts of the platform, but it is not a legal basis for every purpose. Optional location, marketing, social login/cookies, AI, and notifications need purpose-specific handling. |
| Data-subject rights | Critical gap | A client calls an account-deletion endpoint, but no matching backend endpoint was found. Administrative deletion only deletes a user/address record, not cross-service data. No verified access/export/restriction/objection workflow exists. |
| Retention and deletion | Critical gap | The notice says records are kept according to operational schedules, but no central retention schedule, owner, or deletion/anonymization execution was found across all stores. |
| AI/Sparky | Critical gap | Raw chat content and raw screen context are stored before redaction. Chat state is not visibly bound to the authenticated user/tenant. Redaction is too narrow for charging/location data. |
| Tenant/data-level authorization | Critical gap | Gateway rules enforce route/role access, but current source does not prove server-side network/enterprise/location scoping across every data query and command. |
| Security | Partial, with high-risk gaps | iOS Keychain and identity-bound notification registration are good controls. However, simulator credentials in URLs, plaintext FCM token storage, local/session web token storage, unprotected Elasticsearch configuration, and absent network-policy evidence require remediation. |
| Processors and international transfers | Gap | Firebase, social login, observability tooling, AI providers, Cloudflare, maps, payment providers, and support tooling need a formal subprocessor/transfer inventory and contracts. |
| Breach readiness | Gap | No verified breach register, risk-assessment workflow, controller/processor notification procedure, or 72-hour response runbook was found. |
| DPIA and privacy by design | Gap | The combination of charging/location behavior, payments, notifications, AI support, and multi-tenant operations requires a documented DPIA screening. A formal DPIA is strongly indicated and needs legal confirmation before launch. |

## Verified Foundations

These are good starting points. They do not independently establish GDPR compliance.

| Control | Evidence | Status |
|---|---|---|
| Published privacy notice | `electra-hub-org-page/privacy.html` documents categories including account, location, charging, payment, device, AI support, and operational data. | Partial |
| Versioned terms acceptance | User service includes terms acceptance/version concepts; iOS/admin flows use terms gating. | Partial |
| iOS token protection | iOS uses Keychain-backed token handling. | Positive |
| Authenticated push-device binding | Notification service derives device registration from authenticated identity and deactivates a device previously associated with another user. | Positive |
| Push-device logout cleanup | iOS/Android have unregister flows on logout. | Positive |
| Operational-log retention | Reviewed Splunk chart retains indexes for seven days. | Positive but not a platform-wide retention policy |
| Firebase analytics setting | Reviewed iOS Firebase configuration disables Firebase Analytics. | Positive but must be verified per build/environment |
| Simulator/demo notice | The privacy page labels simulator/development data separately. | Positive but needs technical enforcement |

## Personal-Data Inventory

This is an initial record of processing activities (ROPA) input. It is not yet the completed ROPA required for launch.

| Processing activity | Personal data observed or expected | Systems/stores | Likely role to determine | Main privacy concern |
|---|---|---|---|---|
| Account, profile, and authentication | Name, email, phone, address, username, password hash, roles, verification state, terms acceptance | User service, auth service, PostgreSQL, browser/mobile tokens | ElectraHub controller for direct driver relationship; possibly processor for CPO-managed users | No end-to-end erasure/export and duplicated driver records |
| Charger discovery and preferences | Device/map location, selected station, favorite/recent chargers, country/region preference | iOS, Android, driver web, user service | Controller or processor depending on product contract | Location minimization, optional location permission, retention, and third-party map data |
| Charging operations | Station/location, charger, connector, OCPP identifier, session state, timestamps, meter values, energy, idle state, transaction references | Session service, OCPP service, Redis, PostgreSQL, Kafka/RabbitMQ, Elasticsearch, simulator | Often CPO controller and ElectraHub processor; direct-driver model must be decided | Detailed movement/behavioral history, distributed copies, tenant isolation |
| Billing, payment, and tax | Wallet balance, top-ups, masked card data, token/provider reference, receipt, tax/cost, payment method, subscription allocation | Payment, billing, subscription, session services, PostgreSQL, Elasticsearch, future PSP | Controller/processor and independent PSP roles must be documented | Financial retention versus erasure, PCI scope, payments transfer data |
| Notifications | FCM token, device/app data, notification content, delivery status, errors, preferences | Notification service, PostgreSQL, Firebase | Controller/processor depending on recipient relationship | Token secrecy, retention, Firebase processing and transfers |
| Sparky AI support | Free-text questions, charger/session/location IDs, arbitrary screen context attributes, diagnostics | AI support service memory, Ollama, optional OpenAI, logs | ElectraHub controller/processor depending on purpose | Raw context reaches storage/provider before adequate minimization; no visible tenant binding |
| Web project/contact inquiries | Name, email, phone, company, site type, message/brief, marketing consent, UTM parameters | Notification service, PostgreSQL, email/support handling | ElectraHub controller | Retention, consent record, unsubscribe, free-text PII |
| Admin/operator operations | Admin identity, role, scope, audit events, commands, charger configuration/certificates | User, station/charger/OCPP services, observability | ElectraHub processor for CPO data; controller for its own admins | Role route control is not proof of row-level scope control |
| Security and observability | IP address, request IDs, trace IDs, error content, raw emails in some logs, support messages, device details | Service logs, Splunk, Elasticsearch, Grafana/Prometheus | ElectraHub controller/processor by context | PII logging, search access, retention, incident response |

## GDPR Requirements Matrix

| Requirement | GDPR reference | Assessment | Required evidence before launch |
|---|---|---|---|
| Lawfulness, fairness, transparency, purpose limitation, minimization, storage limitation, accountability | Article 5 | Partial/gap | Data map; purpose-by-purpose legal basis; minimization design records; retention schedule; owner sign-off |
| Privacy information to people | Articles 12-14 | Gap | Corrected notice; controller contact/address; legal basis; rights; retention; recipients; transfers; complaint authority; automated decision explanation |
| Access, correction, deletion, restriction, portability, objection | Articles 15-21 | Critical gap | Verified request intake, identity verification, orchestration, deadlines, data export, deletion/anonymization record, legal hold behavior |
| Automated decisions/profiling | Article 22 where applicable | Unassessed | Legal analysis of low-balance stop, eligibility/subscription behavior, operational risk decisions, and AI outputs; user notice and human-review path where required |
| Privacy by design/default | Article 25 | Gap | Default-minimum context, privacy architecture review, design checklist and release gate |
| Processor contract and subprocessor controls | Article 28 | Gap | CPO DPA, subprocessor inventory, approval workflow, vendor DPAs, security/rights/breach clauses |
| Record of processing activities | Article 30 | Missing | Controller and processor ROPAs for every service/data store and transfer |
| Security of processing | Article 32 | Partial/high-risk gaps | Threat model, encryption proof, secrets inventory, network isolation, access reviews, secure logging tests, restore test |
| Breach handling | Articles 33-34 | Missing/unverified | Incident runbook, triage/classification, 72-hour timer, processor-to-controller SLA, notification templates, incident register/tabletop test |
| DPIA | Article 35 | Unassessed | DPIA screening and formal DPIA if screening indicates high risk; legal/privacy sign-off |
| International transfers | Articles 44-49 | Missing | Transfer map, hosting locations, SCC/TIA/adequacy evidence, current-vendor configuration control |

## Priority Findings and Remediation

### P0 - Block public EU launch or any GDPR-compliance claim

#### GDPR-01: Establish the accountable legal and contractual model

**Evidence**

- The privacy notice states that ElectraHub may act as controller or processor depending on the CPO, but it does not define the role per product flow.
- No controller legal name/address, DPO contact, or EU/EEA representative assessment is available in the reviewed public notice.
- No ROPA, CPO DPA, or subprocessor register was found.

**Risk**

The company cannot reliably state who determines purpose/means, which party responds to a driver rights request, who reports a breach, or which party approves subprocessors.

**Required remediation**

1. Register the operating legal entity and publish its legal name, address, privacy contact, and applicable DPO/representative details.
2. Create a responsibility matrix for every product model: direct ElectraHub driver, CPO-branded driver, admin user, simulator prospect, and website lead.
3. Create a controller/processor/joint-controller analysis reviewed by Dutch/EU privacy counsel.
4. Prepare CPO DPA templates, processor instructions, breach SLA, rights-assistance procedure, confidentiality terms, deletion/return terms, and subprocessor approval/notice process.
5. Create a maintained subprocessor register and an internal ROPA.

**Acceptance test**

- For each data subject and feature, the ROPA names the controller, processor, processing purpose, legal basis, stores, recipients, retention, transfer safeguard, and owner.
- A sample CPO DPA supports Article 28 duties, including rights assistance, breach notification, deletion/return, audit, and subprocessor management.

#### GDPR-02: Replace the generic privacy notice with an accurate, purpose-specific notice

**Evidence**

- `privacy.html` includes broad data categories but lists only "Support team" as the privacy contact.
- It says data is kept "according to operational schedules" and financial records may be retained longer, without periods or a retention matrix.
- It does not clearly disclose the controller identity/address, purpose-specific legal basis, named categories of recipients/processors, transfers/safeguards, Dutch complaint route, or automated-decision information.

**Risk**

The notice does not give people the concrete information required by Articles 12-14. The European Commission specifically calls for controller/DPO identity, purpose, legal basis, retention, recipients, transfers, rights, complaint route, consent withdrawal, and automated-decision information.

**Required remediation**

1. Write a privacy notice that maps each purpose to a lawful basis and distinguishes required service processing from optional processing.
2. Publish legal entity/controller identity, physical or registered address, privacy email, DPO details if appointed, and Netherlands/EU complaint information.
3. Add a table of data categories, purposes, recipients/processors, international transfers and safeguards, retention period/criteria, and rights request route.
4. Disclose charging/location history, notifications, support/Sparky AI, future payment providers, social login, simulator data, observability/security logs, and any automated decisions.
5. Use short just-in-time notices for location, notification, AI support, social login, and marketing, not only a long policy page.

**Acceptance test**

- Privacy/legal counsel can trace every service in the ROPA to a precise notice section and the page passes an Article 13/14 checklist.

#### GDPR-03: Implement a real data-subject request and account-deletion lifecycle

**Evidence**

- iOS calls `POST /api/v1/users/{userId}/account-deletion`, but no matching server-side endpoint was found in the reviewed repositories.
- The verified administrative deletion endpoint is limited to `SYSTEM_ADMIN`, rejects self-deletion, and deletes the user/address record. It does not demonstrate deletion, anonymization, restriction, or export across session, billing, subscription, notification, AI, search, logging, backup, or audit stores.
- No structured export, restriction, objection, or DSAR case-management workflow was found.

**Risk**

ElectraHub cannot demonstrate Articles 15-21 rights. A user may be told that their account was deleted while charging, billing, notification, AI, or search records remain accessible. Some financial/tax records may legitimately remain, but that must be explained, protected, and scheduled rather than ignored.

**Required remediation**

1. Build an authenticated self-service privacy center and a secure assisted-request path.
2. Implement a DSAR orchestrator with immutable request ID, identity verification, scope, due date, owner, status, legal-hold decision, and audit record.
3. Define per-store action: delete, anonymize, pseudonymize, restrict, retain for legal obligation, or retain only aggregated data.
4. Revoke sessions, refresh tokens, API credentials, push devices, consent records as appropriate, and future notification delivery when deletion completes.
5. Generate a portable machine-readable export containing account, preferences, subscriptions, sessions/receipts, notifications, and support data where legally applicable.
6. Establish retention of deletion proof without retaining unnecessary source data.

**Acceptance test**

- A test driver with records in every store submits an access request and receives a complete export.
- The same driver submits deletion; test evidence proves deletion/anonymization/restriction in user, auth, session, billing, payment, subscription, notification, AI, Redis, Elasticsearch, export files, and backups at the defined lifecycle point.
- Required tax/financial records remain only under a documented legal basis, locked from ordinary product use, and are shown in the response explanation.

#### GDPR-04: Define and execute retention, deletion, and backup rules

**Evidence**

- The public notice gives general statements instead of retention periods.
- Splunk index retention is configured for seven days, but no single schedule covers PostgreSQL, Redis, Kafka/RabbitMQ, Elasticsearch, report files, notification content, support messages, AI memory, backups, or simulator/demo data.
- Billing report artifacts contain an expiry field, but a verified cleanup execution path was not established in this review.

**Risk**

Keeping data "because it might be useful" conflicts with storage limitation. Distributed retention without an owner causes copies to outlive their purpose.

**Required remediation**

1. Create a retention schedule approved by legal/finance/security for every data class and store.
2. Implement and monitor scheduled deletion/anonymization jobs with idempotency, metrics, failure alerts, and audit events.
3. Define immutable financial/tax/audit retention separately from product/session activity records.
4. Add backup retention, encryption, restricted access, restore, and deletion-expiry procedures.
5. Keep demo/simulator data segregated and regularly reset or use synthetic data only.

**Acceptance test**

- Automated tests create aged records across each store and prove expiration at the configured date.
- A quarterly report shows completed/pending purges, exception/legal holds, backup expiry, and owner approval.

#### GDPR-05: Redesign Sparky AI around data minimization and authenticated ownership

**Evidence**

- `ChatController` stores chat content and `ContextPayload` before redaction.
- `ChatThreadStore` keeps raw content/context in an in-memory map without a visible TTL, owner, tenant binding, or size limit.
- `ChatStreamController` verifies message/thread relationship but no visible user/tenant ownership for a thread.
- Current redaction covers email addresses, bearer tokens, and JWT-like strings only. It does not cover phone, name, precise location, account/session/charger identifiers, payment references, or arbitrary free text.
- `DiagnosticAnswerService` sends raw context/diagnostics into LLM prompt construction. Production chart values select local Ollama, while optional OpenAI support is implemented and can be enabled.

**Risk**

This creates a high-risk disclosure path for behavioral/location/financial context. A guessed or leaked thread/message ID could expose another person's support conversation if ownership is not enforced. Changing provider configuration could introduce a third-country transfer without privacy review.

**Required remediation**

1. Bind every conversation/message to authenticated subject ID and tenant/scope ID at ingress; enforce both on every read, stream, cancellation, feedback, and tool call.
2. Apply a strict allowlist and PII minimization before storage, diagnostics, logs, and model invocation. Do not accept arbitrary context attributes by default.
3. Use short TTLs, bounded storage, explicit purge, and no raw prompt retention unless a documented support purpose requires it.
4. Upgrade redaction, block payment/security/credential content, and test against phone, address, precise coordinates, account IDs, session IDs, card/provider references, and free-text secrets.
5. Make local AI inference hosting/security/retention explicit. Prevent switching to a remote provider unless privacy, procurement, legal basis, DPA, transfer safeguard, and model-use terms are approved.
6. Run a DPIA screening and likely a formal DPIA before public rollout. Provide AI-specific notice, user controls, human escalation, and an opt-out where the legal basis requires it.

**Acceptance test**

- Tenant A cannot stream, fetch, cancel, or influence any Tenant B chat by altering identifiers.
- Redaction/minimization tests prove prohibited fields cannot enter the store, logs, Ollama prompt, or optional provider request.
- A configuration policy blocks unapproved AI provider/region/model changes in CI/CD.

#### GDPR-06: Prove server-side multi-tenant data isolation

**Evidence**

- API gateway policies are route/role based. Source reviewed does not prove universal network/enterprise/location scope intersection in service queries and commands.
- Client-supplied filters and identifiers are present in several workflows. UI hiding or filters alone are not a trust boundary.
- The platform is intended to serve multiple CPOs and scoped location administrators.

**Risk**

One CPO or location administrator could see or operate another CPO's charging, driver, receipt, pricing, certificate, notification, or analytics data. This is both a security and confidentiality failure.

**Required remediation**

1. Create a central server-side access-scope model: system, CPO/network, enterprise, location, charger/connector, and driver self scope.
2. Resolve scope from authenticated identity and server-owned assignments. Never authorize based solely on a client-provided network, enterprise, location, or user ID.
3. Enforce scope in every repository/query/specification and command handler, including exports, background jobs, SSE, Kafka consumers, AI diagnostics, receipts, reports, and search.
4. Add database indexes that include ownership/scope keys so security does not create slow scans.
5. Add explicit deny-by-default behavior for unknown/unassigned scope and audit every cross-scope administration action.

**Acceptance test**

- Automated negative tests create two networks with identical identifiers where possible. Every list/detail/search/export/SSE/action endpoint must deny or exclude cross-network records.
- Database/query review proves scope predicates are server-supplied and query plans remain indexed at expected scale.

#### GDPR-07: Remove simulator security codes from URLs

**Evidence**

- Session service creates simulator URLs containing session ID and a four-digit `securityCode`.
- Mobile applications pass/open that URL.

**Risk**

The code is an authorization secret for a physical-session action. URLs can appear in browser history, copied links, screenshots, mobile diagnostics, web analytics, client logs, and support screenshots. A four-digit code is also weak as a primary authorization factor.

**Required remediation**

1. Replace URL security code with a short-lived, single-use, signed opaque action token bound to session, connector, authenticated user/device, and purpose.
2. Bootstrap over HTTPS, immediately remove sensitive URL state from browser history, and perform the action only through authenticated `POST` endpoints.
3. Add `Referrer-Policy`, redacted logging, no-cache headers where appropriate, expiry/revocation, rate limiting, and audit events.
4. Retain the master/admin access path only under strong admin authentication and audited authorization, never as a universal static secret.

**Acceptance test**

- Browser/network/log tests prove no usable credential or session secret appears in URL, referrer, logs, copied link, or analytics event.
- A token cannot be replayed, used for another session/connector/user, or used after expiration.

#### GDPR-08: Complete processor, subprocessor, and international-transfer governance

**Evidence**

- Code/config show or anticipate Firebase, Google/Facebook login, observability tools, Cloudflare/tunnel exposure, maps, local Ollama, optional OpenAI, and a future payment service provider.
- No reviewed source contained an approved subprocessor inventory, hosting region list, DPA/SCC/TIA record, or vendor-change gate.

**Risk**

ElectraHub cannot demonstrate Article 28 processor governance or Article 44 transfer controls, especially if AI/social/observability vendor configuration changes.

**Required remediation**

1. Inventory every vendor, SDK, cloud/hosting provider, support tool, observability platform, map provider, payment provider, and AI provider.
2. For each: list data categories, purposes, role, hosting region, transfer mechanism, DPA/SCC/DPA status, security contact, retention/deletion terms, and subprocessor chain.
3. Enforce procurement/legal approval before adding or switching a provider, region, SDK, or model.
4. Publish the appropriate processor/subprocessor disclosure and give CPO customers a change-notice process.

**Acceptance test**

- Release approval cannot proceed without a completed vendor record and legal/security/privacy review for every new external data recipient.

### P1 - Remediate before handling meaningful real-driver volume

#### GDPR-09: Stop personal data and secrets reaching operational logs

**Evidence**

- Session/driver code logs raw email values in operational log statements.
- Contact/project-brief workflows persist raw phone/message/brief content in notification payloads.
- Simulator URL secrets can be exposed by client-side logging/diagnostics.

**Required remediation**

1. Add a platform logging standard: no email, phone, address, raw message, authorization token, security code, certificate, full payment value, or provider secret in logs.
2. Replace identifiers with stable salted hashes or masked forms when correlation is necessary.
3. Add a centralized log-scrubber/appender and static/code-review checks.
4. Restrict Splunk/Elasticsearch access by role, document retention, and test ingestion samples.

**Acceptance test**

- Automated integration tests submit known sensitive values and prove none appear in application, gateway, OCPP, simulator, queue, or observability logs.

#### GDPR-10: Strengthen storage, network, and token security

**Evidence**

- Elasticsearch chart configuration has security disabled in the reviewed values.
- No Kubernetes `NetworkPolicy` resources were found in the reviewed platform tree.
- Service charts use internal plaintext HTTP/gRPC endpoints; mTLS/service-to-service TLS was not evidenced.
- Driver web/admin portal token handling uses web storage in reviewed source. Android FCM token is stored in ordinary `SharedPreferences`; Android auth token is memory-only in the reviewed class.
- Application-level encryption at rest for notification device tokens, database volumes, and backups was not evidenced.

**Required remediation**

1. Enable Elasticsearch authentication, TLS, least-privilege service users, and audit logging. Do not expose it publicly.
2. Implement default-deny Kubernetes network policies and explicit ingress/egress allowances.
3. Assess mTLS or equivalent authenticated/encrypted service-to-service transport.
4. Move browser auth handling away from persistent JavaScript-readable storage where feasible; apply strict CSP, XSS defenses, secure refresh-token design, and session revocation.
5. Use encrypted local storage for device tokens where appropriate and verify database, volume, and backup encryption/access controls.
6. Run threat modeling, penetration testing, secret scanning, dependency scanning, and recovery tests before launch.

**Acceptance test**

- External scan confirms Elasticsearch is not anonymously accessible.
- A pod compromise simulation cannot reach unrelated data stores/services.
- Backup restore and access review are evidenced without exposing personal data unnecessarily.

#### GDPR-11: Separate required processing, consent, preferences, and marketing

**Evidence**

- Terms acceptance exists in parts of the platform, but Android's reviewed terms button currently has no execution action.
- Project/contact forms collect a marketing-consent flag, UTM data, and free-text information, but no verified consent ledger/unsubscribe lifecycle was found.
- Facebook login configuration uses cookies when enabled. This requires region-specific assessment before optional cookies are placed.

**Required remediation**

1. Do not rely on terms acceptance as consent for optional processing.
2. Define legal basis and UX for account service, location, marketing, push notifications, analytics, social login, and AI support.
3. Record consent/preference version, purpose, timestamp, source, withdrawal, and evidence; implement withdrawal and suppression immediately.
4. Fix Android terms/privacy flow and provide consistent links in all apps and portals.
5. Add cookie/SDK consent controls where required before optional non-essential cookies/SDKs load.

**Acceptance test**

- With marketing/optional analytics disabled, no optional SDK/cookie/event is sent and no marketing message is delivered after withdrawal.

#### GDPR-12: Establish an incident and breach-response operating procedure

**Evidence**

- Security claims appear in the privacy notice, but no verified breach register, role-based response runbook, processor notification SLA, or tabletop exercise evidence was found.

**Required remediation**

1. Create an incident process for detection, containment, evidence preservation, risk assessment, controller notification, individual notification, and post-incident corrective action.
2. Set an internal escalation deadline well before the GDPR's 72-hour supervisory-authority deadline where notification is required.
3. Contractually require processors to notify ElectraHub promptly enough for it to meet controller duties.
4. Maintain a breach/near-miss register and run annual table-top exercises.

**Acceptance test**

- A simulated leaked push token/AI context event produces a complete incident record, legal-risk assessment, decision, and timed communication path.

#### GDPR-13: Assess automated decision transparency and human escalation

**Evidence**

- The product can stop charging based on low balance, apply subscription eligibility/quota logic, and generate AI support answers/operational explanations.

**Required remediation**

1. Inventory every automated decision that affects a driver or operator.
2. Have counsel assess Article 22 applicability and consumer/sector rules.
3. Explain the logic, relevant factors, consequences, and human-support route where required.
4. Provide appeal/correction handling for incorrect data causing a stop, charge, or entitlement decision.

**Acceptance test**

- A user can see why a session was stopped or benefit was not applied and can request review through a tracked support process.

### P2 - Complete for mature operating readiness

#### GDPR-14: Repair data quality and duplicate identity lifecycle

Driver identity/contact data exists in more than one service. Define a master source, propagation rules, correction event, conflict policy, and audit history so rectification reaches dependent data without rewriting lawful financial history.

#### GDPR-15: Add children/age and account-safety policy

The current notice says the service is not directed at children under 13. That is not sufficient for a Netherlands/EU product. Obtain legal advice on minimum age, parental authorization, account handling, and communication design.

#### GDPR-16: Introduce privacy engineering governance

Create a release checklist covering data classification, purpose/legal basis, scope authorization, retention, external recipients, logging, user rights, test evidence, threat model, and DPIA screening. Require privacy/security sign-off for material data-flow changes.

#### GDPR-17: Isolate demo/simulator data

Use synthetic or segregated demo accounts and station/session data. Prevent demo environments from sending real production data to analytics, support, AI, email, push, or public logs. Reset demo data on a defined schedule.

## Proposed 90-Day Program

| Timing | Outcome | Work |
|---|---|---|
| Days 0-14 | Stop unsafe claims and establish ownership | Appoint privacy owner; legal counsel intake; freeze unapproved external data recipients; create ROPA/subprocessor register; define controller/processor model; update launch gate; remove sensitive URL credentials from new flows; place AI feature behind an approved privacy gate. |
| Days 15-30 | Design auditable data lifecycle | Retention schedule; DSAR design; deletion/export data contracts; tenant-scope authorization architecture; incident response; processor/DPA templates; DPIA screening; privacy notice draft. |
| Days 31-60 | Build P0 controls | DSAR orchestration; cross-store retention jobs; tenant-scope enforcement; AI ownership/minimization/TTL; secure simulator action token; log-scrubbing; vendor configuration controls. |
| Days 61-75 | Harden infrastructure and product UX | Elasticsearch/network/TLS work; browser/mobile token hardening; consent/preferences/privacy center; automated-decision explanations; contact/marketing lifecycle. |
| Days 76-90 | Evidence and launch decision | Two-tenant penetration tests; DSAR end-to-end test; retention/backup restore test; incident tabletop; external security review; legal approval of notice/DPA/DPIA; management sign-off. |

## Privacy-by-Design Architecture Decisions

1. **Identity is authoritative server-side.** Scope derives from the authenticated principal and trusted assignments, never from a UI filter or caller-supplied tenant ID.
2. **Data stores have defined owners.** Every table/topic/cache/index/object has classification, owner, purpose, retention, deletion action, and backup rule.
3. **No sensitive values in URLs or logs.** Use short-lived opaque tokens, POST actions, structured logs, masking, and safe correlation IDs.
4. **AI receives the minimum useful context.** Prefer deterministic, scoped backend tools over sending broad raw context to a model. Model output is advisory and never treated as authorization.
5. **Financial history is separated from identity.** Keep statutory evidence only as long as required, restrict it, and use pseudonymous references after account deletion where lawful.
6. **Demo is a different data plane.** No real personal data, no production keys, no shared support/AI/analytics sink without explicit approval.
7. **Security evidence is testable.** Encryption, backups, access control, network policies, and vulnerability remediation must be demonstrable, not only asserted in a policy.

## Launch Gates

Do not enable public Dutch/EU real-driver onboarding until all gates below are approved by the accountable product/security/privacy owner and legal counsel:

- [ ] Controller/processor model, legal entity details, DPA templates, subprocessor register, and ROPA are complete.
- [ ] Privacy notice and just-in-time notices satisfy Articles 12-14 and match actual implementation.
- [ ] DSAR access/export/deletion/restriction process works across all stores and has retained evidence.
- [ ] Retention, backup expiry, legal-hold, and deletion/anonymization schedules are operational.
- [ ] Server-side scope authorization has passed two-tenant negative testing across data, streaming, search, export, and commands.
- [ ] Sparky AI has subject/tenant binding, minimization/redaction before storage/egress, TTL, provider governance, and DPIA approval.
- [ ] No actionable secret/session credential appears in any URL, log, or telemetry payload.
- [ ] Processor/transfer documentation and contractual safeguards are approved for every external recipient.
- [ ] Security hardening evidence is complete: authentication/authorization, encrypted storage/backups where appropriate, Elasticsearch protection, network policy, vulnerability management, and penetration testing.
- [ ] Breach runbook/tabletop and 72-hour response readiness are completed.
- [ ] Consent/preferences, marketing withdrawal, social/cookie controls, and privacy-center UX are tested on iOS, Android, driver web, and admin portal.

## Immediate Implementation Backlog

| Priority | Work item | Primary owners | Dependencies |
|---|---|---|---|
| P0 | Create legal/processing responsibility matrix and ROPA | Founder, privacy counsel, product | Legal entity/business model decision |
| P0 | Build DSAR/account deletion/export orchestrator | User, auth, session, payment, billing, subscription, notification, AI teams | Retention/legal hold design |
| P0 | Add server-side tenant scope policy library and test suite | API gateway, all domain services | CPO hierarchy data model |
| P0 | Redesign Sparky chat ownership/minimization/TTL | AI support, gateway, mobile/web clients | DPIA/vendor assessment |
| P0 | Replace URL security code with signed one-time action token | Session service, simulator, iOS, Android | Auth/action model |
| P0 | Create processor/transfer inventory and contract workflow | Founder, legal, security | Vendor discovery |
| P1 | Implement retention schedule and purge jobs | Data/service owners, platform | ROPA and legal retention rules |
| P1 | Create PII-safe logging framework and scrub existing logs | Platform, all services | Observability access review |
| P1 | Harden Elasticsearch, network boundaries, and token handling | Platform, security, portals | Infra design |
| P1 | Implement consent/preferences and contact marketing lifecycle | User, notification, web, mobile | Legal-basis decision |
| P1 | Implement incident/breach runbook and tabletop | Security, platform, legal | Controller/processor model |

## Evidence References

The following implementation evidence informed this audit:

- `C:\development\project\electra-hub-org-page\privacy.html`
- `C:\development\project\user-service\user-service-app\src\main\java\com\electrahub\user\service\UserManagementService.java`
- `C:\development\project\driver-portal-ios\Services\AppServices.swift`
- `C:\development\project\ai-support-service\src\main\java\...\ChatController.java`
- `C:\development\project\ai-support-service\src\main\java\...\ChatThreadStore.java`
- `C:\development\project\ai-support-service\src\main\java\...\ChatStreamController.java`
- `C:\development\project\ai-support-service\src\main\java\...\PiiRedactor.java`
- `C:\development\project\session-service\src\main\java\...\SimulatorUrlBuilder.java`
- `C:\development\project\notification-service\src\main\java\...\NotificationOrchestrator.java`
- `C:\development\project\driver-portal-android\app\src\main\java\com\electrahub\driverportal\push\ElectraHubMessagingService.kt`
- `C:\development\project\k8s-platform\infrastructure\elasticsearch\values.yaml`
- `C:\development\project\k8s-platform\infrastructure\splunk\values.yaml`
- `C:\development\project\k8s-platform\charts\config\services\ai-support-service\us\values\prod-values.yaml`

## Next Step

Hold a 90-minute privacy architecture workshop with product, platform, security, and legal counsel. The output must be: (1) controller/processor decision per product model, (2) approved ROPA and vendor inventory owners, (3) P0 implementation sequencing, and (4) a written decision on whether a formal DPIA is required before live EU operation.
