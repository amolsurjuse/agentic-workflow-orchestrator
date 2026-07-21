# Regional Payment And Settlement Plan

## Request

Define a safe, region-aware payment and settlement strategy for ElectraHub in
the United States, European Union, India, and the wider Asia-Pacific region.
The strategy must answer four questions:

1. Which payment gateway and settlement models are appropriate in each region?
2. Which free or no-funds sandbox environments can validate the end-to-end
   behaviour before a commercial PSP contract exists?
3. Can the current payment implementation integrate with a gateway in any
   country?
4. What architecture, operational, commercial, and regulatory work is required
   before ElectraHub processes real driver money?

This is an implementation plan, not legal, tax, payments, or licensing advice.
Regional legal and PSP onboarding decisions require qualified counsel and the
selected PSP's written confirmation before live payments are enabled.

## Executive Decision

ElectraHub must initially operate as a **software platform and payment
orchestrator**, not as an unlicensed payment institution, wallet issuer,
acquirer, or merchant-of-record that holds funds for multiple CPOs.

For the first live pilot:

- The CPO is the merchant of record and contracts directly with the selected
  licensed PSP/acquirer.
- Driver funds settle to the CPO's PSP account.
- ElectraHub charges a separate platform or support fee to the CPO under the
  commercial agreement.
- ElectraHub keeps an immutable operational payment ledger and consumes signed
  PSP webhooks, but does not custody, pool, or manually redistribute driver
  funds.

This is the lowest-complexity and lowest-regulatory-exposure entry path. A
platform settlement model, where ElectraHub onboards sub-merchants and routes
payouts, is a later capability and must use the PSP's licensed marketplace or
platform product.

## Current-State Assessment

### What Exists

The service boundary is useful:

```text
Driver app / portal
  -> API gateway
  -> session-service
  -> payment-service
  -> local payment and wallet records
```

`session-service` requests a start authorization and later requests settlement
from `payment-service`. The service already records wallet holds, local session
authorizations, session settlement data, cards, auto-top-up preferences, and
receipt-facing payment state. This is a viable domain boundary for a real PSP
integration.

The payment-service design draft at
`C:\development\project\payment-service\docs\payment-gateway-design.md`
also proposes an adapter SPI, sandbox profiles, tokenization, authorization,
capture, webhooks, reconciliation, and a public application transaction ID.
That document is a useful target architecture, not an implemented gateway
layer.

### Production Blockers

The current implementation is **not capable of safely settling live card
payments with any PSP or in any country**. It is a local bookkeeping and demo
implementation. The following gaps are blocking:

| Area | Current behaviour | Required change |
| --- | --- | --- |
| Card data | `AddCardRequest` accepts a raw card number; card-present requests accept PAN and CVV. | Remove all PAN/CVV application APIs. Use PSP-hosted fields, hosted checkout, a mobile PSP SDK, or certified terminal SDKs. Store PSP tokens only. |
| Card authorization | A stored local card can satisfy a start authorization without a PSP request. | Create a provider authorization or payment intent, including 3DS/SCA where required. |
| Capture and settlement | `settleSession` performs local bookkeeping; card-present has a dummy processor. | Capture or settle against the PSP, then update the internal ledger only from the canonical PSP result/webhook. |
| Wallet top-up | Local balance changes do not charge a real funding source. | Treat top-up as a tokenized PSP sale/payment intent and credit wallet only after confirmed success. |
| Terminal/card-present | The simulator and service accept raw card-like data. | Integrate certified PSP/acquirer terminals. The simulator may use synthetic sandbox tokens only. |
| Webhooks | No provider-specific signed webhook ingestion or replay protection. | Verify provider signature, persist a deduplicated event, process asynchronously, and reconcile out-of-order events. |
| Reconciliation and payouts | No PSP settlement-report ingestion, payout records, or discrepancy workflow. | Build transaction-to-settlement-to-payout reconciliation and an operations exception queue. |
| Merchant routing | No CPO legal-entity, country, currency, or gateway-capability routing. | Add merchant accounts, routing rules, gateway capabilities, and immutable per-intent gateway selection. |
| Currency | Amounts use a generic decimal model without an ISO minor-unit policy or FX policy. | Use ISO currency codes and native minor units; no implicit FX or cross-currency wallet conversion. |
| Security and operations | No gateway credential vaulting, webhook key rotation, provider circuit breaker, or PSP SLOs. | Add secret references, audit logs, least privilege, retry/recovery queues, metrics, alerts, and runbooks. |

