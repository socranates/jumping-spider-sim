# Feeding, survival and preserve review - active work

User adopted `docs/reference/chet-prompt-v49.md` and its six parts. That reference
predates the completed ranger-station release. Build on published v49 place138,
branch `codex/v50-feeding-survival`, preserving the station, 150x6 reserve and 2px
dot. Deliver a new v50, not a rollback to v48 or an overwrite of v49 evidence.
Keep the requested report name `chet/review-5.md` in the writable repository;
synced Project sources and OneDrive remain read-only. No Claude edits in parallel.

## Acceptance checklist

- [ ] Trace catch/grip/feed controls and explain why minimal HUD hid the cues.
- [ ] Small device-correct contextual feeding prompts, settings opt-out; every
  catch in all modes. Actual bindings: E, left-stick click/L3, touch Eat/Grip.
- [ ] Visible held prey at the animated jaws, bite/head/palp motion at both tiers,
  reduced-motion amplitude, decreasing drawn prey, bounded grounded dropped husk.
  Preserve nutrition conservation, partial credits and 7/10 moult thresholds.
- [ ] Soft bite/end feedback using suitable existing/built-in sounds, respecting
  mute, creature/master volume and pause. No new uploads/permissions needed.
- [ ] Reproduce starvation before changing tuning. Published Normal does die,
  but only after 48 empty-reserve game hours; gentle modes never die. Pin new
  Normal deadline from full/default/empty reserves, sleep, save restore, real
  client end screen and lineage. Preserve pure frozen-reference defaults.
- [ ] Dusk prompts at LifeClock.DUSK_H; correct rest key, no map marker; clear on
  rest, no daytime prompt, return next dusk; every night in all modes. Inspect
  actual post-v48 input, not outdated R/Y examples in the reference.
- [ ] Baseline/after foreground native profiling, full and low, sill/garden/
  meadow/pond/doorway; no concurrent CLI; report exact sample scope and lighting.
  Measure then retain only justified perf changes; keep liked lighting. Phone
  only if available; label Studio emulator honestly if used.
- [ ] Whole-preserve support/clipping review at both tiers, walking and jumping,
  default camera, tight spaces, grapple/mate, held prey, milkweed mesh/collision,
  actor floors, floating/copanar surfaces; fix concrete issues, meaningful tests,
  screenshots for limitations. Recheck v48 limits explicitly.
- [ ] CLI full pass, strict and compile, full native self-test with feeding check;
  source fingerprints; no playback/debug overrides; publish existing place only;
  Dashboard published-only proof; report/handoff/package/GitHub synchronized.

## Evidence so far

Latest GitHub CI on the complete v49 source/test tree is green:
https://github.com/socranates/jumping-spider-sim/actions/runs/39698969512 (8df389a).
Recent GitHub email failures referred to earlier candidates. No email was sent.

`starvation-before.txt` reproduces old Normal timing at 60x game clock: default
0.55 reserve dies after59.2 game hours, full after68.4, empty after48.4 (quarter-
second/2Hz integration bounds). Gentle survives120.2 hours. This diagnoses long
grace, not an infinite Normal life; Nathan's played mode is not known.

Corrected full/low baseline samples are in before-corrected-native.txt. Initial
pond_a2 sampling was underwater and is not representative of the pond edge; it
is retained separately, and the route now uses deck_n2. Doorway darkness cleared
without a source change. Do not call it a fixed camera bug.

First implementation: live manual bites (AutomaticGrip keeps automatic eating),
animated jaw frame / held fly depletion / three-part bounded husk, device-correct
feeding and dusk prompts through ControlHints, quiet built-in bite feedback,
Normal empty-reserve grace 12 hours and weakness 6 hours. Frozen model defaults
remain 48/24. New-life and restore explicitly reapply live rules. No growth,
nutrition, movement, aim or lighting tuning changed.

New feeding_survival suite currently 80 passed/0 failed, including real-client
input and starvation death screen/summary, model save/restore/rest bounds, gentle
survival, prompt device/night timing, visual depletion and bounded husk, mute,
and far-cat render cadence. Existing targeted client27/life20922/prey1668/
checkpoint545/minimalHUD37 passed. Strict analysis clean after initial repairs.
Full native SelfTest is running in local Studio36441252. Cloud Studio4131012
remains stopped/disconnected. No release or final regression claim yet.

Performance candidate: CatBody geometry beyond180 studs gets10Hz updates; its
simulation and audio retain their rates. Source profile attributed substantial
per-frame allocation to its pose list; keep only if native measurements support
the tradeoff. Existing scenery budgets, shadows and low-tier lighting retained.
