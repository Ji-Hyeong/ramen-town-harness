# TASK
Fix two defects found in actual mobile renderer captures. Small presentation correction only.

# CONTEXT
User ran native qa_capture: 20 real screenshots, QA capture 1504 checks / 0 failures. Codex visually inspected portrait_4_feedback_v1.png: customer score is rendered as a vertical stack of digits and 점 at the extreme right, because feedback header allocates insufficient width to the score. portrait_1_shop_closed.png and portrait_7_service_mid.png show the status/note text spilling under the bottom navigation. Existing rectangle tests miss text line overflow. Isometric art suite is independently passing 30 tests / 40404 checks; layout 1464 / 0.

# REQUIREMENTS
- In main.gd _customer_card, keep each score (e.g. 71점) in one readable line with enough width. Preserve the complete name and all five stars without horizontal overflow; choose responsive header arrangement if necessary. No rating or evaluation logic changes.
- In main.gd status strip sizing, fit the actual wrapped ServiceStatusLabel and ServiceNoteLabel text completely above navigation at 390x844; account for padding/spacing/font height. Retain meaningful guidance and existing failure messages. Preserve shop canvas area >=55%, HUD exclusion and controls >=44px. No gameplay, save or researcher flow changes.
- Add targeted QA assertions using actual labels in the first/active service and feedback flows: score line count is one and its rectangle fits the customer card; status/note text minimum wrapped height fits its allocated label and strip, no navigation overlap. Keep all old assertions. Use exact Godot methods available in existing code; do not implement fake metrics that simply mirror fixed sizes.
- Update AGENTS history with visual findings, exact bounded edits and unrun status. No need to rewrite game/art docs.

# CONSTRAINTS
Editable ONLY game/scripts/ui/main.gd (these two presentation areas), game/tests/qa_capture.gd (targeted text QA) and AGENTS history. File tools only; no Bash/network/Git/credentials/runtime/domain/art changes. Do not remove content or relax prior area/reachability assertions to force a pass.

# ACCEPTANCE CRITERIA
Complete one-line scores, names and stars remain readable at both sizes; complete status and note fit above navigation; previous 55%/touch/reachability tests remain. Gameplay unchanged.

# VERIFICATION
Do not run tests. Codex reviews and runs two-size layout QA and checks actual captures. Report exact changes, unrun tests and limitations. Keep final handoff compact.
