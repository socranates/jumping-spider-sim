# Claude's quick review of Chet's pause point — 2026-10-24

This answers `chet/QUICK-REVIEW-2026-10-24.md`. Reviewed: `codex/verified-integration`, source/test commit 3f6ed48 (HEAD aeb6cf2 is docs only), read only:
nothing was edited, built, run, merged or published. Three parallel read-only reviews fed this, and I spot-checked the key lines by hand.
Findings are cited by file:function:line.

## 0. Since v48 (catch-up)

About 305 commits on 10-22 to 10-24.

- **Save system rebuilt and qualified:**
  - leases, typed requests and admission
  - New life reaches the server
  - a read-only preview when another session holds the lock
  - corrupt rests confined to their own slot
  - rest compression, with `MAX_REST_CHARS` raised to 5,000,000
- **Toolchain:** CI pinned. All six silently-passing suites now fail properly. 80 suites are green in CI 40102350037.
- **Bugs fixed:**
  - Predators and drowning could not end a Normal life (`LifeSession` refused those causes).
  - The final Eat tap in the Crack also started Rest.
- **Startup and performance:**
  - startup timing and collision-ready startup without waiting for decoration
  - cached leg-hair orientations
  - hut path shoulders repaired
  - camera field of view restored
  - a 30-minute garden traversal
- **Native female reproductive route in Normal, Easy and Free:** court, mate, sac, guard, hatch and continue, with 90 meals and 9 moults.
- The broad audit is paused. No new public release: the private test place is still v14.

Of my 10-22 foundation review: six suites → **fixed**; rest size cap → **fixed**, though headroom is proven only on the small default rest;
New life → **fixed**; quick rejoin → **fixed** on the new protocol; corrupt rest → **partly** (the slot stays unwritable and New is refused for
it on every reload; a corrupt *progress* record still makes the visit session-only); wall-clock route deadlines → **partly** (StationAir is
fixed; RivalRoute and NavigationPreparation still use `os.clock`; play is held until loading finishes, but a region requested after startup may
never be prepared because nothing calls `Route.advance` later).

## 1. Do the female-route receipts hold? Yes, within their stated limits

The order of events in native.json matches the claims: refusal then acceptance in Normal, sac, guard day 2, restore, hatch, card, generation and
restore in each mode. I found no overclaiming. These gaps remain:

- **Major — rests after hatching are untested.** Rests are refused while `hatched` (`Checkpoint.luau:250`), so the rest a player actually
  returns to is the hatch-morning `guarding` rest. Nothing restores it. After Carry, `carryOn` only marks the save dirty
  (`SpiderClient:1134, 1155`): until the newborn's first rest, a rejoin or "Back to your last rest" returns to the parent and **hatches
  again**. Notebook entries may also duplicate (`:1009, :1154`).
  - Test: Carry, then rejoin before the newborn rests → expect the newborn, or a defined rule; never a second hatch.
- **Minor — guarded returns only on guard day 2.** All three were taken after a scripted `refill()` (`playback.luau:228-235`). There is no
  return on sac day 1.
- **Minor — no natural starvation evidence while guarding.** In Normal she wakes on guard mornings at energy 0.17–0.18 and survives only
  through scripted refills.
- **Minor — Free/Follow landing zone not checked.** The newborn is sent `home()` before it rests, and events carry no region.

## 2. The male currently lays eggs — needs a sex gate now (major)

`Mating.woke` (`Mating.luau:126-132`) turns any `mated` into `sac` with no sex check. Everything downstream keys on `stage` alone: guard days and
hatching, the sac drawing, the guard line, Carry/Follow and `carryOn`, notebook goals and the recovery text.

**Reproduction:** play the peacock male (free), court a female (`client_mating.luau:1103` already does this), rest and sleep. Next morning
there is a sac.

**Two related holes:**
- **The appearance isn't stored in the rest.** It comes from a Player attribute (`SpiderClient:207`), so a female sac rest restores as a male
  one.
- **The spider can be changed during sac and guarding.** `spiderPick.occupied` (`:618`) doesn't block it.

**Minimal gate,** which does not invent the male continuation:
1. Record the player's sex in the mating record at mating. Treat a missing value as female, so old saves load.
2. `woke` returns "" unless the recorded sex is female.
3. `Mating.problems` refuses sac, guarding or hatched records whose recorded sex is male.
4. Block the spider change from mated to hatched, or bind the sex to the rest.
5. **Open: a mated male is stuck today.** A plain `mated` blocks `mayArrive` forever (`Mating.luau:210`). Where he goes next is the design
   in `claude/male-female-playthroughs.md`, and Nathan decides.

