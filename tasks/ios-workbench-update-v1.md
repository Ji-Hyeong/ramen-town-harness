# TASK
Build accepted main2f43dbd for the connected user's iPhone and update the existing
Ramen Atelier development app, preserving its save data.

## CONTEXT
The human explicitly requests installation/update after connecting the iPhone.
Discovery-workbench PR19 has merged and passed fresh Mac visual/flow validation.
Actual discovery reports paired wired iPhone15Pro/iOS26.6.2 with Developer Mode.
Use existing official Xcode26.6, Godot4.7.2 iOS template and the user's real team.

## REQUIREMENTS
- Preserve the existing app bundle identity and back up only this game's saves
  privately before updating. Prefer same-bundle update over uninstalling.
- Stage into a fresh output folder; preserve accepted game source, Mac saves,
  player apps, previous builds and global developer-tool selection.
- Verify source hashes, exported pack/settings, signed bundle/profile coherence,
  actual installation, immediate save preservation and observable launch state.
- Keep account/team/device identifiers, certificates/profiles, raw logs and
  player saves outside Git. Use sanitized evidence for publication.
- No Claude delegation. No iOS trust/login/security prompt bypass; any required
  physical unlock or user authentication is handled by the human.

## CONSTRAINTS
Editable repository paths: this contract, AGENTS.md, iOS docs/README and sanitized
evidence. No game-rule, save-schema, UI or audio changes are requested. Generated
iOS project metadata may change only in the isolated staging build. Normal
development signing/provisioning needed for this authorized install is allowed.
Do not access unrelated apps/data or uninstall/erase the device.

## ACCEPTANCE CRITERIA
Record actual build/sign/install/launch outcomes. Verify backed-up saves against
the immediate post-update files before launch where possible. Distinguish actual
device evidence from human audio, input, keyboard, lifecycle and fun acceptance.
Do not mark device-dependent checks passed without evidence.

## VERIFICATION
Strict code signature, profile/device/team/application consistency and validity,
same bundle ID, embedded pack equality, source161 preservation except intentional
staged iOS project settings, actual devicectl JSON outcomes and scoped save hashes.
Use supported Xcode screenshot tools if available; do not claim touch/audio quality
from a screenshot. Publish ready PR and merge after independent verification under
standing authorization; record any required human action precisely.

## OUTCOME
Completed same-bundle update0.13/build13.0.1 and actual launch JSONsuccess/exit0
on iPhone15Pro/iOS26.6.2. No uninstall. Both game save files are privately backed
up and byte-equal immediately before/after install before launch. A separate real
v11 copy loads/saves/reloads in schema13 with equal state and byte-equal v11 archive.
Current161source hashes preserved; only staged project settings intentionally
differ. Actual exported pack25/0/exit0/engine0, signed build0, signature/profile/
device/team/app/validity/embedded-pack checks pass. Six existing template warnings
remain documented. Signed14-file app is privately preserved byte-equal and strict
signature0 again. Local metadata-placeholder and CLI option-order diagnostic
mistakes were corrected without runtime changes; the latter failed before any
device launch. Actual install/version/launch evidence is separate from unclaimed
current UI screenshot, physical input/audio/keyboard/lifecycle/performance or fun.
No further phone manipulation is needed. Publish sanitized evidence using a ready
PR and matching-head merge under standing authorization; final identity in chat/
private checkpoint. No Claude calls or source/save-rule changes.
