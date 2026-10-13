# Windows drawn-growth check — 2026-10-12

Game source: `537d1ce`, based on `817f88a`. Godot 4.7.2, Windows,
Compatibility renderer, Jolt. No physics, collision, twitch, SimClock or
silk-rule changes. Six new integration tests and their UID are committed.

## Automated checks

- Baseline: 612/612, evidence `fe3af29213dd` (`baseline-612.txt`).
- Growth, surface legs, moulting and drop tests: 26/26 at fixed 30, 60,
  and 144 fps (`target-30.txt`, `target-60.log`, `target-144.txt`).
- Full Windows suite: 618/618, no failures or skips, evidence
  `baedf0eb21d9`, 1,514 s frame time under the 2,400 s watchdog (`full-618.txt`).
- New coverage: each stage changes body/leg size without moving the motor
  or collider; world-space stance anchors survive movement; scaled swing,
  rod width and turn stepping; walls/undersides; restored mid-life size
  alongside condition/softness; calm Reduced motion; adult eye-view mask.

## Native graphical check

`check_play.gd` stages three flies per moult within capture range, resets
reserve to leave feeding room, then uses the real capture ledger, automatic
struggle/feeding and retreat APIs. This is a controlled native simulation,
not a human keyboard hunt. Isolated settings/checkpoints protect Nathan's save.
`play.log` records nine consumed meals, three accepted rests, three stage
checkpoint saves, old-skin counts 1/2/3 and adulthood. Screenshots show the
ready/moulting/soft states and matched size 0/1/2/3. Pale skin is easiest to
see in daylight; the adult-at-night shot preserves silhouette, not fine tint.
Old skins remain Claude's placeholder husks; this work does not remodel them.

Adult silk checks use the real begin_drop and reel intent from a leaf,
wall and planter. All three reached the floor and separately reattached
when reeled before landing. Leaf return attached to the underside; planter
return to its rim/side. Some underside orbit views frame poorly (see
leaf_return_end.png); this is not marked visually polished. Once landed,
the line is a completed trail, so this is not a floor-to-anchor return.
No change to that existing silk rule.

## Moult timing — on battery, not plugged in

Separate native run with `--profile`: screenshot readback disabled, 1280x720,
normal VSync, default simulation rate, no simultaneous suite/export.
BatteryStatus 1, charge 92% to 91%. The app was launched normally and explicitly
foregrounded during the run. Short source-runtime samples, not release-EXE
or whole-game benchmarks. First/third moults orbit view; second eye view.
Raw CSV is gzip-compressed; summary and power snapshots are alongside it.

| Moult/view | Frames | Mean ms | p95 ms | Max ms | Mean GPU ms |
|---|---:|---:|---:|---:|---:|
| 0 / orbit | 513 | 16.776 | 17.603 | 56.627 | 7.486 |
| 1 / eye | 511 | 16.929 | 17.580 | 71.502 | 7.941 |
| 2 / orbit | 512 | 16.860 | 17.875 | 66.469 | 6.832 |

Each sample is about 8.6 seconds. Mean throughput ~59–60 fps; strict 16.7 ms
frame budget still not met consistently. These timings include state/save
work near the moult boundary; no profiler attribution proves which work
caused the spikes. No claim of improvement over the prior plugged-in route.

## Friend builds

Fresh Windows and web exports from `537d1ce`; CRC and SHA-256 in
`friend-builds.json`. Both contain README and Godot licences.
Downloads folder: `The-Windowsill-Playtest-2026-10-12-Growth`.
Windows EXE launches and draws (`windows-release.png`). Web served on
localhost: orbit and eye shader render; V and N work; W input exercised,
without a separate displacement measurement. Eye/notebook screenshots saved.
Embedded browser logs pointer-lock `WrongDocumentError`; mouse-look remains
unverified there. No sound-listening or physical controller pass claimed.
No public upload. Builds carry the tested game source; later commits add
verification/handoff documentation only.
