# Handoff: the detail round (ROBLOX-84..90) and its audit (ROBLOX-91..93) — the spiders up close, the hang, living motion, pacing, the mating scene, Inspect

Claude → Chet, 2026-10-18 (evening). Still branch **claude/roblox-sill** (one bundle, `claude-playtest/claude-sill.bundle`,
carries the daily round, the sill round ROBLOX-71..83 and this round). Build evidence `a83e0b69a7a331ce`. CLI at the
closing commit: strict clean, 136/136 compile, every suite green (new/changed: look 1009, idle 5719, inspect 36,
mating 643, client_mating 17, settings 1151, growth 460, rival 2724). **Nothing in this round has run in Studio** — the
rig work was judged in the off-Roblox previewer (`tools/preview/preview.py`, now with `--hang`, `--cue`, `--focus`),
which gets proportions and placement right and Roblox's materials and lighting wrong. Published to the playtest as
**v29** by the usual Rojo route from Nathan's PC.

**The bundle** is `claude-playtest/claude-sill.bundle` on Nathan's PC: the coordinator overwrites that one file each round, so it always
holds the whole branch up to the latest commit. Names such as `claude-sill-v28.bundle` or `-v29` exist only in the cloud outputs of the
sessions that made them, not on the PC and not in the repository.

**Added 2026-10-19: the audit round, ROBLOX-91..93** (three commits on top: the sim, the client, the rigs and the frame), then a pass over the
notebook's science and the documents. CLI at that point: strict clean, 137/137 modules compile, all 35 suites green (60,796 checks); the counts that moved:
life 20,902, growth 477, rival 2,830, checkpoint 251, mating 715, client_mating 28, look 1,417, inspect 37, hud 96, peacock 270, notebook 941.
The figures below this line that the audit changed are corrected in place and marked *(audit)*; `docs/DECISIONS.md` has the reasons.

## What is in it

- **ROBLOX-84 — anatomy.** First spider and both tarantulas: tapered femur, a patella knee, tibia taper, a metatarsus
  break, feet (claw tufts and pads; tarantula scopula paws), fangs. The 3-link IK chain, targets, gait and motor are
  untouched; the first spider's pattern is untouched. Budgets: first spider 695/267 (full/low), redknee 146/84,
  greenbottle 148/84.
- **ROBLOX-85 — fur, sheen, palette.** The first spider's hairs lie 15–25° along the body, flowing back and out, a few
  pale tips, 0.04 reflectance on carapace and abdomen. Tarantulas: Fabric fur shells on carapace and abdomen, leg
  bristle fringes (full tier), the redknee's urticating cluster and raised copper rim, the greenbottle pulled toward
  the animal (legs #1E3F8F at 0.10 reflectance, teal-green carapace #1E8062, burnt-orange abdomen, softened bars, three
  raised ridges, blue-white bristles). **Studio judgment needed most here**: how Fabric shells, the 0.04 sheen and the
  thin hairs read under the sill's lighting.
- **ROBLOX-86 — the hang.** The body hangs along the line, head down (lean 3°, sway 4.5° at 2.5 s decaying over 4 s,
  spin 8°/s decaying), legs I–II curled up the line, III–IV folded back, palps tucked; head-up when climbing (inferred
  from speed along the line, on > 0.35 studs/s, off < 0.14). Reduced Motion static. Tarantulas a heavier copy.
- **ROBLOX-87 — living motion** (`Rig/Living.luau`, full tier only). Abdomen breathing 0.4 Hz / 2.5%, grooming bouts
  after 4 s of standing (palp through jaws, leg-I wipe; every 8–20 s seeded; a longer clean after a meal via
  `rig:noteMeals`), a ±20° drawn turn toward the focus point, an alarm leg-raise (1.2 s) on the wasp's first warning
  and the rival's windup; tarantulas breathe at 0.25 Hz with a 3 s leg stretch and no grooming.