The existing raw-card paths must be removed or disabled before any production
card traffic. They unnecessarily expand PCI DSS exposure and are incompatible
with the target hosted-tokenization model.

## Operating Models

### Model A: CPO Direct Merchant - Recommended First Pilot

```text
Driver -> CPO PSP merchant account -> CPO bank account
                 ^
                 | token, status, settlement report, webhook
           ElectraHub platform
```

- Each CPO owns its merchant account with the PSP.
- ElectraHub configures the CPO's API credentials or OAuth connection as a
  secret reference, not a value visible to ordinary administrators.
- The CPO receives driver payment settlement directly from the PSP.
- ElectraHub provides charging orchestration, a payment adapter, reports, and
  a separate SaaS/support invoice.
- The CPO owns refunds and chargebacks commercially, while ElectraHub provides
  operational tooling and auditable evidence.

This is the recommended first paid pilot in the Netherlands, US, India, and any
new country because it avoids ElectraHub holding funds on behalf of multiple
merchants.

### Model B: PSP Marketplace Or Platform Settlement - Later

```text
Driver -> Platform PSP account -> connected CPO balance -> CPO payout
```

- ElectraHub onboards CPOs as connected/linked accounts using the PSP's KYC
  flow.
- ElectraHub controls split payments, application fees, settlement timing, and
  potentially chargeback liability depending on the PSP product and contract.
- This supports a single commercial checkout and automated CPO payouts.
- It requires a country-by-country legal, tax, KYC, reserve, dispute, and
  liability assessment before live launch.

Use only a PSP's licensed platform product, such as Stripe Connect, Adyen
Platforms, Mollie Connect Marketplace/Platform, or Razorpay Route. Do not
create an internal payout ledger that moves real money outside an approved PSP
flow.

### Model C: ElectraHub Merchant Of Record Or Stored-Value Wallet - Not First

- ElectraHub collects driver funds in its own name and pays CPOs later.
- A multi-CPO stored wallet, pooled driver balance, foreign exchange, or manual
  payout model can create payment-institution, money-transmitter,
  e-money/stored-value, safeguarding, AML, tax, and consumer-law obligations.
- This is not appropriate for the first live release. It can only be considered
  after legal counsel, PSP approval, a funded compliance program, and a
  deliberately designed regulated operating model.

## Regional Gateway Strategy

The gateway is selected per **CPO merchant account, charging country,
presentment currency, payment method, and channel**. A global UI setting is not
enough. A payment intent must remain pinned to one gateway from authorization
through capture, refund, dispute, and reconciliation.

| Region | First live model | Candidate PSPs | Sandbox / no-funds validation | Required commercial gate |
| --- | --- | --- | --- | --- |
| United States | CPO direct merchant | Stripe, Adyen for enterprise or terminal-led deployments | Stripe Sandbox; Adyen test account | CPO merchant onboarding, US acquiring coverage, card-present terminal decision, state/legal review if ElectraHub receives or transmits funds |
| EU/EEA, Netherlands first | CPO direct merchant | Mollie, Stripe; Adyen later for larger CPOs or unified online/in-person rollout | Mollie Test mode, Stripe Sandbox, Adyen test account | CPO onboarding, PSD2/SCA-ready checkout, DNB/legal assessment if ElectraHub provides payment services or holds funds |
| India | CPO direct merchant through an India-ready PSP | Razorpay, Cashfree; validate provider and entity eligibility before commitment | Razorpay Test mode, RazorpayX Test mode for payout simulation, Cashfree Sandbox | India legal entity/merchant eligibility, RBI/PSP confirmation, local payment-method and data-residency assessment |
| Singapore, Malaysia, Thailand, Indonesia, Philippines, Vietnam, Hong Kong | Country-specific CPO direct merchant | 2C2P; Stripe/Adyen only where merchant and product support are confirmed | 2C2P Sandbox, PSP-specific sandbox | Country support, local entity/acquiring, local payment methods, tax, and payout confirmation per market |
| Japan, South Korea, Mainland China, other APAC markets | Defer until country design is complete | Country-specific acquirer/PSP chosen after discovery | PSP-specific sandbox only | Local methods, local entity, consumer, data, and settlement rules make these separate market launches, not a generic "Asia" switch |

