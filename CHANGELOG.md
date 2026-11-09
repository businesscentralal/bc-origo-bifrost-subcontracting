# Changelog

## [28.0.0.0] - Unreleased

- Repository scaffolded from Bifrost Subscription Billing setup.
- Added Foundation application registration (codeunit 10036887), base/full/read permission sets and Foundation role extensions (10036888–10036892).
- Added installed-app registration and licence-admin discovery smoke tests (97302), with no message types or copied Microsoft code.
- Kept Subcontracting help links and bilingual permission captions available through Foundation discovery.
- Fixed the keyword translation guard for registration-only scaffolds; keyword-less message declarations still fail, with applicability regression checks.
- Added Subcontracting.Worksheet.CarryOut (enumextension 10036898, value and codeunit 10036897). It runs report Carry Out Action Msg. - Req. for accepted lines of one subcontracting worksheet batch. Permission set 10036888 executes the codeunit. Tests are 97314 and 97315.
- Worksheet carry-out (codeunit 10036897) refuses a caller who lacks permission set 10036888 before it reads or changes the worksheet. Table 10036885 is the write gate for that set. Test 97314 checks the refusal in restrictive mode.
