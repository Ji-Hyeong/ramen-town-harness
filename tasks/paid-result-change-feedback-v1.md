# TASK
Show the actual paid revision consequence in the existing tasting-result button.

## CONTEXT
Accepted main df3741c / schema 19 / 440 runtime files. The comparison screen now
has concise known-recipe summaries, but a paid result still says only "이번 개량의
변화". Reuse the accepted projection without adding a new paragraph or card.
User requests Codex only and stopping with at least 30% quota remaining. Check
actual usage between bounded tasks and reserve verification/publication time.

## REQUIREMENTS
- Codex owns all work; no Claude or other agent calls.
- Start from main. Scope: bowl_workbench.gd result button, focused actual-record
  QA, reviewed builder fixture registry, docs/evidence/history.
- Keep EditorRevisionSummary, its 48px single-line geometry, existing icon,
  click feedback, drag cancellation and comparison-modal action.
- Derive the title only from record.comparison.prev_config and the paid record
  config/evaluation. Never compare against the later draft or a different record.
- Independently gate both exact recipes with state.recipe_known. Unknowns use
  the existing generic title and disclose no new taste/equality/compatibility.
- First tasting has no invented predecessor/button. Invalid comparison follows
  existing explicit error handling. Do not invent successful data.
- Preserve selected-goal priority, portraits, customer reasons/value feedback,
  recipe identity, details and existing navigation. Price-only revisions must
  not claim new taste; retain the current price feedback in detail.
- No domain/economy/save/schema/assets changes. Browsing, tapping, dragging,
  switching result and restarting may not charge, apply, reveal or alter records.
- No iPhone install, live save access, configuration/credential work or deployment.

## VERIFICATION
Use actual fresh raw production and paid tasting: first record, pork bone 2 -> 3
same taste +480 won/+24 base seconds, reverse savings, changed broth/noodle and
price-only. Prove recorded predecessor/current identity after later draft changes,
retained old record, delete old predecessor where permitted and exact disk restart.
Synthetic hidden-knowledge coverage is separate from actual progression evidence.
Run the same driver against frozen main and current code at 390x844, 390x750 and
1280x800; assert button fit, held state, drag cancellation and actual modal values.
Rerun selected-goal and first-menu-journey QA plus relevant summary/knowledge
regressions. Build fresh isolated native apps; headless is not rendered acceptance.
Ask once for the exact prepared apps at action time, then native review and publish
READY PR/squash/local main synchronization under standing authorization.

Commands use copied verified Godot from a new build_qa_app.py output, --headless
only for focused/layout runs, scoped new --test-data-dir / --qa-out / --dev-data-dir.
The supported Computer Use launcher performs actual approved native runs.