### United States

**Recommended first adapter:** Stripe for a small CPO pilot, using a direct CPO
merchant account and Stripe's sandbox first. Stripe Connect is a strong later
option when ElectraHub needs connected-account onboarding and application fees.
Adyen is a suitable later candidate where a CPO needs one provider for online
and in-person terminal payments, subject to its commercial onboarding.

**Settlement approach:** authorize a controlled reserve at session start;
capture the final amount at completion; void unused authorization; process
refunds and disputes through the same PSP. Do not assume incremental
authorization is supported for every card, card network, or PSP product.

**Compliance boundary:** if ElectraHub only supplies software and the CPO/PSP
move funds, the model is materially simpler. If ElectraHub accepts and
transmits money as a business, US MSB/money-transmitter analysis becomes
necessary. FinCEN says money transmission can make a business an MSB regardless
of transaction volume, and state requirements can also apply.

### EU/EEA And Netherlands

**Recommended first adapter choice:**

- Choose **Mollie** if the first Dutch CPO needs local Netherlands and European
  payment methods and will be the direct merchant.
- Choose **Stripe** if the first commercial goal is a shared US/EU card and
  mobile payment integration with a common adapter contract.
- Treat **Adyen** as a later option for an enterprise CPO or a deliberate
  online-plus-terminal rollout. That is a product-fit recommendation, not a
  statement about provider quality or availability.

For a multi-CPO marketplace, Mollie Connect and Stripe Connect both provide
connected-account approaches; their contractual roles, payout models, and
liability differ. ElectraHub must choose one model per launch, not merge the
two semantics behind a generic "settle" button.

**SCA and 3DS:** cardholder authentication must be driven by the provider's
hosted/mobile flow. The app must tolerate a pending challenge, redirect,
browser-return, webhook delay, and issuer decline without creating a charging
session until payment authorization is definitive.

**Compliance boundary:** DNB states that a platform that itself provides
payment services may require a licence, while a platform using a third-party
licensed PSP may not be subject to the same requirement. That distinction must
be reviewed against the actual commercial flow before the Netherlands launch.

### India

**Recommended first adapter:** use Razorpay or Cashfree only after their
merchant/onboarding team confirms that the intended CPO, legal entity,
settlement flow, card-present requirements, and cross-border aspects are
supported. Razorpay Route is a candidate for later linked-account/split-payment
work; it is not a substitute for design or regulatory approval.

**Payment methods:** the adapter needs a capability model for UPI, cards,
netbanking, wallets, refunds, webhooks, and recurring/mandate flows where the
provider supports them. The driver UI must show only methods valid for the CPO,
country, currency, and transaction type.

**Compliance boundary:** RBI payment-aggregator rules and cross-border
requirements are material. ElectraHub must not present itself as an Indian
payment aggregator or route CPO funds through its own wallet unless the
necessary authorization and provider model have been confirmed.

### Wider Asia-Pacific

There is no safe single "Asia payment gateway" design. Regional differences in
merchant eligibility, local cards, wallets, QR methods, currency, data,
settlement, and consumer rules require an explicit launch record for each
country.

2C2P is a practical discovery candidate for Southeast Asia because it provides
documented sandbox environments across several APAC markets. Every country is
still gated by a signed PSP agreement, merchant eligibility, supported payment
methods, and reconciliation/payout confirmation.

## Sandbox And Test Strategy

Sandbox access verifies integration behaviour. It does **not** validate
commercial pricing, merchant underwriting, funds movement, payout timing,
chargeback liability, local licensing, or production acquiring approval.

| Environment | What it proves | Cost/funds expectation | Use in ElectraHub |
| --- | --- | --- | --- |
| Internal mock gateway | Deterministic authorize/capture/void/refund/webhook/retry state machine | Free, no external funds | Required baseline for unit, contract, JMeter, and regression tests |
| Stripe Sandbox | Test cards, 3DS, failures, refunds, disputes, and webhook lifecycle | Isolated test environment, no funds move | Initial US/EU card-not-present adapter contract |
| Mollie Test mode | Hosted checkout/payment states and test webhooks | Simulated payments, no real funds | Netherlands and EU direct-CPO integration validation |
| Adyen test account | Platform split/payment/payout workflow test | Test environment; commercial test-account access must be obtained | Enterprise and terminal-capability discovery |
| Razorpay Test mode | Indian test cards, UPI, wallets, payment-state behavior | No real money; separate test/live credentials | India acceptance integration |
| RazorpayX Test mode | Beneficiary/contact/fund-account/payout event behavior | Dummy balance, no real payout | India future settlement/payout workflow only |
| Cashfree Sandbox | India payment-method callbacks and failure handling | Sandbox, no real funds | Secondary India adapter evaluation |
| 2C2P Sandbox | Hosted payment/direct API test behavior in supported APAC markets | Sandbox, no real payment | Southeast Asia country discovery |

