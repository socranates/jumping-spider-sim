# Instars and hunger presentation — 2026-10-24

Nathan's latest direct decisions override the unlock examples in the copied Claude review:

- **Run after the second completed playable moult.**
- **Lock-on after the fifth completed playable moult.**
- Replace the hunger bar by a slowly encroaching red edge effect. Keep the spider and manual aiming area clear. A small, wordless bar remains an accessibility choice.

## Implemented candidate

The live growth ladder begins at instar 2. A saved seeded draw selects maturity at instar 7 or 8, so there are **five or six playable moults**, respectively. This corrects the copied review's stray “six or seven risks” sentence. The draw is independent of sex. New generations receive a deterministic child seed; a new life receives a fresh seed. Old lives migrate using seed 914. Loading an already drawn ladder never draws it again.

Normal goals start at **4 / 6 / 8 / 11 / 15 / 20**. A seven-instar life omits the middle 11-meal requirement, giving **4 / 6 / 8 / 15 / 20**. This omission is an implementation choice, not a biological finding. Easy/Free use **2 / 3 / 4 / 6 / 8 / 10**, omitting the corresponding middle requirement for an early maturer. These are game tuning.

The frozen Godot constants, reference fixtures, and unopted legacy Growth behavior stay unchanged. The live client uses `Growth.game.instars`. Adult eligibility, Easy unlocking and the notebook's adult event consult the growth object rather than assuming stage 3. Every completed moult changes the drawn size. Existing costume endpoints and collision geometry are retained; these interpolated drawing scales are not measured instar-specific carapace widths.

Old stages 0/1/2 map to instars 2/4/6. Old adults stay adult at their drawn maturity. Migration keeps consumed food credit, readiness, running moult duration, softness, old skins and earned abilities. In particular, an old stage-2 spider keeps lock-on even though new spiders now earn it later. Credit already sufficient under a smaller new goal readies the spider immediately. Source save records are not rewritten during inspection/restore.

The hunger effect uses four native UI gradients. Hunger changes their width and opacity smoothly in elapsed time; the central 36% of each viewport dimension stays untouched even at empty reserve. No flashing, pulse, camera squeeze, blur, image asset, or input interception. Menus, death and inspection suppress it. Settings → comfort → Hunger display chooses Closing red edges or Small bar. It is a hunger cue, not a new health system.

## Biology boundary

[Bailey's thesis](https://core.ac.uk/download/pdf/215221609.pdf), Table II, reports 15% maturing at seven instars and 85% at eight in its laboratory sample. This is the basis for the game's configured maturity distribution, not a claim about every wild bold jumper or the other species offered as costumes. The source table was located in indexed primary-source text; no full-thesis review is claimed. The later Vickers et al. feeding study independently identifies instar 1 as inside the sac; its methods and Table 1 are reviewed in [FEEDING-RESEARCH.md](FEEDING-RESEARCH.md). The lab result does not establish the proposed wild survivorship percentages.

## Remaining approved plan, in separate tested increments

1. Stage-sized prey populations and stage-relative meal currency. **This candidate still uses the existing housefly-equivalent food ledger and prey populations.** Do not call this part complete or silently relabel existing small-prey nutrition.
2. Early-instar starvation and predator pressure, plus meaningful retreat quality/dryness/disturbance hazards for each moult. These need visible causal feedback, deterministic saveable decisions and separate regression/native routes. Current retreat admission and soft-skin rules remain.
3. Calibrate art to the source's adult carapace dimensions with measured geometry and native collision/camera checks. This candidate adds per-instar drawing steps only.
4. Broader per-life ecology streams, followed by measured skilled/careless cohorts. Do not advertise a ~1% reproduction result from multiplying invented hazards or running a toy probability model. Nathan has not chosen the skilled target yet.
5. Carry/Follow immediate rejoin policy, late navigation work, corrupt-slot recovery, natural predator attacks, whole-map collision and the rest of the ongoing optimization audit remain open.

## Verification and release boundary

`instars.luau` covers both maturity draws, the whole ladder, exact thresholds, delayed abilities, interrupted moults, deterministic restore, new generations, legacy migration/readiness, malformed records and repeated-frame drawing work. `checkpoint.luau` also sends extended stages/skins through the actual object graph and validator. `hunger_veil.luau` checks bounds, monotonic pressure, fallback, suppression and 30/60/144 FPS transitions. Existing live-client fixtures use the new ladder; frozen fixtures are unchanged.

See accompanying verification receipts for actual outcomes. The native playback is explicitly synthetic food credit in unbound Studio/memory; it does not prove hunting difficulty, natural survival, online persistence or FPS. No publication of this candidate is implied by coding or local testing.
