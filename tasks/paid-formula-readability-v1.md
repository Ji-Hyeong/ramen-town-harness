# TASK
Keep complete raw ingredient names and quantities readable in paid comparison.

## CONTEXT
Accepted main1ce05cd has integrated paid formula and sales follow-up. Native
screens reveal a five-ingredient broth can split the Korean onion name mid-word.
The user requests Codex-only continuation until quota is exhausted; the prior30%
cutoff is superseded. Do useful bounded work and preserve acceptance/publication.

## REQUIREMENTS
Reuse the existing two-dish detail and literal paid formatter. Put each broth
ingredient/quantity and each noodle option on its own unbroken line. Preserve
legacy names, methods, all quantities, folded history, knowledge gates, input and
scroll behavior. No smaller fonts, hidden text, clipping, domain or save changes.

## CONSTRAINTS
Editable: main.gd comparison caption construction; existing formula QA; this
contract; AGENTS and scoped report/evidence. No Claude/other agents, live saves,
phone installation or global settings. No new runtime systems/assets/schema.

## ACCEPTANCE CRITERIA
All actual fresh/earned/legacy formula profiles finish. Each complete line fits
the actual inherited font/column, without automatic CJK splitting. Long broth
and noodle combinations remain reachable at390x844/390x750/1280x800. Paid state,
deletion/later-draft, restart and price-only behavior remain unchanged.

## VERIFICATION
Use existing paid_formula_comparison_qa.gd against a fresh builder snapshot with
headless --layout-only and isolated --qa-out; run existing paid-result regression.
Prepare a new signed-engine QA app with build_qa_app.py --fixture
paid-formula-comparison, request exact action-time GUI approval, inspect exit,
logs, all21current captures and source/PCK equality. Do not equate tests with fun.
