# Handoff: the detail round (ROBLOX-84..90) — the spiders up close, the hang, living motion, pacing, the mating scene, Inspect

Claude → Chet, 2026-10-18 (evening). Still branch **claude/roblox-sill** (one bundle, `claude-playtest/claude-sill.bundle`,
carries the daily round, the sill round ROBLOX-71..83 and this round). Build evidence `e2986a4a8c0a2de1`. CLI at the
closing commit: strict clean, 136/136 compile, every suite green (new/changed: look 1009, idle 5719, inspect 36,
mating 643, client_mating 17, settings 1151, growth 460, rival 2724). **Nothing in this round has run in Studio** — the
rig work was judged in the off-Roblox previewer (`tools/preview/preview.py`, now with `--hang`, `--cue`, `--focus`),
which gets proportions and placement right and Roblox's materials and lighting wrong. Published to the playtest as
**v29** by the usual Rojo route from Nathan's PC.

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
  the counter-bite 0.30; the rival grip needs ~5 taps/s for 7–10 s, ≤3.5 loses, idle tears free in 1.65 s. Gentle
  modes unchanged.
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

## Your Studio checklist (on top of HANDOFF-roblox-sill.md's, which still stands)

1. **Look at the three spiders** in Inspect mode at full tier: fur density and lay, the shells (Fabric may need
   transparency/colour tweaks — `Appearances` holds every number), fangs, feet, the greenbottle palette, the first
   spider's pattern unchanged. Then the low tier on a phone.
2. **Frame time** at full tier with the first spider: 695 parts, 494 of them hairs, plus living motion stepping each
   frame — measure on the PC and on a phone (low tier should be unchanged at 267).
3. **The hang**: drop on a line, watch the pose, the sway, and the head-up climb; check the 0.35 studs/s climb
   threshold against the real reel.
4. **Living motion**: breathing visible but not silly; grooming bouts; the attention turn when looking at a fly; the
   alarm raise at the wasp hum. Reduced Motion kills all of it.
5. **Pacing**: a full day's play — does 5 meals a moult and 0.61 a day feel like the pace Nathan wants? The rival fight
   at 5 taps/s on a pad; on touch it may need a lower tune (`Data/Catch.rival`).
6. **The mating scene** end to end: the two-shot, the touch, the departure, the skip; then the sac and hatch still
   chain. `PromptSpec`/`SettingsSpec` counts changed again (Inspect row): run them.
7. Merge judgment: the branch is now long (35 commits since main); merge when your pass is clean.

Open for Nathan: the pacing feel, the rival tap rate on touch, whether grooming bouts are too frequent, inspect's
auto-orbit speed, and the tarantula pass pricing (still one-vs-each).
