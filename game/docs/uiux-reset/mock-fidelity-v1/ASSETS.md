# Selected-mock native assets

Visual source: `game/docs/uiux-reset/refinements/concept-03-categories-v1.png`.
These generated originals recreate individual assets from the selected direction,
not a screenshot shell. All labels, costs, counts and controls remain native UI.
The JSON files retain full prompts, original SHA256, dimensions and visible-alpha
bounds. No generated PNG was cropped, recolored or otherwise rewritten on disk.

`scripts/ui/mock_fidelity_art.gd` creates AtlasTextures at runtime. It transforms
original measured bounds to the actual Godot-imported texture size for frames,
icons and connectors. Nine-slice corner margins are native-scale; content padding
is independent. Standard `.png.import` size limits keep ornamental corners from
inflating minimum layout sizes. Nearest filtering belongs to art; UI fonts remain
smooth. The bowl strip keeps full resolution and its measured three regions.

`bowl-bases-v2.png` is the active shallow bowl strip: fine, curly and thick noodles,
without garnish. Actual selected toppings are separate layers, including repeats.
`bowl-bases.png` is the rejected deeper first generation, retained as provenance,
not used by the current bowl view. No illustrative green garnish is added unless
the actual recipe includes it. Existing ingredient and kitchen art is reused.

Fonts use original Pretendard Regular/Bold faces; provenance and full upstream OFL
are in `assets/fonts/`. Standard interface symbols remain licensed Material
Symbols Rounded. No third-party game artwork is shipped as a runtime asset.

Current real captures and source comparison:
`game/docs/uiux-reset/mock-fidelity-v1/`; bounded review: root `design-qa.md`.
