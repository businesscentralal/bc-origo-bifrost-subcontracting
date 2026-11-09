# Changelog

## [28.0.1.0] - 2026-11-02

### Added
- Added `Subcontracting.PurchaseOrder.Create` (issue #6) for creating subcontracting purchase orders from a released production order routing operation: coded refusals, prechecks, purchase order numbers in the response, is-IS translations, Bifrost Full/Read permission set extensions and tests.
- Objects: enumextension 10036885, codeunits 10036886/10036887, permissionset 10036888, permissionsetextensions 10036889/10036890; tests 97300/97301.

### Fixed
- Callers without `BIFROST Subc ori` (included in Bifrost Full) are refused with PermissionDenied before any purchase data is created. Gate table 10036891. Permission tests 97300 run with TestPermissions NonRestrictive (AC05/AC08).

## [28.0.0.0] - Unreleased

- Repository scaffolded from Bifrost Subscription Billing setup.
