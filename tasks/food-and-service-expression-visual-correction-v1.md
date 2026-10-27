# Targeted correction: actual native food differences are too weak

Codex imported/exported and ran the real GPU fixture. Appearance63/0 and service observer13/0 pass after Codex corrected the kelp/scallion test to consider actual oil identity, not broth base color only. Native food/service274/0 passes behavior, BUT the food pixels are not accepted visually: clear, creamy bone, chili and herb all still look overwhelmingly like the same orange broth. Passing scalar parameter tests does not satisfy the task.

Read the actual native PNGs:
/private/tmp/ramen-food-and-service-qa-20261028-v1/native-food-service/captures/portrait_food_clear.png
/private/tmp/ramen-food-and-service-qa-20261028-v1/native-food-service/captures/portrait_food_bone.png
/private/tmp/ramen-food-and-service-qa-20261028-v1/native-food-service/captures/portrait_food_chili.png
/private/tmp/ramen-food-and-service-qa-20261028-v1/native-food-service/captures/portrait_food_herb.png

Correct only the same four owned food files. Strengthen actual masking/recoloring enough that a pale creamy bone soup, clearer golden/kelp soup and chili-red oil surface read distinctly at390px. Preserve the red ceramic, original texture/shading, real noodle appearance, independently layered toppings and transparent exterior. No flat filled primitive bowl/whole-sprite tint/new assets. The current luma/ceramic guards appear to exclude much of the orange soup; inspect the existing source and native evidence rather than simply weakening tests. Keep legacy and mixed-bowl safety, explicit raw validation and profile API.

Codex owns other files now, but is waiting without concurrent edits. Do not modify shop/pixel_art/domain/tests outside the original food ownership, instructions or assets. File-only, no execution/network/Git/subagents. Return exact changes, limitations and tests NOT RUN. Codex will re-run and inspect actual new pixels.
