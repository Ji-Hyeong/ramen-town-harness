# TASK
Make ramen development responsive and rewarding, and support rank-scaled topping
portions including multiple portions of the same ingredient.

## CONTEXT
User accepted the prior touch fix on iPhone, but rejects bland interactions and
menu development. Existing unique-only toppings require rank AND bench, hiding
progression. Start from main0f87d7c. Codex implements this bounded milestone.

## REQUIREMENTS
- Explicit visible topping positions: select position, add/replace ingredient,
  remove a portion (minimum one), show locked future positions and unlock rank.
  Multiple positions may hold the same ingredient. Rank alone unlocks positions;
  bench purchases retain menu-family capacity benefits. User confirmed rank1=2, rank2=3, rank3=4 positions.
- Each portion contributes its real taste axes, cost, prep and sample use.
  Preserve deterministic synergy once per rule rather than stacking free bonuses.
- Visible click/selection/rejection feedback, ingredient burst and recipe change
  feedback; cooking/tasting payoff must be on the currently visible screen.
  Show actual flavor differences/compatibility, not invented luck or free scores.
- Preserve existing swipe-anywhere/tap cancellation and desktop input. Cosmetic
  effects ignore input, expire and cannot charge money or duplicate results.
- Bump save version for repeats/new capacity; preserve all supported old values
  and real old scoring, immutable witnesses, backups. Reject forged old repeats.
- Actual relevant tests and fresh iPhone signed update preserving own app saves;
  public ready PR/main merge under standing authorization after verified scope.

## CONSTRAINTS
Editable: topping/catalog/check/growth/state/foraging and necessary recipe art,
UI/effects, focused and relevant existing tests, docs/evidence/AGENTS. No unrelated
new systems, security changes, cloud publishing or live Mac save writes. Keep
private device/team/profile/save data out of Git. Old app/builds stay preserved.

## ACCEPTANCE CRITERIA
Repeated/mixed topping positions are editable and persisted, rank gating clear;
portion costs/time/sample consumption are correct and atomic. Existing flavor
results remain identical for old configurations. Real visible effects react to
committed input and cooking/result milestones, not canceled swipes. Regression,
legacy migration, actual rendering/input checks pass; physical feel feedback
reported honestly and separately.

## VERIFICATION
Frozen previous source/save fixtures, domain and focused portion tests, two-size
routed/native touch tests and layout. Fresh native render samples/effects frames,
actual iPhone build/profile/PCK/source checks, same-bundle install + save backup
and byte preservation, actual screen observation. No offset-only touch claims.
