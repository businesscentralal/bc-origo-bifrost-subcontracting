# Extension: Bifrost Subcontracting

## Customer
Origo / AppSource

## Prefix
(none - objects use raw names with the mandatory `ori` suffix inside the `Origo.Bifrost.Subcontracting` namespace; same as Bifrost Subscription Billing)

## Namespace
Origo.Bifrost.Subcontracting (tests: Origo.Bifrost.Subcontracting.Test)

## Object ID Range
App:   10036885-10036984
Tests: 97300-97399

| Id | Object | Name |
| --- | --- | --- |
| 10036885 | enumextension | Sub Msg Type ori |
| 10036886 | codeunit | Sub PO Create Impl ori |
| 10036887 | codeunit | Sub Registration ori |
| 10036888 | permissionset | BIFROST Subcontracting ori |
| 97300 | codeunit (test) | Sub Create PO Tst ori |

## Microsoft source
Wrapped Microsoft app: Subcontracting (`1f32a50d-0057-4b95-b5df-cc04d7e89470`, 28.5.0.0). Source: https://github.com/microsoft/BCApps/tree/main/src/Apps/W1/Subcontracting
Read it there before designing message types.

## Setup Notifications
Setup notifications live **only** on Bifröst Foundation's `Setup ori` page. This app never raises a `Notification` of its own.
It makes itself known to Foundation by subscribing to `App Registry ori.OnRegisterApps` and calling `AddApp` with this
app's module id, its display name and its setup page id (`0` while the app has no setup page). Follow
`app/src/Common/SubRegistration.Codeunit.al` in Bifrost Subscription Billing.

## Target BC Version
28.5 (application 28.5.0.0, platform 28.0.0.0, runtime 17.0)

## Source Control
Platform: GitHub
Organization: businesscentralal
Repository: bc-origo-bifrost-subcontracting
Default branch: main

## Dependencies
- Bifrost Foundation (`7505e808-6e52-4b96-a328-82573391297a`, 28.0.5.590, same floor as Bifrost Subscription Billing)
- Subcontracting (Microsoft, 28.5.0.0; application floor 28.5.0.0)

## Naming Rules
- Every object carries the `ori` suffix (AppSource mandatory affix), max 30 characters.
- The brand name "Bifrost" lives in the namespace, the app name ("Bifrost Subcontracting"), the permission sets and
  user-facing captions - never as an object-name prefix.
- Message type names have three parts: `Domain.Entity.Action`.
- Icelandic captions use "Bifröst".

## Development Standards

This project follows the **Origo BC Development Standards** (https://github.com/OrigoSoftwareSolutions/bc-dev-standards).

Before writing any AL code, load the relevant skills: `origo-bc-al-coding-standards`, `origo-bc-test-writer`, `origo-bc-documentation-writer`.

Key rules always in effect:
- Namespace `Origo.Bifrost.Subcontracting` at the top of every app file (`Origo.Bifrost.Subcontracting.Test` in tests)
- XML documentation on every object and non-local procedure
- Bilingual captions (en-US + is-IS) on all user-facing text
- `SetLoadFields` on all record reads
- `Format(guid, 0, 4)` for GUIDs, `Format(value, 0, 9)` / `Evaluate(var, text, 9)` for culture-invariant serialization
- Never use `Format()` / `Evaluate()` on enum values - use `.Names()`, `.Ordinals()`, `.AsInteger()`, `.FromInteger()`
- Implementation = code + tests + documentation (the contract chapters of `Msg Contract ori`)

## Development Environment
- COSMO Alpaca containers are defined in `app/.vscode/launch.json` (git-ignored, the authority for instance ids).
- Compile locally with alc.exe + CodeCop/UICop/AppSourceCop; AL-Go CI is the gate for AppSource affix rules (AS0011).
- `app/AppSourceCop.json` sets `mandatoryAffixes`/`mandatorySuffix` to `ori` and the supported countries.
- Reference implementation: Bifrost Subscription Billing (businesscentralal/bc-origo-bifrost-subscription-billing).

## Message Type Conventions
- One enum extension of Foundation's `Message Type ori` with one value per type, named `Domain.Entity.Action`. These
  keys are the published external API contract and must never be renamed or removed.
- Each type has an Impl codeunit implementing `Msg Interface ori`, `Msg Discovery ori` and `Msg Contract ori`, with
  `TableNo = "Message Argument ori"` and an `OnRun` that runs its own write, as in Bifrost Subscription Billing.
- Errors are returned as `status = Error` with a helpful message; never let an unhandled exception reach the API.

## Test App Rules
- The test app uses Bifröst Foundation's public API only. Run message types through the public `Dispatcher ori`.

## Testing Through the MCP Server
- Keep MCP calls serial - parallel bursts crash the server.
