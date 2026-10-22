# Handoff to Claude - The Windowsill v50, published 2026-10-21 Central

**Published and tested.** Pull branch `codex/v50-feeding-survival` from
https://github.com/socranates/jumping-spider-sim . Tested source:
`856c12e3e71d9b79282954013142fa5577fc3f19`; evidence `3112f8aa4f3f192f`.
Later commits contain receipts only. Existing place120119801868085,
universe10771103250, **published place version139**, publication operation
2026-10-22T02:15:08.763Z. This builds on v49/place138; the reference prompt's
v48 baseline and requested v49 name were obsolete.

## Start here

Read `chet/review-5.md`, `docs/verification/v50/RESULTS.md`,
`docs/verification/v50/PERFORMANCE.md` and `docs/DECISIONS.md` ROBLOX-130.
Actual release/build hashes: `docs/verification/v50/release.json`.
Actual portable zip path/hash: `docs/verification/v50/portable-package.json`.
The zip contains active Roblox code/tests/tools, playable and test places,
reports and an internal file-hash manifest. It excludes the frozen Godot tree
and generated test captures/snapshot archives. Cloud sessions should use the
GitHub branch, not expect access to Nathan's Windows paths.

From roblox_port, run `python tests/run.py <path-to-luau>` for all58 suites.
`tools/check.sh compile|types` is the Linux CI entry; the workflow installs its
toolchain. Build using `python tools/build.py <path-to-rojo>`; it should retain
evidence3112f8aa4f3f192f while source/tests/project inputs are unchanged.
No new dependencies, uploaded assets, grants or save-schema changes are needed.

## What changed

- Actual Feed controls E / Xbox left-stick click / PS L3 / touch Grip-Eat now
  explain every catch in all modes. After subduing, accepted taps renew a
  bounded0.38s eating window at the old nutrition rate. Movement/air interrupts;
  no banked nutrition. AutomaticGrip also supports automatic eating (defaultoff).
- Held prey follows the animated jaw frame, depletes visually, then drops one
  temporary grounded three-part noninteractive husk. Head/jaw/palp pulses are
 20% in Reduced Motion. Held perched shadows are hidden, restored on release.
- Quiet built-in volume_slider.ogg feedback respects mute/volume/pause. Native
  IsLoaded was true; no new asset permission step is required.
- ContextPrompts uses actual device words and survives SpiderHud.minimalView.
  ShowControlHints covers it. Dusk briefly names the local home, then gives the
  real rest button at shelter; rest clears it and next night repeats it.
- Normal live rules weaken6h/death12h at empty reserve. Full unfed reserve is
  bounded by three game days even sleeping; rest/save does not erase starvation.
  Easy/Free remain nonfatal. Old published Normal was48 empty-reserve hours,
  not immortal; Nathan's exact prior difficulty was not reproduced.
- Pre-v50 saved meals may omit new bite fields: ObjectRecord.commit clears
  constructor defaults. useGameRules supplies optional defaults after restore.
  Keep that compatibility pattern for future optional fields.
- Shelf fallback moved above its book; floorA fallback moved beside boot sole.
  Geometry/saved positions/layout revision are unchanged. Old overlaps are
  reproduced and replacements verified by meaningful motor/camera tests.
- CatBody caches pose specs10Hz beyond180studs but carries actual body motion
  every render. AI/attacks/audio remain unchanged. Kept for measured allocation
  savings, not a demonstrated steady FPS gain.

Preserve seven/ten whole-fly equivalents for the first two moults, partial credit,
Run after first, lock after second, no future unlock spoilers, L1 creep/earned
contextual lock, L2 Run, R2 Focus, manual aim/jumps, green chelicerae, wordless
150x6 reserve and2px aim dot. New feeding/dusk cues explicitly narrow the former
hunger-only screen rule; do not remove them by reapplying the old rule.

## Exact verification scope

Final GitHub run39708111460 succeeded: all58 suites, strict clean and211/211
source modules compile. Embedded garden SelfTest41/0/0, preserve274/0/0.
CI stdout/metadata and focused state_client142/0 are retained.

Native Studio G complete low274/0/0, followed by H selected5/0/0 at each detail
(the last H edits are test selection/cleanup and stale meal assertions only).
Historical A full273/0/0 predates several repairs; do not relabel it final.
Actual H meal/dusk/rest/sound/husk checks pass at both tiers. Controlled capture
fixtures are not claims of an unassisted player hunt. Native full survey233
regions found only the two old buried fallback positions (three observations
each); final low233/233 had0 unready/0 camera interiors, scenery<=500.
Final full/low tight checks cover both spawns/cans, Crack, bench, leaf and a real
silk catch with camera overlap0. Surveys sample spawn stand/walk/hop, not every
possible route or animation.

No concurrent CLI/compiler load during final native timing: five scenes per
tier, same desktop viewport1105x435,7s settle/5s sample. After full means17.43-
22.38ms, low16.67-24.20ms. Some samples regress; include the table and variance.
Paired cat sound-lap allocation (includes CatBody.draw)62/36/63KB per frame,
whole render161/138/166KB; mean17.62/19.96/20.85ms is inconclusive for FPS.
MicroProfiler overview/timeline screenshots retained. Phone emulator iPhone17Pro
749x381, TouchEnabledtrue: TapEat/reserve fit, locked abilities hidden. No real
phone performance or controller hardware test is claimed.

## Remaining bounded work for a future pass

1. Older phone labels Focus/Creep/Recentre/Cancel wrap. Screenshot
   `docs/verification/v50/phone-layout-iphone17pro.jpg`. Shorten/fit text while
   preserving hit targets, controls, accessibility and unlock hiding.
2. Close milkweed views expose the broad support-box shape beside the detailed
   oval blade. Records are centered/fitted by axis; no confirmed origin-offset
   bug was found in the source audit. Retain current collision/save IDs unless
   Nathan authorizes a support-shape redesign. See final-full-leaf-review.jpg.
3. Procedural feet can intersect soft vegetation; cans remain faceted; husk is
   simplified. Low omits decorative leaf meshes while retaining support.
   Ants/grubs/fleas/dog are still not new food types.
4. Real-phone play/performance and real-controller testing remain useful.
   Avoid claiming an optimization from a single frame or a CLI simulation.

## Working and release guardrails

Writable clone C:/Users/natha/windowsill-publish. The OneDrive project and synced
Project sources remain read-only; Godot remains frozen. Do not push the local
OneDrive origin/main or a Claude branch. Work on a fresh named branch and tell
Nathan before another parallel agent edits fly/feeding/settings/menu.

The local PlaceId0 review copy was cleaned, source-compared211/211, saved in
claude-xfer and closed. Cloud Studio remains stopped/disconnected. Before future
publication compare source, clear SilkPlayback/SelfTest/Detail/Cat/Wasp/TestTarget,
verify existing IDs/StreamingEnabled/gravity35, disconnect Rojo and Publish only
the existing place. Never Publish As, create an experience or change access.
Future lighting and radii96/160 are unchanged configuration values; their direct
command-bar reads were unavailable in this Studio context. Do not turn those
failed diagnostic reads into claims about engine state or change lighting to
make a guard pass. Dashboard Show published only confirms139; screenshot saved.

No email/messages were sent. Inbox alerts were earlier GitHub failures; final
H is green. No private mail or credentials belong in this handoff/package.
