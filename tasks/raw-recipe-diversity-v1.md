# TASK
Audit how much visible numerical outcome diversity the fresh starter raw broth
and noodle choices actually provide, before adding more ingredient/goal content.

## CONTEXT
Main e962eaf remains the accepted419-source/schema18 game. Independent PR50
server challenge (schema19) is committed/pushed but waiting for exact native-v5
launch approval. Do not change it. User authorized sustained development until
the Codex5-hour quota has about30%remaining; menu development/farming diversity
is their top priority. More mathematical recipes are not automatically more fun.

## CLAUDE OWNERSHIP
ONLY new excluded tool game/tools/audit_raw_recipe_diversity.gd. No other edits,
UIDs, docs, source/config, tests, AGENTS, Git, Bash, network or subagents.
Codex owns source safety, independent enumeration/result checking, actual runs,
report/evidence and Git. File-only restricted/dontAsk/strict empty MCP, max30turn.

## REQUIREMENTS
- Pure catalog/evaluator study, NOT an earned playthrough. No GameState progress,
  user save, money/XP/rank/stock injection or gameplay changes. Clearly distinguish
  enumerated theoretical starter choices from player discovery or campaign volume.
- Enumerate every canonical rank1 starter-accessible broth multiset of1..3raw
  portions and every rank1method, preserving repeated portions. Exclude supplier-
  gated/sample ingredients. Enumerate every rank1 starter flour/water/cut/method
  noodle formula. Inspect/reuse the actual catalogs and validation functions.
- For each candidate evaluate THREE fixed valid full raw-component bowls, varying
  tare/oil/toppings/cook. Match manufactured broth/noodle IDs and raw formulas via
  their actual pure workshop helpers, do not use nonexistent/historical setters.
- Keep the companion raw component fixed per context. Use valid actual starter
  products; do not claim choices were manufactured, selected or tasted by a player.
- Write each candidate's canonical formula, all three full configs and comparable
  numeric outcomes (actual evaluator numeric taste/profile/customer scores, prep
  seconds, unit cost; exclude recipe text/name/formula IDs from the numeric key).
  Reuse Check.parse_config and validate evaluator preconditions for every config.
- Compute unique numeric outcome signatures ACROSS ALL THREE contexts, collision
  group sizes, representative collisions, and per-numeric-metric ranges. Do not
  claim equality across all possible toppings/customers from three observed cases.
- Include input catalog IDs/methods, enumeration counts and schema/algorithm
  version metadata in one JSON; stable ordering, deterministic output, defensive
  copies. Cap finite loops with explicit errors rather than partial success.
- CLI --audit-out=<new canonical absolute directory>. Require an existing real
  parent, reject existing file/directory/symlink/brokenlink, relative path, missing
  parent and parent symlink/alias BEFORE writing. Do not overwrite/delete anything.
  Reuse the existing excluded raw-staff audit's safety pattern if useful.
- All internal self-checks must run under release mode (no assert); count/fail
  report. Explicit errors on invalid args/output/write; actual exit0 only complete
  success,1checks/engine failure,2bad args. No caught-and-hidden runtime errors.

## ACCEPTANCE / VERIFICATION (CODEX)
Run with frozen accepted main419PCK; independently check exact multiset/formula
coverage, canonical uniqueness, numeric outcome grouping/ranges, every config's
identity and JSON shape; repeat into a second new output to verify determinism.
Reject semantic mutations even with valid JSON and preserve all safety fixtures.
Confirm419game sources/schema18/assets/PCK untouched. Report bounded findings
and next menu-design implications without a new gameplay/native/phone claim.

## RETURN
Exact changed path, tool args/output fields, chosen contexts/outcome metrics,
ambiguities/limitations, UNRUN tests and permission denials. Do not run commands.
