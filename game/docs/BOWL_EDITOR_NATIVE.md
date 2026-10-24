# Native bowl editor: implementation checkpoint

## Current verified checkpoint

2026-10-25: [Ingredient payoff](INGREDIENT_PAYOFF_V1.md) adds an opt-in
before/after dish preview below material details and surfaces real completed
direction/research feedback in the native result. The initial editor composition
and existing game rules remain unchanged. [Current capture gallery](uiux-reset/ingredient-payoff-v1/)
and root design QA supersede earlier counts for this bounded addition.

2026-10-25: [Native exploration](EXPLORATION_WORKBENCH_V1.md) now hands received
materials to the actual editor detail via read-only reveal_ingredient. Current
same-pack editor regression524/0/exit0 and compact219/0 retain this editor's
accepted composition. [Current exploration evidence](uiux-reset/exploration-workbench-v1/)
and root design QA record its separate new flow; the earlier editor checkpoint
below remains the historical basis, not a new iPhone acceptance claim.

The selected option3 composition remains the editor's first screen. Current work
adds compact ingredient details with a fixed apply action, explicit actual-slot
replacement at capacity, and fixed broth/noodle sub-tabs with context/scroll
restoration. Directed experiment links open their relevant ingredient/method tab.
[Player rules](INGREDIENT_EDITOR_FLOW_V1.md), [fresh captures and comparisons](uiux-reset/ingredient-flow-v1/).

Final same-pack actual OpenGL flow567/0 and editor regression524/0, exit0 and
engine errors0;48 current PNGs total. Same packed390x750 layout flow261/0 and
editor219/0; live sheet resize and nonzero tab scroll restoration are included.
All277 runtime files and exported/embedded pack
2c0b06b227f8b7f667f3d572aa144c63e8b36ddcaf9e112fd2b2a76421e3c8f8 match,
with post-run official-engine strict signature0.14 new-flow originals,8 regression
originals and5 composed views were opened. Root [design QA](../../design-qa.md)
records exact scope/limits. The old [selected-mock rebuild evidence](uiux-reset/mock-fidelity-v1/)
remains historical; continuing work did not change its art/fonts/game rules.

The iPhone is excluded by the user's latest instruction. No current installation
or human usability/fun acceptance is claimed; the earlier prepared0.14 app is
stale and must be rebuilt if device work is requested later.

## Selected target

The human selected displayed concept3 and requested categorization for a larger
topping collection. The visual target is
`uiux-reset/refinements/concept-03-categories-v1.png` (853x1844 source pixels;
390x844 logical portrait target). This PNG is a design reference, not a game
screenshot. The native implementation remains Godot, with the iPhone target.

## Implemented behavior

- Persistent broth/tare/oil and noodle/firmness summaries open focused dialogs.
  The live dish layers actual selected noodle art, broth palette and each topping
  portion separately. Repeated toppings produce separate sprites.
- Actual rank capacity controls two, three or four portion slots. Select an
  occupied slot to replace it; removal uses the existing minimum-one guard.
- Fixed All, Meat/Egg, Vegetables/Fruit and Seafood filters cover the current
  eight catalog toppings. The ingredient list scrolls independently; draft,
  category and scroll position survive details. Locked items expose their real
  discovery conditions. Information uses a44px hit; add/replace uses a separate48px control.
- Each row reads the real catalog cost and preparation time. A successful recipe
  change animates the dish; a refused change does not celebrate food addition.
  Existing committed-click feedback and audio remain connected.
- Name, selling price, processes, research directions, sound and other existing
  feature routes remain available from focused dialogs or the work menu.
- Cooking shows the real phase/progress and cancel action. Existing guarded
  transactions own payment, stock use and record creation. Results show the real
  dish, three customer portraits/scores, feedback, comparison and experiment clues.
  Save failures remain visible and readable in full from the work menu.

`bowl_workbench.gd` owns view state and emits actions; `main.gd` delegates them to
the established guarded handlers. Legacy lab/result nodes remain controller
adapters, hidden while the new editor is visible. Tests do not count those hidden
nodes as current rendered evidence. Domain/services and save schema are unchanged.

## Assets and scope

New original frame/button/callout/icon and three-noodle bowl PNGs recreate the
selected reference, with full prompts, hashes and measured alpha regions in
`assets/ui/mock-fidelity/`. AtlasTexture bounds account for standard Godot import
size limits; PNG originals are unchanged. The rejected deeper bowl generation is
preserved but unused. Existing food/background/steam originals remain in
`uiux-reset/native-assets/`. The bowl has no baked toppings: actual repeated
portions are layered and broth-region shading preserves the vessel. Generated
pixel shading, smooth UI font and minor decorative details approximate the mock;
no pixel-identity claim. [Asset integration notes](uiux-reset/mock-fidelity-v1/ASSETS.md).

The13 interface symbols are upstream Google Material Symbols Rounded icons,
with source URLs, original/modified hashes and Apache2 license in
`assets/ui/material-rounded/`. Third-party Kairosoft art is not a game asset.
`docs/.gdignore` prevents reference galleries from becoming runtime resources.

## Verification boundary

Current verification and evidence status are in root `design-qa.md`. Headless
layout tests cannot establish visual quality or human usability. The dedicated
`tests/bowl_editor_qa.gd` uses actual pointer input and the current visible editor;
`--layout-only` explicitly omits rendering. Native mode captures each real
SubViewport and rejects blank images.

The four-slot image is explicitly a synthetic view projection: the fresh player
has not earned rank3 and no projection is saved into the controller's data.
The save-failure scenario creates/removes only its own temporary collision and
checks manual-save recovery in an isolated test directory. Ordinary saves and
the disconnected iPhone are untouched. Safe-area conversion is implemented;
physical iPhone layout, touch feel, accessibility and human-fun acceptance still
require separate validation. No Claude delegation occurred.

Use `game/tools/build_qa_app.py --fixture bowl-editor` for a fresh current-source
capture app; the default full fixture is unchanged. Only the two reviewed fixture
paths are accepted, and missing/unexported fixtures fail explicitly. Fresh native screenshot review is required before visual acceptance and main
merge. The current review used the explicitly authorized terminal execution
method because Computer Use was unavailable. Do not use older captures as proof.
