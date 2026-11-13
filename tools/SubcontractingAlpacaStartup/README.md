# Microsoft Subcontracting CI prerequisite (issue #21)

Gunnar selected option B on 10 November 2026:
https://github.com/businesscentralal/bc-origo-bifrost-subcontracting/issues/21#issuecomment-6762921548

`AdditionalSetup.ps1` is a fragment to append to the CI owner's **existing** Alpaca
startup bundle, after its original AdditionalSetup logic. It synchronizes and
installs the Microsoft Subcontracting package already published in the image,
then confirms tenant installation. It targets only the paired CI container's
`default` tenant using the image-provided `ServerInstance`. It is not a script to
run against a worker's local BC server or a customer server.

The fragment refuses missing/ambiguous/old/non-Global packages and a different
already-installed version. A restart with the exact version installed performs
no writes. Errors propagate; no publish, Force, schema recreation, upgrade,
licensing, consent, credentials or HTTP changes are performed.

## Integration remaining with Architect / CI owner

1. Preserve the current managed Alpaca startup bundle, including all original
   customization scripts and the original AdditionalSetup execution order.
2. Append this fragment to that bundle's AdditionalSetup.ps1. Do not replace the
   complete managed bundle with this single file or the repository source ZIP.
3. Publish that combined bundle at an approved, versioned URL reachable by the
   build container. Record its content hash and this repository's exact commit.
4. Configure `alpaca.startupScriptUrl` in `.AL-Go/settings.json` using that actual
   URL, then verify the effective merged settings still select it for Default.
   No speculative URL is committed here. Alpaca's documented setting replaces
   its startup customizations, so preserving them is part of integration.
5. Compile both apps and publish/read back the new candidate before external
   verification. Run a fresh **whole** paired Default/Test CI workflow at that
   candidate. Check startup install/readback, private dependency download,
   signed/no-IVT Default, Test product republish, executed AL counts, Test-only
   skipUpgrade and cleanup. Never rerun Test alone against an expired container.
6. Land the reviewed main-target repair through Architect, then update PR #22's
   existing branch from main, as Gunnar requested. Do not copy this fix across
   feature branches before that merge or force publish the Microsoft app.

`tools/Test-SubcontractingAlpacaStartup.ps1` executes the fragment with mocked
platform cmdlets. It runs through `Test-SharedAlpacaContainer.ps1`, already called
by the pipeline-guard workflow. Its result is a local regression result, not a
live installation, native AL full-suite, UI or MCP result. Main currently has
zero AL source/test files; a zero-test build cannot establish a full-suite pass.

References:

- Alpaca setting behavior: https://docs.cosmoconsult.com/en-us/cloud-service/alpaca/github/setup-al-go-settings.html
- Docker startup ordering: https://github.com/microsoft/nav-docker/blob/main/HOWTO.md#additionalsetupps1
- Platform tenant readback: https://learn.microsoft.com/en-us/powershell/module/microsoft.businesscentral.apps.management/get-navappinfo?view=businesscentral-ps-28
