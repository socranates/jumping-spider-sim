# Wasp presentation — Windows, 2026-10-13

Based on main 7fa4bd1. Godot 4.7.2, Compatibility renderer, Jolt.
Baseline: 628/628, evidence e962dffc61cb (baseline-628.txt).
Final targeted: 28/28 at fixed 30, 60, 144 fps, evidence a45591fefdf2.
Final full suite: **632/632**, no failures/skips, evidence **a45591fefdf2**,
1,704 s frame time under the 2,400 s watchdog (full-632.txt).
Game source commit: **373c7cf**; subsequent commits are documentation/evidence.

## Model and animation

Procedural original geometry: ~2.47 WU head-to-abdomen, excluding antennae;
-Z forward. Black head/thorax/gaster, slender yellow petiole, yellow collar
and scutellum, black/yellow jointed legs, two translucent smoky wing pairs
with simplified veins, bent antennae with yellow scapes. Three rendered
segments per leg are a simplification, not a complete insect skeletal rig.
Public pose(mode, beat, search) and modes preserved. Walking alternates
tripods; flight trails long legs; holding folds front/middle legs beneath.
Wings fold during walking and sweep in flight. Beat now uses SimClock.DT
on physics ticks so slow motion affects animation. Shapes and motion remain
stylised, not a photorealistic model or measured wing kinematics.

Identification references consulted:
- University of Florida: https://ask.ifas.ufl.edu/publication/IN1478
  Black body, narrow waist, variable yellow markings, female length 23–25 mm.
- University of Minnesota: https://extension.umn.edu/garden-and-home/yard-and-garden/yard-and-garden-insects/solitary-wasps
  Black/yellow legs and orange-to-dark wings.
- University of California Riverside: https://insects.ucr.edu/we-ch-9-2
  Yellow petiole and portions of legs; markings vary among descriptions.
No downloaded meshes, textures or audio. No optional looming response added;
the existing player-controlled retreat remains unchanged.

## Spider and catch screen

Seized body stops recoil, twitch and jump poses; all eight legs draw inward
and stop cycling. Existing growth scale and tint remain. Regression checks
all four sizes, static local feet and released surface anchors. The normal
unseized twitch and gait remain. No change to motor/collider/AI/escape timing.
Catch screen now hides lower HUD CanvasLayers while it is shown, leaving the
notebook above it available; previous visibility is restored when continuing.

Staged native fixture check_play.gd invokes a real visit at floor_middle,
paces in the open until noticed, then stops. This is controlled simulation,
not a human controller playtest. Screenshots use observer closeups for model
and carry, gameplay camera for inspection, and an eye-view inspection.
Normal 1080p text fits. At 150% text the catch message and both choices fit;
the previously overlapping live HUD no longer clutters it. See caught_large.png.
Normal caught.png predates HUD cleanup; its typography is unchanged.

Visit events: warning at 0; searching 8.0167 s; noticed 9.8 s;
strike 12.4833 s; catch 12.8333 s in visual run. The suite covers retreat
safety, jump/drop escapes, stillness, notice and the pre-strike inspection.
My visual assessment: readable warning/inspection, brief non-graphic carry,
plain pause/choices. This is not evidence of how Nathan's children will feel.

## Sound

Designed hum keeps a 120 Hz base (not a measured species wingbeat) and adds
480/720/960/1440 Hz presence for small speakers. Unit distance 40 WU, +3 dB
source gain, near-field cap -3 dB, distant filter attenuates by only 6 dB.
Existing speaker EQ, cue/master mute and limiter retained. No sting impact
or sudden scream added. Timing/volume regression confirms sound starts in
arrival and stops with the actor. Harmonic test verifies upper-band energy.

arrival.wav.gz is a digital Master-bus recording with ambience and speaker
mode, not a microphone recording of laptop speakers. audio-summary.json
records per-second RMS and peak; the peak limiter holds about -1 dBFS.
Recording buffers cover about 7.9 s of the eight-second warning. Audibility
on the actual speakers at Nathan's chosen Windows volume is NOT VERIFIED;
physical listening and child comfort remain human playtest items.

## Native visit performance

Separate 1920x1080 source-runtime run, default VSync, no screenshots, audio
recording or concurrent tests/export. BatteryStatus 1 (discharging), 53% at
start. 891 frames over ~16.35 s. Fresh isolated shader cache; no causal
comparison with the old model. Brief eye-view portion during inspection.

| Phase | Mean ms | p95 ms | Max ms |
|---|---:|---:|---:|
| Whole visit | 18.348 | 22.069 | 183.558 |
| Arrival | 20.128 | 22.696 | 183.558 |
| Search | 17.459 | 19.320 | 22.369 |
| Inspection | 16.884 | 18.917 | 58.696 |
| Strike | 16.838 | 18.315 | 18.590 |
| Carry | 16.649 | 18.495 | 23.349 |

About 54.5 fps overall; arrival is the slowest phase in this sample and has
a large first-visit hitch. Shader warmup is a possible contributor, not a
proven diagnosis. Strict 16.7 ms F01 remains unmet. Raw CSV, summary and power
snapshots retained. Do not describe this as a stable 60 fps pass.

## Builds

Fresh Windows/web ZIPs from 373c7cf; CRC and hashes in friend-builds.json.
Downloads/The-Windowsill-Playtest-2026-10-13-Wasp. Windows launch and web
eye-shader launch visually verified. Web console reported no errors/warnings
in this launch check; no mouse-look or sound-listening claim. Full visit
was tested in native source runtime, not replayed in exported bundles.
Physical controller checks remain unverified. No public upload.