### Sandbox Rules

1. Use fake provider credentials stored only in the secret manager.
2. Tag every sandbox transaction with `environment=SANDBOX` and reject any
   production callback at a sandbox endpoint.
3. Never send real PAN, CVV, customer PII, or production account IDs to a
   sandbox.
4. Do not load test external PSP sandboxes. Use the internal mock gateway for
   high-volume JMeter regression and a small, provider-approved contract test
   suite for each external sandbox.
5. Replay signed webhook fixtures through the same code path as live webhooks.
6. Test successful, declined, 3DS-challenge, timeout, duplicate webhook,
   partial-capture, void, refund, dispute, and reconciliation-mismatch paths.

## Target Architecture

### Boundary

```text
Mobile app / Driver Portal / HMI terminal
  -> PSP hosted component, mobile SDK, or certified terminal
  -> PSP token or terminal payment reference
  -> API gateway
  -> session-service
  -> payment-service payment intent
  -> gateway routing engine
  -> selected PSP adapter
  -> provider API / webhook / settlement report
```

The driver interface never posts PAN or CVV to ElectraHub. It obtains a
provider token or terminal reference. `payment-service` receives only the
token/reference, a payment-method type, an internal payment-method ID, and
non-sensitive display data such as brand and last four digits.

### Canonical Domain Records

| Record | Purpose |
| --- | --- |
| `merchant_account` | CPO legal entity, PSP connected-account/merchant ID, country, settlement currency, onboarding state, capability flags |
| `gateway_configuration` | Secret reference, environment, provider, supported countries/currencies/methods, enabled state |
| `routing_rule` | Ordered match on CPO, country, currency, channel, method, amount, and capability |
| `payment_intent` | One charging or top-up payment purpose; stable internal and public ElectraHub transaction IDs |
| `payment_attempt` | Immutable provider operation: authorize, capture, void, refund, sale, or inquiry |
| `payment_method` | Token reference and safe display metadata only; never PAN/CVV |
| `authorization_hold` | Provider hold/reference, authorized amount, expiry, extension policy, and release state |
| `ledger_entry` | Immutable, balanced operational financial event in minor units |
| `settlement_batch` | Provider settlement report/import and expected vs actual totals |
| `payout` | CPO payout reference/status where the PSP/platform model exposes one |
| `webhook_event` | Provider event ID, signature verification result, payload hash, receipt time, processing state |
| `reconciliation_exception` | Unmatched, duplicated, late, amount-mismatched, or manually reviewed transaction |

All money is stored as `amount_minor` plus ISO 4217 currency. Decimal display
is calculated from currency metadata. The system must handle currencies whose
minor-unit scale differs from USD/EUR; it must not assume two decimal places.

### Gateway Adapter Contract

The adapter interface should support only capabilities the selected provider
actually guarantees:

```text
createPaymentMethodSession()    hosted field, SDK, redirect, or terminal setup
authorize()                     reserve funds / payment intent confirmation
incrementAuthorization()        only where the provider and card support it
capture()
voidAuthorization()
refund()
getPaymentStatus()
verifyAndParseWebhook()
retrieveSettlementReport()
retrievePayoutStatus()
```

The adapter reports a capability set. The routing engine rejects an unsupported
operation before any charging session starts. It must not transparently
fail-over an in-flight authorization to another PSP, because capture/refund and
chargeback ownership remain with the original provider and merchant account.

### Routing Rules

Route by the following ordered keys:

1. Environment: sandbox or production.
2. CPO legal entity and merchant/connected account.
3. Charging location country and presentment currency.
4. Payment channel: app/web card-not-present, Plug and Charge, RFID-linked
   account, physical terminal/card-present, or wallet top-up.
5. Payment method and required capabilities: 3DS/SCA, UPI, terminal,
   incremental authorization, refund, split/payout, or local method.
