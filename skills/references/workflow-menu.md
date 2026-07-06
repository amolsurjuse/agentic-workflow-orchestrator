# ElectraHub Workflow Menu

## Default Feature Flow
Run ElectraHub feature workflow for `<requirement description from chat>`.

`01-launchpad -> 02-story-forger -> 03-impact-mapper -> 04-delivery-architect -> 05-change-builder -> 06-verification-runner -> 07-risk-reviewer -> 08-quality-hardener -> 09-release-scribe -> 10-release-conductor`

`01-launchpad` must prepare the workspace first: verify required tools, check out/fetch canonical ElectraHub repositories from `electrahub-service-catalog.md`, capture the requirement from chat, generate `REQ-<YYYYMMDD>-<slug>`, and persist `/agentWork/<WORK_ID>/01-launchpad.out.<RUN>.md` before handoff.
