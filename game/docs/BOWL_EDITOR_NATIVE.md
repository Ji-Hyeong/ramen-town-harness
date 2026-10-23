# Native bowl editor: implementation checkpoint

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
  discovery conditions. Information and add/replace use separate48px controls.
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

Original food/background/steam PNGs were generated for this visual direction.
Their bytes, prompts, hashes and measured alpha bounds are preserved in
`uiux-reset/native-assets/`. Runtime AtlasTextures omit transparent margins
without editing the originals. The existing original scallop is reused. Broth
palette shading affects the soup region, preserving the bowl and separate food.
Noodle variants have small generated silhouette differences; they are not claimed
to be pixel-identical ceramic. Broth/noodle/topping appearance is supported, not
an exact distinct visualization of every oil, firmness or process setting.

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
paths are accepted, and missing/unexported fixtures fail explicitly. Execution
confirmation and fresh native screenshot review are required before visual
acceptance and main merge. Do not use older captures as current proof.