**Tests:**
- a pure test: a male's `woke` returns "" and his record stays as it was
- a client test: a male sleeps after mating, with no sac and no guard line
- restoring a female sac rest while the male is selected

## 3. Normal 7 → 15 → 20: edge cases to cover before coding

**Facts:**
- There are three moults (`Growth.ADULT=3`). Stage 0 uses `firstMoultFlies` (7) in every mode.
- Stage 1 uses `secondMoultFlies` (10) in every mode today. Normal must become 15 while Easy and Free stay 10, so `readyAt` needs a gentle-aware
  stage-1 branch.
- Stage 2 uses `moultFlies`/`gentleMoultFlies` (Normal 5 → 20; gentle stays 3).
- Suggested table: `Growth.game = {firstMoultFlies=7, secondMoultFlies=15, gentleSecondMoultFlies=10, moultFlies=20,
  gentleMoultFlies=3}`. The Godot golden defaults are untouched (`growth_reference.json` never applies game rules).

**Findings:**
- **Major — `Growth.eat` un-readies a preserved-ready save** (`Growth.luau:62-68`, confirmed). `ready` is recomputed on every meal, and eating
  while ready is allowed. Example: a Normal stage-1 save at 10 meals that is ready loads ready, then one more fly makes it *not ready*
  ("11/15").
  - Fix: make ready sticky, `self.ready = self.ready or fed >= readyAt()-1e-9`. No golden step goes from ready back to not-ready.
- **Minor — recovery copies a stale `readyFood`.** It copies 1.5 (5 meals) into a recovered stage-2 life (`RecoveryLifePrototype:38, 86`). The
  client re-applies rules only when `gameRules ~= true` (`SpiderClient:2397`).
  - Fix: derive the goal in `readyAt` from `Growth.game` plus a stored gentle flag, not a cached number. Add any new field to the GROWTH
    whitelist.
- **Minor — `Mating.carryOn` drops the rules.** It calls `Growth.new()` without rules (`:285`). This is harmless today because stage 0 is 7
  everywhere; copy the parent's rules anyway.
- **Minor — hard-coded "5"** in comments and text: `Growth.luau:14-15`, `SpiderClient:304`, `Nursery.luau:7-8` ("five houseflies'"),
  `QuietHud.luau:30`, `LifeText:269`.
- **Validators:** do **not** add a "fed vs threshold" check to `Growth.problems`. It would reject legitimate preserved-ready saves.

**Tests that change:**
- `growth.luau`: 160, 163, 165-183, 188, 197, 200-203, 221, 234-249.
- `minimal_hud.luau`: 15, 21, 92.
- The first-moult 7 tests are unchanged.
- **Leave the evidence scripts pinning 7/10/5 alone** (playback, collect, qualify), and don't relabel them.

**Edge-case test list:**
1. Normal from fresh: not ready at 6/14/19 meals; ready at 7/15/20; then adult. Easy and Free stay 7/10/3.
2. Fractional prey crossing the 4.5 and 6.0 boundaries (0.15, 0.6 and 0.9 meals), within the 1e-9 tolerance. The counter reads "14.5/15".
3. A Normal stage-1 save at 12 meals, not ready: loads as "12/15"; three more flies make it ready.
4. The same save already ready: stays ready after load **and after eating** (the sticky fix).
5. A Normal stage-2 save at 5 meals, ready: still moults. At 4 meals, not ready: reads "4/20".
6. A moult in progress or the soft period at stage 1 or 2: it completes, and the next goal is the new one.
7. A legacy gentle life in the main slot uses 10/3. Main vs Easy vs Free slots stay separate.
8. In one session: Normal → New Easy → Continue main re-derives 15 → 7 → 15, with no leak through the `gameRules` short-circuit.
9. A Normal adult's newborn (`carryOn` and RecoveryTemplates): 7, then 15.
10. A recovered stage-2 Normal life with a stored `readyFood` of 1.5: the goal is 20.
11. `Growth.problems` still accepts fed above the threshold and ready below it.
12. Unlocks unchanged: run from stage 1, lock from stage 2, neither while moulting.
13. The Godot golden is unchanged.
14. The counter and quiet text show 15 and 20, and an adult shows nil.