6. Regional fallback policy, only before payment authorization exists.

The selected gateway ID, merchant account ID, public ElectraHub transaction ID,
and provider transaction IDs are immutable on the payment intent. UIs see only
the ElectraHub public ID and safe card display metadata.

## Charging Authorization, Capture, And Settlement Flow

```text
1. Driver selects a connector and payment method.
2. App/HMI tokenizes through the PSP or obtains a certified-terminal reference.
3. session-service requests a payment authorization from payment-service.
4. payment-service resolves CPO, location country, currency, and gateway route.
5. The PSP authorizes the reserve or returns a required authentication action.
6. Only a confirmed authorization permits the OCPP start command.
7. During charging, session-service calculates cost using server-side pricing.
8. If cost approaches the authorized amount, apply the configured provider-safe
   action: incremental authorization where supported, controlled stop, or a
   second customer-approved authorization. Never silently exceed the hold.
9. At completion/unplug, session-service sends final server-side rated amounts.
10. payment-service captures the final eligible amount or releases unused hold.
11. Signed webhook and/or provider inquiry confirms terminal state.
12. Receipt shows payment state and the public ElectraHub transaction ID, not a
    PSP/acquirer reference.
13. Daily reconciliation matches ledger entries to provider settlement and CPO
    payout records. Exceptions become operator work items.
```

The existing charging and idle-fee caps remain server-side pricing rules. The
payment authorization policy must reserve enough to cover the configured
session cap, applicable fees and taxes, and the bounded idle-fee cap without
allowing a wallet or card balance to become an unbounded exposure.

## Wallet Policy

The current local wallet must not be advertised as a cross-country stored-value
instrument until legal and PSP design is complete.

Initial policy:

- A wallet belongs to one driver and one settlement currency.
- No implicit currency conversion.
- No cross-border wallet funding or transfers.
- Card-funded top-up credits the wallet only after PSP confirmation.
- Charging eligibility reserves local wallet funds atomically and releases or
  settles them from the server-rated final amount.
- A user may pay a charging location in a different currency with a PSP card
  flow if the CPO/PSP supports that presentment currency; issuer FX is disclosed
  by the issuer/PSP and is not silently invented by ElectraHub.
- Multi-currency wallet, FX conversion, and CPO payout netting are future work
  requiring a separate regulated-product decision.

## PCI, Security, And Privacy Requirements

1. Remove raw PAN/CVV DTO fields and log redaction gaps before production PSP
   work begins.
2. Use provider-hosted tokenization, mobile SDKs, hosted checkout, or certified
   payment terminals.
3. Store gateway secrets in Kubernetes external secrets or an approved vault;
   database records contain secret references, never plaintext keys.
4. Verify webhook signatures with provider key rotation, event-ID dedupe,
   payload hashing, timestamp validation, and durable retry handling.
5. Use idempotency keys for each provider mutation and retain provider response
   references for audit/recovery.
6. Separate internal service authentication from end-user JWTs. Session service
   can invoke payment-service internal endpoints through a workload identity;
   an app cannot call settlement or card-present endpoints directly.
7. Restrict payment operations and settlement data with the existing data-level
   RBAC model. CPO users see only their CPO's merchant, transactions, reports,
   and payouts.
8. Minimize personal data in provider metadata and define retention/deletion
   rules for payment audit records, receipts, and webhooks.
9. Add SAST/dependency/secret scans and a CI rule that blocks PAN/CVV patterns
   in DTOs, logs, fixtures, and error responses.

## Settlement And Operations

### Required Lifecycle States

```text
CREATED
-> AWAITING_CUSTOMER_ACTION
-> AUTHORIZED
-> CHARGING
-> CAPTURE_PENDING
-> CAPTURED
-> SETTLEMENT_PENDING
-> SETTLED

Terminal alternatives:
DECLINED | AUTHORIZATION_EXPIRED | VOIDED | REFUNDED | PARTIALLY_REFUNDED |
DISPUTED | FAILED | RECONCILIATION_EXCEPTION
```

The receipt has distinct states:

- `PROVISIONAL`: charging has ended but PSP capture/settlement is not confirmed.
- `PAID`: the PSP-confirmed payment is captured or settled according to the
  selected provider model.
- `PAYMENT_REVIEW`: an asynchronous discrepancy requires intervention.

