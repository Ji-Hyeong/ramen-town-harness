# TASK
Identify completed broths in the working notebook and archive by their actual
ingredients, portion counts and extraction method, without expanding details.

## CONTEXT
Base main ad9261936f6b95d9d5e4b8ba453ef1361bcc8c2e (PR65 native accepted).
Review of all30native shelf captures found many different formulas share the
same short product name and pot icon. Existing comparison details retain facts,
but browsing60owned formulas requires opening too many cards.

## REQUIREMENTS
Reuse existing raw pantry icons and catalog names. Group repeated ingredients
with exact portion counts, wrap whole icon/name groups on narrow screens and
show the owned extraction method beside existing cost/time facts. Keep primary
archive/use/compare actions, paging and fixed footer. All cues are read-only and
swiping over them scrolls the existing list. No compatibility/score forecast.

## CONSTRAINTS
Edit game/scripts/ui/bowl_workbench.gd and game/tests/broth_shelf_qa.gd only for
runtime/QA; task/report/evidence/AGENTS and original captures may be added.
No domain/save/schema/economy/cap changes, new assets, config, phone or live saves.
Codex only, no Claude or other agents. Preserve PR65 frozen source and captures.

## ACCEPTANCE CRITERIA
Rendered cues match each actual owned recipe on both shelves, including repeated
portions. Names/icons never split across rows or overlap actions at390x844,
390x750,1280x800. Independent synthetic five-ingredient/long-name/method layout
cases are marked separately from actual paid production. Browsing/swiping cues
changes no game value or disk file. Actual60-to61 path, archive/restore, save
failure/recovery/restart remain accepted. Native and frozen headless whole saves
must match accepted PR65 byte-for-byte. No merge before fresh approved native QA.

## VERIFICATION
Use existing broth shelf domain runner425 and component315/formula635 relevant
flows. Build a fresh snapshot with reviewed build_qa_app.py --fixture broth-shelf;
run frozen res://tests/broth_shelf_qa.gd --layout-only with separate --qa-out and
--dev-data-dir. Check actual exit/errors/warnings, all three complete save files,
and current source/PCK/official signature. Request exact new-app approval only
after headless acceptance; review every fresh capture before publication/merge.

## HEADLESS ACCEPTANCE
Frozen v2 UI2651/0, actual shelf domain425/0, old component315/0 and formula635/0,
all actual exit0/errors-warnings0. Source474exact; only UI/QA differ from accepted
mainad92619. Three whole UI saves equal that main's native saves byte-for-byte.
Maximum five-portion/long-name/repeated-ingredient cases are synthetic layout
only and do not modify player state. Actual native/rendered readability pending
user-approved final v2 launch; preserve unrun v1. No merge yet.
