TASK
Create only game/scripts/domain/regular_story_catalog.gd and game/tests/regular_story_core_tests.gd. Pure data/assessment helper, no existing project files. Do not read the repository or any credentials; this contract is self-contained. This is a new bounded public game component, not the previously cancelled repository review.

CONTEXT
Godot4.7 typed GDScript, Korean comments/text. Codex owns integration/persistence/UI. You own only two new files. Do not execute tools other than Read/Edit/Write/Glob/Grep, no shell/network/git. Do not edit AGENTS/docs/UID files. Return compact changed paths, decisions, unrun tests. You cannot run tests; Codex independently executes.

API
extends RefCounted, no preload. static ids()->Array[String] exactly dohyun,hayoung,maru.
static story(customer:String)->Dictionary deep copy, unknown {}.
story: {id,title,opening,routes:Array}. Each route {id,label,reply,chapters:Array,ending}. Two chapters each {title,dialogue,success,requirements:Dictionary}. Every opening/reply/dialogue/success/ending is substantive original Korean character dialogue, about 1~3 sentences. Existing personas: 한도윤 late-working developer likes rich filling ramen; 서하영 elementary teacher short lunch likes light aromatic; 윤마루 budget graduate student likes spicy quick ramen. Give character-specific connected stories and different endings for choices (not just counters). No copied reference-game text/assets.
static route(customer:String,route_id:String)->Dictionary deep copy, unknown {}.
static chapter(customer:String,route_id:String,index:int)->Dictionary deep copy, index0/1 else{}.
static assess(customer:String,route_id:String,index:int,metrics:Dictionary)->Dictionary {error:String,all_met:bool,lines:Array[String]}. metrics exactly {score:int,price:int,prep:int,profile:Dictionary}; profile rich/salt/aroma/chew/spice each int0..10. Reject unknown, missing/wrong type/out of range with nonempty error, never silently successful. Price0..1000000000 prep1..10000 score0..100. Result lines human-readable required/current values for every condition; no state mutation. Requirements are only score_min, optional price_max,prep_max,rich_min,rich_max,aroma_min,spice_min,cost_max. metrics must ALSO include cost:int0..1000000000 (so exact keys score/price/prep/profile/cost).

ROUTES / REQUIREMENTS (first => second)
dohyun hearty: score_min80 rich_min8 => score_min85 rich_min9.
dohyun quick: score_min80 prep_max150 => score_min85 prep_max150.
hayoung aroma: score_min80 aroma_min7 => score_min85 aroma_min8.
hayoung light: score_min80 rich_max4 => score_min85 rich_max3 prep_max100.
maru spicy: score_min75 spice_min5 price_max8500 => score_min80 spice_min5 price_max8500.
maru budget: score_min75 price_max7500 => score_min80 price_max7500 cost_max1500.
No extra gating or hidden conditions, no cash/economy changes, no existing file dependency.

TESTS
Standalone extends SceneTree, _initialize runs checks, prints 'regular_story_core checks=N failures=N', quits0/1. Meaningful all12 pass/boundary/fail, malformed metrics numeric types bool/float/unknown/missing keys/axes, deep-copy nonmutation, all nonempty unique story/branch dialogue. No magic passing test count. Do not run it yourself. No other files.

EXECUTION OUTCOME (2026-10-17)
Claude invocation exit1/is_error=true/1turn/session-expired, no edits. No retry or permission widening. Codex implemented the catalog and focused tests under default implementation authorization; actual pure189/0/exit0. Initial unreachable spice6 condition was corrected to current achievable spice5 plus score80 before acceptance. No successful Claude implementation/review is claimed.
