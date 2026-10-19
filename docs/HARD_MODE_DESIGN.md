# Hard mode — proposed next chunk

Nathan requested an optional harder life on 2026-10-18, alongside a clearer meal count and slightly faster energy drain in normal play. This is a concrete design, **not enabled or implemented in this build**. Keep normal play welcoming for the kids.

> **Rebased 2026-10-19 on the current numbers.** The first draft (2026-10-18) measured Hard against a Normal that has since moved: the hunger drain went from 1.1 times the original LIFE rates to 1.55 (ROBLOX-78) and then **1.9** (ROBLOX-88, so a game day costs **0.612** energy), the food for a moult from three housefly-equivalents to **five** (ROBLOX-88), the wasp from one visit a day to **two** (ROBLOX-75), and the food bar became a **hunger bar** (ROBLOX-78). The tables below use the current figures, and the first draft's are kept in brackets, marked *superseded*, so no one finds them elsewhere and thinks them live. ROBLOX-63, which points here for "50% greater food demand than revised Normal", is stale in the same way and says so. Also in the game now, and relevant to a harder life: the rival is a contest and a long grip fight (ROBLOX-73, -77, -88), a mate and a mating cycle exist, gated on a full-grown spider with the hunger bar at 60% or more (ROBLOX-79), and Easy and Free play have their own gentle pacing and their own rest slot (ROBLOX-91).

## Rules to start with

| System | Normal now | Proposed Hard |
| --- | --- | --- |
| Hunger drain | **1.9 times the original LIFE rates**: 0.612 energy per game day (11 waking hours at 0.021 plus 13 asleep at 0.007, times 1.9) *[superseded: 1.1 times, 0.354 a day]* | More than Normal; the size of the step is open, see "How much harder" below |
| Full housefly food | 0.35 | Same; small fruit prey is 0.175 (half a housefly) |
| Food for next moult | **5** housefly-equivalent meals (10 small prey), 1.5 in the units of the food ledger *[superseded: 3 meals, 6 small prey]* | Same, to avoid making growth a grind |
| Fly capture radius | Prey 0.45 + spider radius | Prey 0.40 + spider radius, the earlier accepted tolerance |
| Fly awareness gain | Current profile | Start at 1.10 times current; tune in play before accepting |
| Wasp warning | At least 8 seconds | Same clear warning, caption and sound |
| Wasp inspection before lunge | 1.2 seconds (1.5 times the 0.8 of `Wasp.game`) | Try 85% of current duration, with at least 0.9 seconds to react |
| Visits | **Two a day**, one in 09:30 to 12:00 and one in 13:30 to 16:30; never the first day, before the first meal, or during a rest *[superseded: at most once a day, 10:00 to 15:30]* | Same two windows and the same protections |
| The rival | Aware rival, struck: 40% caught, 32% sprang clear, 28% counter-bite (0.30 energy); a caught rival is a grip fight that needs about 4.5 taps a second or more | Same in the first Hard; do not stack more on the rival |
| Mating | A full-grown spider with the hunger bar at 60% or more at a rest in the crack | Same gate (it is harder to reach at Hard's drain, which is part of the point) |
| Easy and Free play | Their own pacing: drain 1.1 with the gentle half rate (0.177 a day), three flies a moult, contest 55 / 25 / 20, no counter-bite cost | Unchanged; Hard never touches them |
| Retreat | Safe | Always safe |
| Jump, dragline, camera | Current mechanics | Identical reliability and controls |

### How much harder

At the game's day (11 waking hours, 13 asleep), Normal consumes 0.612 energy, so one whole housefly covers about 0.57 of a day, a full reserve lasts 1.63 days and holding steady takes about 1.75 houseflies a day, with five more to grow. The first draft's "50% more food per game day than Normal" is still a number, but on top of 1.9 it is a hard game: 2.85 times the original rates, 0.918 a day, a housefly worth 0.38 of a day, a full reserve gone in 1.09 days, 2.6 houseflies a day just to hold steady. Against the aim below (a cautious player can recover from a missed catch without an inevitable starvation spiral) that leaves almost no slack. A smaller step to try first is **25% more**: 2.375 times the original, 0.765 a day, a housefly worth 0.46 of a day, a full reserve lasting 1.31 days, about 2.2 houseflies a day to hold steady. It is one number (`NeedsModel.game.drain` is 1.9 for Normal; Hard would carry its own), so the choice is cheap to change after a playtest. These are game tuning, not a claim about real feeding frequency. Hunger never advances while offline.

*[Superseded first draft: at a representative 16 hours awake and 8 asleep, Normal consumed 0.4312 energy per game day and Hard would have consumed 0.6468; a housefly covered approximately 0.81 Normal days and 0.54 Hard days. Those figures were for the 1.1 drain and a 16-hour day; neither is the game's.]*

Keep the soft-cuticle slowdown and shorter jumps, but do not stack an extra Hard-only movement penalty on moulting. Keep the visible hunger bar, meal progress ("of 5 meals"), landing preview and notebook. Reduced Motion, large text, captions and automatic grip stay available in Hard without a penalty. No extra gore or surprise attacks.

## Start, saves and recovery

Offer Hard from the start menu as an explicit new-life choice with a short rules comparison and Back. It is not a paid feature. Label the HUD HARD throughout the life. Preserve Normal, Easy and Free-play rests; use a separate Hard rest slot, a fourth beside main, free and easy (the slots are keyed by the rules through `SaveRules.slotOf(mode, rules)`, ROBLOX-91, so Hard is one more case there and in the server's key list). Never reinterpret a Normal checkpoint as Hard just because a setting changed.

Keep both recovery choices (last rest / another spider) and the notebook across lives. No permadeath, deleted saves, exclusive cosmetic or required grind. A completed Hard life may get a modest notebook record. Changing difficulty mid-life should return to the menu and start/resume the corresponding slot, with an explicit explanation, rather than silently changing the current save.

## Implementation and acceptance

1. Centralize named rule profiles (Normal, Easy, Free, Hard) instead of scattered multipliers. The game's rules now live in five tables applied by `useGameRules` (`NeedsModel.game`, `Growth.game`, `Data/Catch.game` and `Catch.rival`, `Data/Wasp.game`, the contest numbers in `Data/RivalRules`), most of them with a gentle variant chosen by the same flag; a profile should gather those, not add a sixth place. Derive fly/wasp tuning from the profiles without mutating shared Species tables.
2. Extend LifeSession, checkpoint validation, PlayerProgress and server SaveService allowlists together. Version and migrate the save format; old saves (main, free, easy) retain their contents. Test newer-version rejection and failed-load no-write behavior. Do not add a Hard menu button before its save slot is safe.
3. Add deterministic rule tests at 30/60/144 render fps, exact food budgets, partial meals, soft-skin transitions, no offline drain and the twice-a-day wasp limit. Keep the frozen Godot golden fixtures as original-rate reference tests.
4. Verify all recovery choices and four independent rest slots through the isolated real DataStore test experience. Test gamepad focus and short-phone layouts.
5. Play one whole life on PlayStation. A cautious player should be able to recover from a missed catch without an inevitable starvation spiral. Keep warning and retreat rules fixed while tuning hunger/awareness first.

Suggested delivery: ship separate saves + hunger-only Hard first, then add the modest prey/wasp tuning only after Nathan tries it. No public-release, pricing or account changes are part of this design.
