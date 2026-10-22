# Outdoor encounter reset

Unpublished source `3c8de801e5fab68598e1e5323e7f5e1c8151b0e6`, evidence `d543592dddf4e621`, branch `codex/outdoor-life-reset`. Base `b1be9f1d59650463a0cc82c230dae63afdccb687` includes the verified caption fix.

## Problem and change

The frog, crab spiders and robin are seeded visitors whose transient combat state is not serialized in a checkpoint. New Life restored the core world and cat/wasp but retained these three live objects' reactions, cooldowns, sighting flags, queued signals and diagnostic counters. A same-day restart did not even trigger their normal day-change placement. Returning to a saved rest could also retain an encounter that happened after that rest.

Each model now exposes reset(), returning it to constructor state while preserving its identity, seed and enabled/gentle configuration. New Life and successful rest recovery call it, then apply the current life's gentle rule. The client also clears its cached robin-shadow cue and frog tongue target. This does not change attack rules, seeded schedules, positions, input, camera, lighting, geometry, feeding, settings, save records or schema. The next ordinary simulation tick places the visitors for the restored clock. Invalid/refused New Life requests leave the current encounters intact.

Four production modules change: SpiderClient, Frog, CrabSpider and Bird. There is no rig cache in this change.

## Evidence

- The frozen old production source fails 15 checks (30 pass) in the current real-client preserve regression. Its fixtures actually trigger strikes/cooldowns/signals before New Life or rest recovery. The fixed source passes all 45 checks.
- Targeted suites: OUTDOOR_RESET 45, NATURE 28,890, NATURE_CLIENT 6, MINIMAL 63, STATE_CLIENT 162: **29,166 passed**, exit zero.
- All 216 production modules compile with -O0; strict analysis is clean; five runner regressions pass.
- Native Studio run `1792664252632` passed **46 assertions** after a guard verified all 217 authored scripts (216 production plus one probe) and confirmed Persistence.Disabled=true. The native probe uses real client callbacks, model-generated attack fixtures, Normal/Free Play, enabled and disabled flags, and a real in-session local rest/recovery. No CreatorError occurred. The probe was stopped afterward.
- Full Windows run and Linux CI run `39761460756` are tracked separately. Their status is authoritative only in receipt.json and the completed process/CI metadata. Do not treat a partial log as a finished suite.

The diagnostic place is `C:\Users\natha\claude-xfer\Windowsill-outdoor-reset-native-v1\Windowsill-outdoor-reset-review.rbxlx`, SHA-256 `d828dc8708a1d0abd16cbdaa5f6e35e87b19cd02242f456e0854fb6bb7a2a81b`. Never publish it. Its injected probe, diagnostic attributes and disabled persistence are absent from the release XML. This is not online DataStore rejoin, native performance, physical input comfort, or manual playthrough evidence.

## Reproduction and receipts

`baseline.py --luau ABS_EXE` archives the old production source in a temporary directory and bundles the current regression against it. It binds both SRC and HERE: the bundler's inline SpiderClient path reads HERE.parent/src independently. An earlier attempt bound only SRC and hit a missing-reset-method setup error; that log remains as baseline-wrong-client-binding.txt and is not regression proof. baseline-initial.txt retains an earlier fixture issue. baseline.txt is the corrected, source-bound 30/15 reproduction.

`check.py` builds the place, compiles/types it and runs the runner regressions. `check.py --full-only` starts the full default 63-suite CLI run and refuses to overwrite an existing full log. The five-suite targeted run is separate. `verify.py` checks current source bytes against Git, compilation hashes, evidence, logs, negative regression binding, native sources/events and production release XML. It rejects the test XML as a release. `verify.py --require-full` additionally requires completed Windows and successful Linux CI gates.

The native review log is `0.744.0.7441077_20261022T101521Z_Studio_6233D_last.log`; bounded events, source manifest, guard and probe are retained here. No live saved data was touched and no publication occurred. Broader audit work remains open.
