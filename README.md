# Bifröst Subcontracting

**App name:** Bifrost Subcontracting
**Publisher:** Origo — **Version:** 28.0.0.0 — **Target:** Cloud (BC 28.5, runtime 17.0)
**App ID:** `a1a7e927-8beb-4ab5-b2c3-68d0f339e43b` — **Test app ID:** `81cc895f-e3a4-4ef2-93e4-1ef8da227d59`
**Object ID range:** 10036885–10036984 (tests 97300–97399) — **Namespace:** `Origo.Bifrost.Subcontracting`

Bifrost Subcontracting will make Microsoft's **Subcontracting** app callable from outside Business Central through
Bifröst message types, so an agent can operate it end to end. It is built on the same basis as
[Bifrost Subscription Billing](https://github.com/businesscentralal/bc-origo-bifrost-subscription-billing).

**Microsoft source:** <https://github.com/microsoft/BCApps/tree/main/src/Apps/W1/Subcontracting>

**Status:** planning, no message types yet.

---

## Object ranges

| Object | Range |
| --- | --- |
| App (`app/`) | 10036885-10036984 |
| Test app (`test/`) | 97300-97399 |

---

## Documentation

All public documentation lives in the [businesscentralal/bifrost](https://github.com/businesscentralal/bifrost)
site repository and is published at <https://docs.bifrost.origo.is>.

| What | Where |
| --- | --- |
| Product documentation | <https://docs.bifrost.origo.is/en-us/subcontracting/> |
| Bifröst documentation home | <https://docs.bifrost.origo.is> |
| Release notes | [CHANGELOG.md](CHANGELOG.md) |

---

## Dependencies

| App | ID | Publisher | Version |
| --- | --- | --- | --- |
| Bifrost Foundation | `7505e808-6e52-4b96-a328-82573391297a` | Origo | 28.0.5.590 |
| Subcontracting | `1f32a50d-0057-4b95-b5df-cc04d7e89470` | Microsoft | 28.5.0.0 |

---

## Repository layout

| Folder | Content |
| --- | --- |
| `app/` | The AppSource app (`Bifrost Subcontracting`), no AL code yet |
| `test/` | Test app (`Bifrost Subcontracting - Tests`) |
| `tools/` | Pipeline guard scripts |
| `.AL-Go/`, `.github/`, `.alpaca/` | AL-Go for GitHub / COSMO Alpaca pipeline configuration |