**Side effect to tell Nathan:** reaching adulthood in Normal, which also unlocks Easy, now takes 42 meals instead of 22.

## 4. Spiders walking through each other after mating: smallest safe fix

**Root cause (critical).** No motor knows about another spider's body:
- Every `SpiderMotor` queries only `{config.world}` (`SpiderMotor.luau:83-88`).
- The rigs are `CanCollide=false` and `CanQuery=false` (`SpiderRig.luau:195-196`).
- The leaving mate walks a straight exit route through wherever the player stands (`MateDrive.luau:64-71` → `RivalDrive._wish:350-399`).

**When it happens:**
- **Male mate, ordinary end:** the player stands idle while the mate walks through them.
- **Female mate, ordinary end:** controls return about 2 studs from her, so pressing forward walks into her, and she walks through the player.
- **Skipped scene (either sex), and the wasp's or rival's forced skips:** the controls free at once at attend range.
- **Before mating:** `Mate.conditions` has no minimum distance, so a scene can start already overlapped.

**Latent trap.** A blocked leaving mate loses its exit. After 4 s stuck, `RivalDrive._think:335-340` clears the goal and it patrols randomly
until the 120 s timeout. Nudging `mate.position` from outside resets route and goal (`RivalDrive.update:459`). So the fix belongs inside the
motor, not as a position nudge or a teleport.

**Smallest safe fix:**
1. **`SpiderMotor` optional `avoid = {pos, up, radius, steer?}`,** only in `_tickAttached`, and only when both bodies are attached and coplanar:
   `up·up' > cos 25°` and `|offset·up| < 0.25`. If the next step would come closer than `radius`, remove only the **inward** part of the
   movement. Outward and sideways moves stay free, so overlapped bodies separate at walking speed. Nothing pushes the player, so there is no
   jitter and no shove off a ledge.
2. **The mate gets `steer=true`:** when blocked head-on, it walks round on a fixed side, dropping that side if it would enter the retreat
   keep-out. The rival leaves `avoid` nil, so its behaviour is unchanged.
3. **`MateDrive`:** while leaving, re-set the exit goal whenever it was cleared.
4. **Client:** pass the mate's motor `pos`/`up` as the player's `avoid` while the mate is present, in `tickInput`. The player's motor ticks
   before the mate's.
5. **Radius:** body half-lengths only, times about 0.85: about 1.15 studs for the adult first spider and the male mate, about 0.6 for the
   peacock pair. Never leg span: two leg spans add up to about 2.2, which is more than `attendWu` (2.0) and would break courtship.

**Concerns:**
- Across a floor-to-wall seam the coplanar test switches off. Either document that, or add a small 3D sphere fallback.
- Steering at a convex edge could carry the mate into the air. Test it.

**CLI tests** (`mating.luau` legs harness, with a real second motor for the player):
- Departure with the player on the mate's exit line, male and female, ordinary end and skip: the planar gap stays at least `R−0.02` every tick,
  the mate reaches its exit (not the timeout), and `resets` doesn't change.
- Player walking into the mate: stops at R; outward is full speed; sideways slides; no oscillation.
- Starting overlapped: they separate.
- Different planes (wall vs floor): unaffected.
- A ledge: the player stays attached.
- The keep-out: the mate goes round, never through.
- Blocked for 6 s: the mate keeps its exit and leaves once the player moves.
- `client_mating:791-793` walks Forward toward the mate and may need a different direction.

**Native gate:** the playback route twice, first spider (male mate) and peacock (female mate), each with an ordinary end and a skip at about
4.5 s. Script only the player's placement on the mate's exit line, then hold Forward toward the mate for 3 s. Each frame, log the planar gap and
any rig overlap. Assert the gap stays at least R−0.05, the mate leaves "mated" by reaching its exit, and there are zero script errors. Take
screenshots at the closest approach and at a wall seam.

## 5. Nathan's new direction for Normal: skill, then the luck of the draw

Nathan, 2026-10-24: **"It should not be easy on the normal mode to 'win'. It should be like life. Heavily dependant on the application of skill
and much more dependant on the luck of the draw."**

The 7/15/20 thresholds serve the skill side. The luck side needs one structural fix:

- **Every life draws from the same luck (major, design).** The world seed is a constant: `WorldMap.SEED = 914` (`WorldMap.luau:92`), used by
  the server, the client and every checkpoint. Prey, the wasp, the rival and the mate's acceptance draw from that seed with the day and
  counters, and only some streams mix in the generation (e.g. `Ballooning.stream`). So a new Normal life largely replays the same fortunes:
  the same lean days, the same wasp mornings.
  - Proposal: a **per-life seed**, drawn when a life begins (and for each new generation) and stored in the life record (optional, defaulting
    to 914 for old saves). Mix it into every *life* draw: prey abundance and kinds, weather fronts, predator schedules, mate visits and
    acceptance, ballooning, rare sightings. World geometry and region seeds stay on 914, because saves and walkable boxes rely on them.
  - Draws stay seeded and deterministic: a restore never rerolls.
  - Confirm with Chet which streams already include the generation.
- **Variance with meaning (proposals for Nathan):**
  - Lean and fat seasons by the per-life seed: some lives start in a good fly year, some in a drought.
  - Weather streaks.
  - Predator pressure that varies by life, e.g. a robin pair nesting nearby one year.
  - A mate who may never come in a given life.
  - Skill still decides the outcome within a hand: hunting accuracy, shelter choice, when to rest, reading the rival.
  - Normal never tells you the odds. The notebook can reflect on luck afterwards, which fits the game's philosophical side.
- **Measure "winning":** run a batch of seeded Normal lives with a scripted "competent player" and a "careless player", and report the
  distributions: days survived, moults reached, chance of mating, causes of death. The target is that skill clearly shifts the odds, but even a
  skilled life often fails. Agree the target rates with Nathan before tuning.

## 5b. Nathan's survivorship brief (2026-10-24): design the luck around a Type III curve

Nathan shared this as the model for Normal. **Fewer than 1–2% of jumping spider eggs reach reproduction in the wild** (a Type III
survivorship curve). Survival by stage:

| Stage | Survival | What kills |
|---|---|---|
| Egg in the sac | ~70–85% | desiccation, fungus, parasitoid wasps |
| Early instars | ~10–20% | **the dispersal cliff:** starvation, ants, larger spiders, siblings |
| Mid and late instars | ~30–50% | failed moults, birds, parasites |
| Adult to reproduction | ~50–70% | courtship cannibalism of males, exhaustion while searching |

Captive broods survive at 60–80%: the environment, not fragility, drives the attrition.

The stage figures multiply to about 1–6%, which is consistent with the headline. **They are not yet tied to a cited study**, so they guide
tuning but don't go in the notebook until a source is opened, as the notebook rule requires.

**Proposal: you play a brood, not one spider.**
1. **The sac decides the brood.** While she guards, the sac's hatch count is drawn from the per-life seed, together with real threats: a
   parasitoid wasp visit, damp or mould. Guarding well improves the odds.
2. **The player is one spiderling at a time.** On death, play continues as a surviving sibling, which is the honest Type III experience.
   Death is common and expected, but the lineage isn't over until the brood is gone. Normal never says how many siblings are left.
3. **The first stage is the cliff.** Make stage 0, the 7 meals, the deadliest stretch:
   - prey sized to the spiderling (springtails, fruit flies)
   - ants and larger spiders hunting it
   - a short starvation clock
   - no web, so every meal is a hunt
4. **Moults are dangerous.** A failed moult is a real risk when the retreat is poor, exposed or dry, or when the spider is disturbed. This ties
   to the silk retreat in `claude/silk-features-design.md`. The game's 3 moults stand in for the real 5–10; the notebook says so.
5. **Adults.** A male risks being eaten while courting (the male playthrough). A female risks exhaustion between clutches. Multiple clutches
   per season give a female's life several broods.
6. **Measured targets,** to agree with Nathan, using the batch of seeded "skilled" and "careless" lives from §5:
   - careless play: about 1% of spiderlings reach reproduction
   - skilled play: noticeably more, perhaps 5–15% (Nathan decides)
   - a skilled player's lineage usually, but not always, survives a brood
   
   Easy and Free stay forgiving, like the captive brood.

## 5c. Nathan's decision (2026-10-24): the real number of moults, with the curve adjusted to fit

Nathan: **"I think the moults should be the accurate number and the curve adjusted."** This supersedes the 3-moult abstraction. It reshapes the
7/15/20 change in §3: keep the idea that each stage asks for more food, but spread it over the real stages.