### Daily Reconciliation

1. Import provider transactions, fees, settlement batches, and payout records.
2. Match provider transaction IDs against immutable payment attempts.
3. Compare amounts, currency, event state, fees, settlement date, merchant, and
   payout recipient.
4. Auto-close exact matches; create a durable exception for every mismatch.
5. Provide an admin queue with owner, reason, evidence, retry/inquiry action,
   resolution note, and audit trail.
6. Never alter a paid ledger entry to conceal a mismatch. Post compensating
   entries for refunds, reversals, and corrections.

### Operational Metrics And Alerts

- PSP authorize/capture latency, success, decline, timeout, and retry rates by
  provider, country, CPO, currency, and payment method.
- 3DS/SCA challenge and completion rate.
- Authorization expiry and capture-after-expiry count.
- Webhook signature failures, duplicate events, processing lag, and dead-letter
  queue depth.
- Reconciliation match rate, unsettled amount, exception age, payout delay, and
  refund/chargeback count.
- A circuit breaker for provider failures. A provider outage may block new
  sessions for its payment path; it must never cause duplicate charges.

## Implementation Plan

### Phase 0: Commercial And Legal Decisions

1. Select Model A for the first paid pilot.
2. Select one first live geography and one first PSP adapter. For a Netherlands
   CPO, evaluate Mollie and Stripe with their sales/onboarding teams against
   real CPO legal-entity and payment-method needs.
3. Confirm merchant-of-record, refund, dispute, tax, receipt, payout, and
   support obligations in the CPO agreement.
4. Obtain legal advice before holding funds, enabling a wallet across countries,
   routing CPO payouts, or operating in India/US under a platform model.
5. Define a country launch record containing legal entity, PSP approval,
   currencies, methods, fee model, settlement schedule, refund/chargeback
   policy, data residency, and support runbook.

**Exit gate:** a signed pilot/CPO arrangement and written PSP confirmation of
the proposed flow. No production money before this gate.

### Phase 1: Payment Domain And Security Refactor

1. Replace raw-card DTOs and the dummy card-present flow with token/reference
   inputs.
2. Add canonical payment-intent, attempt, authorization-hold, ledger,
   merchant-account, gateway-config, routing-rule, webhook-event, settlement,
   payout, and reconciliation tables.
3. Migrate existing local transaction records into a compatibility view; do not
   destroy historic receipts.
4. Add a `PaymentGateway` SPI and an explicit provider capability model.
5. Introduce a secret-reference configuration model and workload authentication
   for internal payment operations.
6. Change receipt APIs to expose only public ElectraHub transaction IDs and
   safe payment display data.

**Exit gate:** no PAN/CVV crosses the ElectraHub API/database/log boundary;
wallet and existing receipt regression tests pass.

### Phase 2: Internal Mock Gateway And Regression Coverage

1. Implement the internal mock adapter with deterministic authorize, decline,
   timeout, 3DS action, capture, partial capture, void, refund, duplicate
   webhook, late webhook, and settlement-file outcomes.
2. Add contract tests shared by every PSP adapter.
3. Add JMeter scenarios for payment authorization, session start, metering,
   stop, capture, webhook delivery, and receipt retrieval using the mock only.
4. Add idempotency, concurrency, retry, and out-of-order event tests.

**Exit gate:** complete payment-state regression passes at planned concurrency
without external PSP traffic.

### Phase 3: First PSP Sandbox Adapter

1. Implement one adapter only: Stripe Sandbox or Mollie Test mode, based on
   Phase 0 selection.
2. Build provider-hosted/mobile tokenization and return/action handling for
   3DS/SCA.
3. Build signed webhook ingestion, provider inquiry recovery, and sandbox
   reconciliation fixture import.
4. Add CPO merchant configuration, capability checks, and country/currency
   routing.
5. Validate card decline, user cancellation, 3DS, provider outage, duplicate
   webhook, partial capture, void, refund, and receipt state.

**Exit gate:** provider sandbox integration is certified by automated contract
tests and manual test evidence; no raw card paths remain reachable.

### Phase 4: First Live CPO Pilot

1. Create one CPO merchant account and onboard it through the PSP's approved
   process.
2. Configure production credentials through the vault and restrict them to that
   CPO/country/currency.
3. Enable a tightly scoped feature flag for selected test drivers and chargers.
4. Run a low-volume operational pilot with daily reconciliation and an on-call
   rollback plan.
