# TASK
Same menu-identity session412352bc-fb9e-4da0-b053-acc11c14cbe4, final bounded
visual correction from actual native captures. Initial full native953/0/48PNG,
service479/0,journey449/0,cycle280/0,goals965/0 all pass with engine0.

## OBSERVED
MenuIdentityCard._food uses the old Pixel.icon_image fallback for ordinary
noodle_thin/medium/thick. At32px it is a cream rectangle with yellow dots, unlike
the real original noodle bundle used in the existing workbench. Actual portrait
cards at first/rich tasting show this low-detail rectangle between pot and topping.
The original Mock.texture("noodles") is already the existing noodle-bundle asset.

## EXPECTED / OWNERSHIP
- Edit ONLY game/scripts/ui/menu_identity_card.gd and, if needed, its focused
  existing game/tests/menu_identity_tests.gd.
- Keep buckwheat's Art.food special case. Add a noodle_ branch using the existing
  Mock.texture("noodles") for the ordinary wheat variants, before the generic
  Pixel fallback. No generated/redrawn image or asset edits, no unrelated changes.
- Add a focused regression that ordinary noodle art uses this exact source texture
  and buckwheat keeps its original existing texture. No broad test rewrite.
- Do not touch projection, Codex integration, controllers, QA fixtures, other docs
  or UIDs. File-only restricted/dontAsk/empty MCP/no outside reads/Bash/network/Git
  still apply. Codex keeps repo writers serial and reruns final actual captures.

## VERIFICATION
Tests are NOT RUN by Claude. Return compact changed files/decision/UNRUN/denials.
This is an actual observed artwork correction, not a new task or a new design.
