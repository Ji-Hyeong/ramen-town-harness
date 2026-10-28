# Targeted correction to first-menu-journey-v1

The initial independent import and kitchen_journey_tests pass184/0, exit0,
engine0. Preserve that behavior and the same three-file ownership; Codex has not
started integration. Apply only these focused usability/integration corrections:

1. journey_card currently preloads service_result_view for its button factory.
   Integration must also use JourneyCard inside service_result_view. This would
   create a static preload cycle. Reuse the factory through a narrowly scoped
   runtime load inside card initialization (with a precise dependency comment),
   or an equally small solution confined to your three files. Do not edit the
   service result/factory or introduce an extra file.
2. Held teal button styles do not recolor the overlaid child Labels/chevron.
   Connect button down/up so real held-state text/arrow become white, then restore
   INK/MUTED on release/cancel. Test the two color states; no early navigation.
3. The human dislikes verbose instruction text. Shorten actual copy: first goal
   should be a qualitative culinary preference tied to the actual customer's
   catalog data (e.g. a rich, hearty soup for Dohyun), not a paragraph of safety
   instructions or a numeric9/10 target. Keep first-stage hints to a short taste
   brief plus current activity. First-sales hint can simply ask to check the
   selling menu and price. Improvement hint should identify its actual tasting
   record/version and customer's observed score in one or two short clauses.
   Use concise nouns for explore/research. Do not imply a visited customer,
   promise higher sales or reveal undiscovered compatibility.
4. Invalid/unusable state must show an explicit unavailable explanation rather
   than a silent success-like perpetual preparing label. Keep it disabled.

Same file-only restricted/dontAsk/emptyMCP/no Bash permissions and max10 turns.
Tests remain NOT RUN for you; report changed paths and exact unrun commands.
Do not inspect outside-project screenshots or change instructions/docs/domain.