**What the source says.** Bailey 1968, *Life History of the Spider Phidippus audax*, PhD thesis, Oklahoma State University:
- **Instars:** of 100 lab-reared bold jumping spiders, **15% matured after 7 instars and 85% after 8**.
- **Survival:** 79% reached adulthood in the lab. Mortality was highest in the first instar (about 7%), mostly in moulting, possibly from low
  humidity. That matches the "captive brood" survival of the survivorship brief.
- **Size and lifespan:** adult carapace widths were about 2.40 mm in males and 2.96 mm in females. The mean time from egg to death was about
  405 days for males and 488 days for females.
- **Not in the source:** the thesis gives no instar count by sex, so the game must not claim that males and females differ in moult count.
- A forum summary citing Roach 1988 gives 13–150 eggs per sac, averaging about 60. Open that source before using the figure.

**What it means for the game.** Spiderlings leave the sac after their first moult (an assumption to confirm with a source before it goes in the
notebook), so the playable life has about **6 moults** for an 8-instar spider and **5** for a 7-instar one.
- The per-life seed draws which kind of spider this is: about 15% mature at 7 instars, the rest at 8. A rare early maturer is part of the luck.

**Approved by Nathan, 2026-10-24** ("That sounds good"). These are now the plan for Chet, not proposals. The numbers are starting points, to be tuned against the measured curve in item 7:
1. **Data, not golden:** `Growth.game.instars`, the per-stage meal goals and the 7-or-8 draw. Godot's `Growth.ADULT = 3` and its golden data
   stay as they are, and the game uses its own table.
2. **Meal goals rise each stage,** and prey grows with the spider (springtails and fruit flies early, house flies later). Meals are counted in
   the stage's own currency, so the counter still reads "n / goal".
   - **Normal starts at 4 · 6 · 8 · 11 · 15 · 20.** A 7-instar spider skips one stage's goal.
   - Easy and Free stay gentler.
   - The first two or three stages are **the dispersal cliff**: a short starvation clock, small prey, ants and bigger spiders.
3. **Unlocks move onto the instar ladder:** **run at instar 4, lock-on at instar 6.** Each is explained only when it is earned.
4. **Every moult is a hazard.** Each needs a retreat. A poor, dry or disturbed retreat risks a failed moult, as in Bailey's first-instar
   deaths. Six or seven moults mean six or seven risks, which is where much of the curve's attrition comes from.
5. **Size and drawing:** the drawn spider scales per instar toward the adult carapace sizes above. `Appearances` gains a scale per instar. The
   existing growth stages map onto it.
6. **Saves:**
   - Old saves at stage s of 3 migrate to an equivalent instar, keeping consumed credit and unlocks. This is optional and validated, with no
     reroll.
   - Validators accept stages up to the drawn instar count.
   - Test a stage-2-of-3 save loading as the right instar, and a save already ready to moult (the sticky-ready fix in §3 still applies).
7. **The curve, measured:** use the seeded batch of skilled and careless lives (§5) and report survival per instar against the survivorship
   brief. Tune the hazards, not the moult count, until careless play gives about 1% to reproduction and skilled play reaches Nathan's target.

## 6. Recommended order for Chet on resume

1. **Sex gate** (§2, items 1–4), with its tests. It prevents a male laying eggs today.
2. **Real moult count with rising meal goals** (§5c, which supersedes the 7/15/20 numbers in §3), with the sticky-ready fix and §3's edge cases adapted.
3. **Post-mating clearance** (§4), with CLI tests, then the native gate.
4. **Carry and rejoin**: never hatch twice (§1).
5. **Per-life seed** (§5), as a design-reviewed change. Then the skill-vs-luck batch measurement, then tuning with Nathan.
6. Resume the paused audit: natural attacks, whole-map collision, devices, measured startup, the remaining `os.clock` route preparation, and the
   corrupt-slot recovery path.
7. **Then features**, after a public release of the above. In order:
   1. male/female playthroughs (`claude/male-female-playthroughs.md`, once Nathan decides where a mated male goes)
   2. jumping-spider silk (`claude/silk-features-design.md` §2)
   3. the greedy merge (`claude/chet-prompt-greedy-merge.md`)
   4. rare sightings (the Rare Sightings page)
   5. the orb weaver
