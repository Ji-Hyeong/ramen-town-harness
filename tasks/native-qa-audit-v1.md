# TASK
Make a read-only mechanical auditor for this repository's frozen native QA runs.

## CONTEXT
Base main ad92619. PR66 ingredient cues remain separate and await approved native
launch; do not change its frozen app. Repeated manual source/PCK/exit/capture/save
comparisons are useful but easy to omit. A zero process status alone is not proof.

## REQUIREMENTS
Given an explicit JSON specification, check one named run under one app root:
actual start/finish/exit, capture-mode positive summary and no engine errors or
warnings, exact profile PNG counts/dimensions/structural integrity and freshness,
frozen source bytes against an explicit full Git commit, PCK/engine hashes and
post-run official engine signature, and complete baseline save byte equality.
Pin reviewed PCK/engine hashes in the spec independently of the app manifest;
changing a binary and its manifest together must still fail.
Write a new report only; never execute Godot/GUI or write inputs. Label visual
review and iPhone/human acceptance as still required, even when mechanics pass.

## CONSTRAINTS
Only game/tools/audit_native_qa.py and its unit test plus task/report/evidence/
AGENTS. Standard library, no dependencies, credentials, network, live saves,
global settings, Claude or agents. Fixed git/codesign subprocess argument arrays
only; no shell. No arbitrary revision/path options or paths escaping app/spec
scopes. Explicit failures; no success fallback. Do not merge PR66 without native.

## ACCEPTANCE CRITERIA
Negative tests reject exit-zero engine error, layout mode, missing/extra/stale/
corrupt/wrong-size PNG, stale source/PCK/engine, failed signature, missing or
changed whole save, unsafe relative/symlink paths and existing report. Verify
accepted PR65 v3 run against ad92619 and original frozen headless saves. Inspect
all input file hashes before/after to establish read-only behavior. This does not
replace the already completed human screenshot review or prove a new game build.

## VERIFICATION
python3 -m unittest discover -s game/tools -p test_audit_native_qa.py -v
python3 game/tools/audit_native_qa.py --spec <owned absolute JSON> --report <new absolute JSON>
Run the latter against accepted final v3; do not launch an app or engine.

## ACCEPTED
Ten unit tests pass, including coordinated binary+manifest replacement against
independent SHA pins. Final CLI audit of accepted PR65 v3 run20261102T101349Z-56279
passes with exit0,474source/2045checks/30PNGs/3whole save pairs/signature0. Hash
all517inputs before/after: byte-identical. Tool SHA and summaries in evidence.
No engine/GUI execution or input write. Native visual review is still a separate
requirement; this confirms the previously reviewed run, not a new game build.
