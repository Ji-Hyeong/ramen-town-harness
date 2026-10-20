# TASK
Connect the verified iOS development build to the user's real iPhone, provision,
sign, install and validate what can actually be observed.

## CONTEXT
Start from clean main7051f65, merged preparation PR13. The user confirmed USB
connection/trust. Actual discovery reports iPhone15Pro/iPhone16,1, iOS26.6.2,
paired wired tunnel, Developer Mode enabled. Xcode26.6/SDK26.5 and a real Personal
Team are ready; the accepted unsigned export is in the local checkpoint.

## REQUIREMENTS
- Use the real local team/device only. Keep account identifiers, device IDs,
  certificates, profiles, raw logs and personal data outside Git.
- Preserve the95 accepted game source files, Mac player/PCK and live Mac save.
  Build into a new scoped DerivedData/result bundle; never overwrite old proof.
- Allow normal automatic development provisioning needed for the authorized
  installation. Hand off actual credential, legal, trust or device prompts.
- Independently verify signed bundle, embedded game pack and actual installation
  results. Distinguish launch/process evidence from visual/touch/save acceptance.
- Do not read unrelated phone apps, photos, messages or saves. Use only this
  development app's container for any persistence tests and preserve existing
  app data if present. Never uninstall the app or erase the phone.

## CONSTRAINTS
Codex owns this bounded task; no Claude call required. Editable repository paths:
this contract, AGENTS.md, iOS documentation/README/verification/evidence, and
strictly necessary iOS preparation tooling/tests if a concrete defect occurs.
No game-rule, save-schema or public Mac player changes without a new scope.
GUI actions use CUA; use documented device development CLIs for their specific
build, inspection and installation operations. No security bypass/OS update.

## ACCEPTANCE CRITERIA
Record actual signed build/install outcomes and device identity only in safe
model/OS terms. Complete observable real-device checks; explicitly identify any
physical/user-dependent checks rather than claiming they passed. Preserve
reproducible local resume paths and publish only sanitized reviewed evidence.

## VERIFICATION
Verify original95 hashes/Mac PCK, signed bundle and entitlements/profile coherence,
embedded PCK equality, device install/launch JSON status, available scoped app
logs and any actual UI/save/lifecycle evidence. Relevant existing tooling tests
are rerun only if tooling changes. Publish ready PR and merge under the user's
standing authorization once its stated scope is verified.

## OUTCOME SO FAR
Actual iPhone15Pro/iOS26.6.2 is paired with Developer Mode enabled. Fixed the
Godot push Disabled enum after the first signed build failed65. Actual old
export now fails the new entitlement guard; corrected export passes.31tool
tests,13exported-pack checks and30config-preservation checks pass. Corrected
signed build/strict signature/profile-device-team coherence/install all pass.
Original95game sources/Mac player pack/live Mac save are preserved.

First launch fails with the device's generic security/signature/entitlement or
untrusted-profile error. User-owned developer-app trust/restart/unlock has been
requested. Do not mark launch, visual, touch, save or lifecycle acceptance as
passed until actual evidence exists. Signed app and Xcode project are preserved
in a private app-owned durable folder; no identities/profiles/raw logs in Git.

## FOLLOW-UP 2026-10-21
User completed developer-app trust; fresh launch0/JSONsuccess and actual game/
research screen captures confirmed. The old failed launch above is historical.
User rejected finger scrolling; fix/validation is tracked separately in
tasks/ios-touch-scroll-v1.md. Initial launch does not constitute touch acceptance.
