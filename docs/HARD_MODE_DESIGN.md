# Hard mode — proposed next chunk

Nathan requested an optional harder life on 2026-10-18, alongside a clearer meal count and slightly faster energy drain in normal play. This is a concrete design, **not enabled or implemented in this build**. Keep normal play welcoming for the kids.

## Rules to start with

| System | Normal after this update | Proposed Hard |
| --- | --- | --- |
| Hunger drain | 1.1 times the original LIFE rates | 1.65 times original: 50% more food per game day than Normal |
| Full housefly food | 0.35 | Same; small fruit prey is 0.175 (half a housefly) |
| Food for next moult | 3 housefly-equivalent meals (6 small prey) | Same, to avoid making growth a grind |
| Fly capture radius | Prey 0.45 + spider radius | Prey 0.40 + spider radius, the earlier accepted tolerance |
| Fly awareness gain | Current profile | Start at 1.10 times current; tune in play before accepting |
| Wasp warning | At least 8 seconds | Same clear warning, caption and sound |
| Wasp inspection before lunge | Current duration | Try 85% of current duration, with at least 0.9 seconds to react |
| Visits | At most once per day | Same limit; never first day, before first meal, or during rest |
| Retreat | Safe | Always safe |
| Jump, dragline, camera | Current mechanics | Identical reliability and controls |

At a representative 16 hours awake / 8 asleep, Normal consumes 0.4312 energy per game day; Hard would consume 0.6468. One whole housefly therefore covers approximately 0.81 Normal days versus 0.54 Hard days. These are game tuning, not a claim about real feeding frequency. Hunger never advances while offline.

Keep the soft-cuticle slowdown and shorter jumps, but do not stack an extra Hard-only movement penalty on moulting. Keep the visible food bar, meal progress, landing preview and notebook. Reduced Motion, large text, captions and automatic grip stay available in Hard without a penalty. No extra gore or surprise attacks.

## Start, saves and recovery

Offer Hard from the start menu as an explicit new-life choice with a short rules comparison and Back. It is not a paid feature. Label the HUD HARD throughout the life. Preserve Normal and Free-play rests; use a separate Hard rest slot. Never reinterpret a Normal checkpoint as Hard just because a setting changed.

Keep both recovery choices (last rest / another spider) and the notebook across lives. No permadeath, deleted saves, exclusive cosmetic or required grind. A completed Hard life may get a modest notebook record. Changing difficulty mid-life should return to the menu and start/resume the corresponding slot, with an explicit explanation, rather than silently changing the current save.

## Implementation and acceptance

1. Centralize named rule profiles (Normal, Easy, Free, Hard) instead of scattered multipliers. Derive fly/wasp tuning from those profiles without mutating shared Species tables.
2. Extend LifeSession, checkpoint validation, PlayerProgress and server SaveService allowlists together. Version and migrate the save format; old two-slot saves retain their contents. Test newer-version rejection and failed-load no-write behavior. Do not add a Hard menu button before its save slot is safe.
3. Add deterministic rule tests at 30/60/144 render fps, exact food budgets, partial meals, soft-skin transitions, no offline drain and once-per-day wasp limits. Keep the frozen Godot golden fixtures as original-rate reference tests.
4. Verify all recovery choices and three independent rest slots through the isolated real DataStore test experience. Test gamepad focus and short-phone layouts.
5. Play one whole life on PlayStation. A cautious player should be able to recover from a missed catch without an inevitable starvation spiral. Keep warning and retreat rules fixed while tuning hunger/awareness first.

Suggested delivery: ship separate saves + hunger-only Hard first, then add the modest prey/wasp tuning only after Nathan tries it. No public-release, pricing or account changes are part of this design.