5. Expand only after payment success, settlement match, and support criteria
   meet the agreed thresholds.

**Exit gate:** a defined period of reconciled production transactions with no
unresolved money discrepancies or critical security issues.

### Phase 5: Regional Expansion

1. Reuse the canonical model and adapter contract, not gateway-specific UI or
   session logic.
2. Add US, India, and each APAC country only after a country launch record is
   approved.
3. Implement a provider adapter and sandbox tests per country/payment-method
   combination.
4. Add platform/connected-account settlement only after a separate legal,
   commercial, risk, and operational approval.

## Validation Matrix

| Scenario | Expected result |
| --- | --- |
| Wallet session with sufficient funds | Atomic local reserve, server-rated final settlement, one receipt |
| Wallet session with insufficient funds | Start denied before OCPP start; no negative wallet |
| Card session requiring 3DS/SCA | No OCPP start until the provider confirms authorization |
| Card authorization decline | No OCPP start, no local fake authorization, clear user result |
| Charging reaches reserved limit | Provider-supported incremental authorization or controlled stop before exposure exceeds policy |
| Session completion | Final rate comes only from backend; capture/void occurs once with idempotency |
| Duplicate/late webhook | One canonical payment state; no duplicate capture or receipt |
| Provider timeout | Intent becomes recoverable pending state; inquiry/webhook resolves it, not a blind duplicate charge |
| Refund | Immutable compensating ledger entry and receipt/payment history update |
| CPO settlement report | Exact matches auto-close; mismatches are visible exceptions |
| Cross-currency card | Only permitted where merchant/PSP route supports charging-country presentment currency; no hidden ElectraHub FX |
| Card-present | Certified terminal/PSP reference only; simulator never handles real PAN/CVV |
| Region unsupported | Payment method not offered and charging cannot start through an invalid route |

## Decisions Required Before Implementation

1. Confirm Model A, CPO direct merchant, for the first production pilot.
2. Select the first target geography: Netherlands/EU is the recommended first
   commercial path because it aligns with the business plan.
3. Choose the first sandbox adapter: Mollie for Netherlands-local method focus,
   or Stripe for a shared US/EU card-first path.
4. Confirm whether physical card terminals are in first-pilot scope. If yes,
   select a supported terminal PSP before design starts.
5. Confirm which currencies may be presented at the first pilot and explicitly
   defer FX and multi-currency wallet conversion.
6. Obtain external payments/legal advice before Model B, India production,
   cross-border settlement, or holding CPO/driver funds.

## Source Notes

The following official provider and regulatory sources informed this plan:

- Stripe Sandbox testing: https://docs.stripe.com/testing
- Stripe Connect charge and connected-account models:
  https://docs.stripe.com/connect/charges?locale=en-GB
- Mollie Connect overview: https://docs.mollie.com/docs/connect-overview
- Mollie test mode: https://docs.mollie.com/reference/testing
- Adyen Platforms: https://docs.adyen.com/platforms
- Razorpay test and live modes:
  https://razorpay.com/docs/payments/dashboard/test-live-modes/?preferred-country=IN
- Razorpay Route linked accounts:
  https://razorpay.com/docs/payments/route/linked-account/?preferred-country=IN
- Cashfree sandbox: https://www.cashfree.com/docs/payments/online/resources/sandbox-environment
- 2C2P sandbox: https://developer.2c2p.com/docs/sandbox
- De Nederlandsche Bank on payment-service-provider licensing:
  https://www.dnb.nl/en/sector-information/open-book-supervision/open-book-supervision-sectors/payment-institutions/licensing-requirement-for-payment-service-providers-overview/what-is-a-payment-service-provider/
- De Nederlandsche Bank on platform/PSD2 considerations:
  https://www.dnb.nl/en/sector-information/open-book-supervision/laws-and-eu-regulations/psd2/electronic-trading-platforms-e-commerce-platforms-under-psd2/
- FinCEN MSB registration:
  https://www.fincen.gov/resources/money-services-business-msb-registration
- RBI cross-border payment-aggregator notification:
  https://rbi.org.in/Scripts/NotificationUser.aspx/upload/Scripts/NotificationUser.aspx?Id=12561

## Status

Planned on 2026-07-20. No payment code, live PSP configuration, or production
fund movement was changed by this planning work.
