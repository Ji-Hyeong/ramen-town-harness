# Mountain ingredient asset provenance

## Buckwheat ingredient bundle refinement

Saved asset: assets/ui/bowl-editor/noodle_buckwheat-v1.png, copied byte-for-byte from exec-1c8caee5-300d-4d30-a76d-89617b748c0b.png in the same generated folder. Size1536x1024, measured opaque crop x340 y200 w950 h699. Reference: existing assets/ui/mock-fidelity/summary-icons-v1.png. The generated source has an exterior translucent brown haze despite the request; food_alpha_cutout.gdshader clips only this marked new texture at0.94. Existing artwork receives no material override. The same real bundle is used in exploration, detail, selector and current noodle header.

Use case: precise-object-edit. Reference contains a soup pot and a golden wheat noodle bundle; it is a STYLE and GEOMETRY reference only. Create ONE isolated ingredient icon: a small folded rectangular bundle of raw slender BUCKWHEAT NOODLES, warm gray-brown/taupe with subtle dark buckwheat speckles. Preserve the low oblique view, folded strand loops, chunky readable pixel-art texture and compact silhouette of the RIGHT-hand noodle bundle, but make the noodle color clearly earthy gray-brown rather than yellow wheat. No soup pot, no bowl, no second object, no steam, no ground or cast shadow, no text, no glow, no haze. Center one bundle with ample real transparent alpha padding; crisp opaque silhouette, no semitransparent exterior pixels. Make the mass and individual strands readable at 48 pixels.


Mode: built-in imagegen (no CLI/API key). The original existing images remain unchanged. New files were copied byte-for-byte from the generated results; no Python pixel edits were made.

| Saved project asset | Generated source | Size / measured opaque crop |
|---|---|---|
| assets/ui/bowl-editor/base-bowl-buckwheat-v1.png | exec-5159dca6-3122-4b8d-b850-0b8a1d900e42.png | 1536x1024; x175 y165 w1186 h719 |
| assets/ui/bowl-editor/topping_grilled_shiitake-v1.png | exec-e2d5ce39-96f5-498b-b04f-1b61bb5e4990.png | 1484x1060; x281 y231 w947 h642 |

Local generated originals are under ~/.codex/generated_images/01a13392-6c1a-77b0-89a1-70e9ea69d3a4/. The first bowl result exec-a1f03cc2-9d24-4fe0-a768-0fd047da1427.png is preserved privately and is not the selected asset.

The bowl edit still contains a semitransparent red exterior halo. The new bowl alone uses a display alpha threshold0.94 and the measured crop; no source image is falsely described as clean alpha. Existing sprites keep threshold0 and retain their old rendering. The original shiitake cluster is also sampled by nearest interpolation for the small service dishes; each selected portion remains a separate visible cluster.

Reference images: assets/ui/mock-fidelity/bowl-bases-v2.png (existing bowl geometry/style) and assets/ui/bowl-editor/topping_mushroom.png (existing art style, not copied subject). Full prompts below record intentional generation; no artist identity or reference-game assets are reproduced.

## Bowl generation

Use case: precise-object-edit. Asset type: transparent original food-game bowl base. Input image is a STYLE/GEOMETRY REFERENCE ONLY, a row of three existing ramen bowls. Create ONE single matching red-and-white ceramic ramen bowl, identical low oblique/isometric front view and wide elliptical silhouette to the LEFT bowl. Keep the ceramic red-white bands, lighting, original crunchy pixel/dither illustration style, and warm clear golden broth. Replace the wheat noodles with distinct slender gray-brown buckwheat noodles, slightly speckled, many visible strands. NO toppings, no steam, no chopsticks, no decorations or text. Center the entire one bowl horizontally, keep all rim and foot visible, about 78% canvas width with comfortable transparent padding. Real alpha background, no drawn checkerboard, no ground shadow. Do not create a row or sheet; only one bowl. Crisp original pixel-art food texture, not photorealistic.

## Shiitake generation

Use case: stylized-concept. Asset type: one transparent food-game topping sprite. Input mushroom image is STYLE REFERENCE ONLY. Create one small cluster of TWO whole flame-grilled shiitake mushroom caps with short pale stems, deep chestnut-brown caramelized rounded caps, one shallow X-shaped cut on top of each, subtle golden sear highlights. Both caps clear and chunky enough to read at 48 pixels, overlapping slightly, low oblique/isometric front view compatible with ramen topping art. Match the reference's crunchy pixel/dither illustration and warm palette. Do not produce the reference pile of sliced mushrooms. No bowl, plate, leaves, steam, lettering, border, ground or shadow. Center isolated cluster around 70% width with ample truly transparent alpha margin. No checkerboard or photorealism.

## Bowl edit

Use case: background-extraction. This is the EDIT TARGET. Preserve the exact existing single buckwheat noodle bowl pixel art, colors, noodle shape and ceramic silhouette. Remove ALL red glow, red haze, cast shadow, background specks and every visible or semitransparent pixel outside the ceramic bowl silhouette. Everything outside the bowl must be real fully transparent alpha 0. No background color and no checkerboard. Keep the rim, ceramic body and foot crisp, and preserve all interior noodles and soup unchanged. Keep a comfortably padded canvas. Output a clean game sprite with no soft surrounding halo.
