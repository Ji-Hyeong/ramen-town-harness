# Targeted correction: compact visible noodle choices

## TASK / OBSERVED FAILURE
The first actual implementation is not accepted yet. Every card is112px tall and every section uses two columns, so11options create7rows plus headings/duplicate lock paragraphs. This turns the four-depth problem into a long form. The accepted goal is compact same-sheet food-centered editing, not a larger scroll burden.

## REQUIREMENTS
- Keep the same ownership paths as tasks/development-cycle-v1.md and preserve behavior.
- Use one row per field:3columns for three options and2columns for water. Compact72-84px cards with an existing24-28px icon, short readable Korean caption and one14px price/lock line. Example short captions: 중력분/강력분/메밀분, 맑은 물/간수, 가는 면/중간 면/굵은 면, 기본/고가수/숙성. Keep exact full names and all traits in the existing optional disclosure/tooltip; no tiny type or text touching borders.
- Current selected food preview already carries actual aggregate facts; do not repeat unlocked per-card prose. Locked choices keep a short visible rank/source label. Remove duplicated per-section full red lock prose/sample-count rows from normal view; retain full conditions and current mountain stock in the optional disclosure. Raw source highlighting/navigation metadata must stay truthful.
- Keep current selection clearly shown, fixed preview/footer, actual disabled controls, short-profile scrolling and correct restore. No hidden legacy controls. Update comments that still claim four focused navigation depths.
- Adapt your tests if necessary, but do not claim visual acceptance or tests passed without running them (Bash intentionally unavailable).

## CONSTRAINTS / VERIFICATION
File-only tools; do not edit domain/controller/instructions/assets/other tests. Codex is waiting, no concurrent repository edits. Return changed paths, risks and NOT RUN test status. Codex will import and inspect actual native shots before accepting.