- **ROBLOX-88 — pacing** (Nathan: "getting through too quickly"). A moult takes 5 housefly-equivalents (`Growth.game`,
  Godot's 3 stays golden; HUD "N of 5 meals"); hunger drain 1.55 → 1.9 (a day ≈ 0.61); the rival contest 40/32/28 with
  the counter-bite 0.30; the rival grip needs ~5 taps/s for 7–10 s, ≤3.5 loses, idle tears free in 1.65 s. *(audit)* Gentle
  modes were meant to be unchanged but had taken this pacing by accident; ROBLOX-91 gave Easy and Free play their own back (drain 1.1 with the
  half rate, three flies a moult, contest 55/25/20).
- **ROBLOX-89 — the mating scene.** A full courtship meter starts a 15 s scene (11 s with a male mate) on the sim's own
  clock: 0.8 s ease into a two-shot with a 90° quarter-orbit (static in Reduced Motion), beats turn / touch / settle /
  depart with `MateText` captions for either sex, `meet`/`settle` cues on both rigs, the music swelling 1.6×, skip
  after 4 s, controls locked otherwise, a rest refused while it plays, a wasp arrival force-skips it. The sac / guard /
  hatch chain after it is unchanged.
- **ROBLOX-90 — Inspect mode.** Settings "Look closely" button, or hold the choose key 0.6 s in the crack: an orbit
  camera 1.6 body-lengths out, zoom 1.1–3.0 (wheel 12%/notch, stick/W-S, pinch), elevation 4–88°, auto-orbit 10°/s
  after 3 s idle, framings face/side/top on the eye key, the sim running (living motion is the point), ended by
  Cancel/jump/choose/any menu, cut off by a wasp warning or the rival's windup. Eye view given back on exit. Works on
  the line.

## The audit round (ROBLOX-91..93)

- **ROBLOX-91 — the sim.** The rival keeps away from courtship and the mating scene; a rival that tore free of the grip is a contest again;
  Easy and Free play get their own pacing back (drain 1.1, three flies a moult, 55/25/20) and their own `easy` rest slot beside main and free;
  the starving streak decays by meals; each generation has its own first-day grace; checkpoints drop the profiling windows; a hungry rest
  says so; the stale text and the duplicated credit formula are fixed.
- **ROBLOX-92 — the client.** A failing save no longer stops the frame ("Saving is off"); a close look begun from the eye view gives way to the
  mating scene; the controls card is ten lines or fewer (9 / 10 / 10 for keyboard / pad / touch) and is the one string PromptSpec measures;
  the Menu has Controls; the mating scene's skip is announced; a mate far off is not announced; Reduced Motion cuts the two-shot; short phones
  take the compact touch layout; toasts have priorities; a refused rest speaks in the game's words; "checkpoint" is "last rest"; the client
  compiles at -O0 again.
- **ROBLOX-93 — the rigs and the frame.** The mate is sized once, not every frame; the spiderlings' heads touch their bodies; no hair passes
  through an eye; the hairs go in a second `BulkMoveTo` only when the frame they follow moved; a rival or mate beyond 25 studs is drawn ten
  times a second; the two sides of a mirrored pair are thinned alike; legs I and II keep 0.6 of the femur bare; the meet pose's knees stand
  out wider; the greenbottle's first legs are a tenth heavier. First spider: **693 parts full / 265 low** *(audit: the figures above and
  below that say 695 / 267 are the ones before this round)*.
- **Then the notebook and the documents (2026-10-19).** Several sentences of the notebook said more than their sources do and were corrected
  (the moult counts, the "25 to 31 days", the mud dauber's sight, "83 milliseconds", courtship "by sight"), after the sources were opened;
  `docs/NOTEBOOK_SOURCES.md` says which and what each was checked for. The documents that quoted old numbers were brought up to date or marked.

## Your Studio checklist (ROBLOX-84..90, and the audit round ROBLOX-91..93; on top of HANDOFF-roblox-sill.md's, which still stands)

1. **Look at the three spiders** in Inspect mode at full tier: fur density and lay, the shells (Fabric may need
   transparency/colour tweaks — `Appearances` holds every number), fangs, feet, the greenbottle palette, the first
   spider's pattern unchanged. Then the low tier on a phone.
2. **Frame time** at full tier with the first spider: 693 parts, 492 of them hairs *(audit; 695 and 494 before it)*, plus living motion
   stepping each frame and, since ROBLOX-93, two `BulkMoveTo` calls a frame when any hair moved — measure on the PC and on a phone (the low
   tier is 265 parts). A rival or mate beyond 25 studs is drawn ten times a second: does its walk look steppy?
3. **The hang**: drop on a line, watch the pose, the sway, and the head-up climb; check the 0.35 studs/s climb
   threshold against the real reel.
4. **Living motion**: breathing visible but not silly; grooming bouts; the attention turn when looking at a fly; the
   alarm raise at the wasp hum. Reduced Motion kills all of it.
5. **Pacing**: a full day's play — does 5 meals a moult and 0.61 a day feel like the pace Nathan wants? The rival fight
   at 5 taps/s on a pad; on touch it may need a lower tune (`Data/Catch.rival`).
6. **The mating scene** end to end: the two-shot, the touch, the departure, the skip; then the sac and hatch still
   chain. `PromptSpec`/`SettingsSpec` counts changed again (Inspect row): run them.
7. *(audit)* **Saves:** the `easy` rest slot on the real DataStore (a new Easy life leaves the standard rest as it was; "Continue the Easy
   life from its last rest" appears) and a player leaving while still loading (the shutdown count). Then **Easy and Free play** for a stretch:
   drain 1.1 with the half rate, three flies a moult, 55/25/20 — is it right beside Standard's harder pacing?
8. *(audit)* **The controls card** on a real phone: ten lines or fewer (`PromptSpec` now measures the one string the HUD shows for every
   device and display key), the 480 x 320 and 640 x 360 layouts, "Skip" and "Rear up" in their buttons, the Menu's Controls entry, and
   "Saving is off" (break the notebook's record to see it).
9. *(audit)* **Close faces and walking legs** under Studio's shadows: the hairs are placed up to 1e-4 studs late, legs I and II have a bare
   hip (0.6 of the femur), the meet pose's knees stand wider, the spiderlings' heads touch their bodies, the greenbottle's first legs are a
   tenth heavier, and the grey disc behind the peacock fan in the dance is the fan's back repeat (nothing was changed; the cheap ways to
   take it away are in ROBLOX-93, item 16).
10. Merge judgment: the branch is now long (more than 35 commits since main); merge when your pass is clean.

Open for Nathan: the pacing feel, the rival tap rate on touch, whether grooming bouts are too frequent, inspect's
auto-orbit speed, and the tarantula pass pricing (still one-vs-each).
