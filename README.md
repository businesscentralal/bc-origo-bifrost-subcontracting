# Bifröst Subcontracting

**App name:** Bifrost Subcontracting
**Publisher:** Origo — **Version:** 28.0.1.0 — **Target:** Cloud (BC 28.5, runtime 17.0)
**App ID:** `a1a7e927-8beb-4ab5-b2c3-68d0f339e43b` — **Test app ID:** `81cc895f-e3a4-4ef2-93e4-1ef8da227d59`
**Object ID range:** 10036885–10036984 (tests 97300–97399) — **Namespace:** `Origo.Bifrost.Subcontracting`

## Overview

Bifrost Subcontracting makes Microsoft's **Subcontracting** app callable through Bifröst message types. It is built on the same basis as
[Bifrost Subscription Billing](https://github.com/businesscentralal/bc-origo-bifrost-subscription-billing).

**Microsoft source:** <https://github.com/microsoft/BCApps/tree/main/src/Apps/W1/Subcontracting>

**Status:** Exposes `Manufacturing.Subcontracting.CreatePurchaseOrders` through Bifröst for creating purchase orders from a released production routing operation. The message preserves the existing public type key while living in the dedicated Subcontracting app.

## Functional Flow

1. The caller provides a released production order and subcontracted routing operation.
2. Bifrost Foundation dispatches `Manufacturing.Subcontracting.CreatePurchaseOrders` to this app.
3. The app validates the routing line and calls Microsoft's subcontract purchase-order creator.
4. The response includes the production order number and number of purchase orders created.

## Benefits

- Create subcontract purchase orders through the standard Bifröst message dispatcher.
- Keep subcontracting dependencies isolated from the general Manufacturing app.
- Reuse Microsoft's subcontracting business rules and setup.

## Logic Flow

`Caller -> Bifrost Foundation Dispatcher -> Sub PO Create Impl ori -> Subc. Purchase Order Creator -> JSON response`

## Setup & Configuration

Install Bifrost Foundation and Microsoft's Subcontracting app. Configure the subcontracting requisition worksheet in Manufacturing Setup and assign a subcontractor vendor to the production work center. Assign the Bifrost Subcontracting permission set alongside the appropriate Bifrost Core permissions.

## Example Scenario

Create purchase orders for one released production routing operation:

```json
{
	"type": "Manufacturing.Subcontracting.CreatePurchaseOrders",
	"data": {
		"productionOrderNo": "X-PROD-0001",
		"routingReferenceNo": 0,
		"routingNo": "X-ROUTE-01",
		"operationNo": "020"
	}
}
```

## Objects

| ID | Object | Name |
| --- | --- | --- |
| 10036885 | Enum extension | Sub Msg Type ori |
| 10036886 | Codeunit | Sub PO Create Impl ori |
| 10036887 | Codeunit | Sub Registration ori |
| 10036888 | Permission set | BIFROST Subcontracting ori |

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
| `app/` | The AppSource app (`Bifrost Subcontracting`), message types, registration, and permission sets |
| `test/` | Test app (`Bifrost Subcontracting - Tests`) |
| `tools/` | Pipeline guard scripts |
| `.AL-Go/`, `.github/`, `.alpaca/` | AL-Go for GitHub / COSMO Alpaca pipeline configuration |
