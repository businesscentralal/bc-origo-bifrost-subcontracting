# Changelog

## [28.0.0.0] - Unreleased

- Repository scaffolded from Bifrost Subscription Billing setup.
- Added Foundation application registration (codeunit 10036887), base/full/read permission sets and Foundation role extensions (10036888–10036892).
- Added installed-app registration and licence-admin discovery smoke tests (97302), with no message types or copied Microsoft code.
- Kept Subcontracting help links and bilingual permission captions available through Foundation discovery.
- Fixed the keyword translation guard for registration-only scaffolds; keyword-less message declarations still fail, with applicability regression checks.
- Added Subcontracting.TransferOrder.Create (enumextension 10036895, codeunit 10036896). It runs report Subc. Create Transf. Order for one subcontracting purchase order. That report commits after the lines exist. Permission set 10036888 executes the codeunit. Tests are 97312 and 97313.
- A caller who is not SUPER and has no execute permission on codeunit 10036896 is refused with PermissionDenied before that report runs. Nothing is created. BIFROST Full ori still includes the execute permission.
- Localized the transfer message's contract/help chapters in is-IS and declared its source, demand and permission preconditions (10036896). Replaced the injected permission-refusal test with an exact read-role check at the production Codeunit.Run boundary; added an installed-resource help regression (97312).
- Check effective execute permission without reading User metadata, so restricted callers can receive the intended refusal without an unrelated User-table permission error (10036896).
