# Jumping Spider Sim — T09 part 1 handoff (checkpoints and first accessibility pass)

Written by Claude on 2026-10-10, continuing from Chet's chunk 8 (`docs/HANDOFF-chunk-8.md`, evidence 182235d71390 / 779a6714b373). Nathan asked Claude to continue with T09, finish the deferred L01 save/load test, and keep the approved movement, camera and hunting mechanics. **No movement, camera, jump, silk, prey or feeding tuning was changed.**

This is T09 **part 1**. It covers persistence (S01-C, S02) and the first accessibility pieces (remapping, controller help, text size). The rest of T09 (controller remapping, reduced-effects/nonvisual options, assisted presets, and the human gates) is listed under "Next".

## Build identity and verification

- Branch `claude/jolly-bell-gq3mm8` on https://github.com/socranates/jumping-spider-sim (based on main 9f95de0). Final evidence: **4267a104376a** (source c3cf797e, settings 8b6707d4 unchanged, tests 46b6a141).
- Engine: Godot 4.7.2 stable, Linux x86_64 headless (downloaded into Claude's cloud container; not Nathan's PC, not Windows, no GPU). Compatibility renderer, Jolt, 60 ticks/s.
- Full suite at accelerated fixed 60 fps: **502 tests, 502 passed, 0 failed, 0 not run**. No test is deferred any more: the L01 save/load test now runs and passes. Report: `docs/verification/t09/full_report_t09.txt`.
- The four new or changed persistence/access files at fixed 30 and fixed 144 fps: 22 of 22 at each (`fps30_new_tests.txt`, `fps144_new_tests.txt`).
- Main scene smoke run (180 frames, headless): no errors or warnings.
- Software-rendered stills (Xvfb + Mesa, not a GPU, not a human playtest): `docs/verification/t09/t09_*.png`. They show the checkpoint caption, the pause menu at 100 % and 150 %, the restored world's notice and the field notes.
- **Not run on Windows.** Please run `run_tests.bat` and `snapshot.bat`; the Windows `evidence_id` should match the one above if the checkout is byte-identical (`.gitattributes` keeps the bytes).
- Baseline check before any change: this container reproduced Chet's numbers on main (482 tests, 481 passed, 1 not run, evidence 779a6714b373).

## How to play the new parts

- **Checkpoint.** Walk home to the silk-lined crack at the west end, stop, press E / X to rest. The top-left caption says **"Checkpoint kept."** That rest saved the whole sill (you, your energy and what fed it, every fly and what it was doing, the shadow event's clock).
- **Return to checkpoint.** Esc / Menu → **Return to checkpoint**. It works from anywhere and in any state (walking, mid-air, hanging on silk, mid-meal): the current world is discarded and the sill comes back exactly as it was at your last rest. The caption says "Returned to the checkpoint … checkpoint recovery, not an exact resume." Before your first rest the button is greyed out and the menu says how to make one. The checkpoint is on disk, so it also works after quitting and starting `play.bat` again; a new launch still starts a fresh sill.
- **Keys.** Esc → **Keyboard keys...**: pick an action, press the new key. Esc stops without changing anything. A key already in use is swapped, and the menu says what moved. **Reset keys** restores the defaults. Walk forward/back also move reel in/lower. Controller buttons are unchanged.
- **Text and panel size.** Esc → "Text and panel size", 100–150 %. The 3D view is unchanged. The menu scrolls if it gets too tall.
- **Field notes from a controller.** H, or the controller's View / Back button. The notes and prompts name your remapped keys.
- Everything else (movement, camera, Focus, stalking, jumping, silk, feeding, rest, the shadow) is exactly as chunk 8 left it.

## What changed

New: `scripts/persistence/` — `checkpoint.gd` (boundary check, capture, full validation), `checkpoint_store.gd` (safe file writes), `record_math.gd` (plain-record helpers).

- `main.gd`: builds a world from a validated checkpoint record (`restore_record`); `save_checkpoint()`, `available_checkpoint()` and `return_to_checkpoint()` (swaps in a freshly built world and frees the old one). It also applies the text size setting.
- `habitat_loop.gd`: the rest makes the checkpoint at the end of its tick, and the caption shows notices. It restores the habitat record and has a short grace while a restored spider takes hold. Field notes use the `help` action, and on-screen key names follow remapping.
- `prey_director.gd`, `prey_population.gd`, `fly.gd`, `fly_mind.gd`, `fly_senses.gd`, `fly_flight.gd`: each owns `to_record`/`apply_record` for its own state. The director restores flies by id/serial/seed and draws nothing from any stream.
- `windowsill.gd`: perch, vent and surface IDs are now named constants (`PERCH_POINTS`, `VENT_POINTS`, `SURFACE_IDS`, `CONTENT_REVISION`), so a checkpoint is validated before anything is built. The perch, vent and surface values are unchanged.
- `needs_model.gd`: one clamp (T9-06). It fixes a rare -2e-9 accumulator remainder that made NeedsModel's own record fail its own loader.
- `settings.gd`, `input_setup.gd`, `pause_menu.gd`: keyboard remapping, the `help` action (H / View), `ui_scale`, and the Return to checkpoint button with its status line. The pause panel now scrolls.
- Tests: `test_s01c_checkpoint.gd` (7), `test_s02_checkpoint_store.gd` (7), `test_u01_access.gd` (6), and the L01 save/load test implemented. `world_test_case.gd` points interactive test worlds at a test save folder, never the player's saves.
- `docs/DECISIONS.md`: T9-01 … T9-09 appended (the review-3 block was not touched).

## Gate status (honest)

| Gate | Status |
|---|---|
| **S01-C** | Automated checks pass. Rest makes a checkpoint, and loading restores the whole sill, with fly/perch/capture/schedule records identical after a load. Two loads continue identically, and loading twice duplicates nothing. Loading while airborne, preparing or feeding discards the world; a refused record never replaces it. Hanging is not separately scripted in the windowsill: there is no miss fixture there, and the load path does not depend on the spider's state. |
| Original S01 | **Deferred** (A-001). Exact resume from airborne, hanging or feeding states is not claimed. |
| **S02** | Automated checks pass. Truncated file → backup used, damaged file left untouched. Edited number → checksum refusal. Newer schema → reported and untouched. Stale temp file → never read. A damaged current file never pushes out a good backup. Inconsistent records are refused with a reason. Interrupted writes are simulated by leaving partial files, not by killing the process mid-write on Windows, so crash safety on the supported platform is not yet claimed (spec 22.4). |
| **L01** | Both halves pass: the four feeding fixtures, and save/load with a part-eaten fly (three loads, 39 checks). |
| **U01** | **Partial, not claimed.** Done: remapped keys drive the real actions and survive restart, every loop action has a controller input, field notes are reachable from a controller, text size works, toggle preparation/stalk/Focus exist, and the game has no audio, so it is mute-readable by construction. Still needed: a human completing the loop controller-only, with remapped keys, toggle preparation and sound muted. Controller remapping is also not built yet. |
| **W01** | Unchanged from chunk 8 (visible warning text and light change, pause freezes it). The formal mute-readable playtest is still open. |
| E02, M04 (graphical), F01 | Still open, as in chunk 8. |

## Known limitations and choices to check

1. **The perception memory is not saved.** After a load the spider has no last-seen marks or contacts; it re-notices the flies within a moment. This is presentation-adjacent; save it later if it matters.
2. **Developer history restarts after a load**: fly traces, event logs and cost counters. The capture list and the counts the books depend on are kept.
3. **Only the windowsill has checkpoints.** The lab is a regression fixture and refuses with a reason.
4. **One checkpoint slot** plus its backup. Each rest overwrites the current one, and the previous one becomes the backup. There is no death in P0, so the "never erase the only recoverable state after a death" rule (spec 22) does not yet bite.
5. **A fresh launch does not auto-load the checkpoint**; Return to checkpoint in the menu does. Say if you'd prefer launching to resume.
6. **Text size scales all 2D UI.** At 150 % on a 720p window, the top-left caption and the fly labels get large. Check whether 125 % is the more useful maximum.
7. A mouse drag on the text-size slider applies when released; keyboard/controller steps apply at once.

## Next

1. Nathan: `run_tests.bat` + `snapshot.bat` on Windows. Play: rest in the crack, wander and eat a fly, then Return to checkpoint. Is the fly back, is the energy back, does it feel like recovery and not a cheat? Try remapping one key and the text size, and try the field notes with a controller if you have one.
2. T09 part 2: controller remapping; reduced-effects and nonvisual cue options (spec 17; there is no audio yet, so "visual alternatives to audio" is trivially met); assisted-play presets; a Windows interrupted-write test. Then the human U01/W01 sessions.
3. Keep the lab fixtures. Don't revive the arbitrary-state S01 silently.

---

## T09b — the feel of the hunt (same branch, added after Nathan's notes)

Nathan asked for twitchy jumping-spider movement, a fly that looks to and fro while you creep, a tap-to-hold struggle with a depleting bar, hunts that are deliberately slow and challenging, and a leaf on the sill that gives way so the silk can catch you. Decisions T9b-01 … T9b-06.

**Evidence:** **8149fa0be2b8**, full suite **511 / 511 passed** (Linux headless, fixed 60 fps), `docs/verification/t09b/full_report_t09b.txt`. Hunt, struggle, leaf and save tests 37/37 at fixed 30 and 144 fps. Main scene smoke run clean. Stills: `t09b_struggle.png`, `t09b_pause_menu.png`. Tuning measurements: `tuning_run.txt`. **Not run on Windows.** This supersedes the evidence ID in the first half of this file for the branch head.

**How the hunt plays now**
- Watch the fly. It turns to look one way, then the other, every second or two. **Move while it looks away; freeze when it looks back.** A steady creep in plain view gets you spotted around 4 WU. Patient, timed creeping gets you to striking range in roughly 15–20 s from 7 WU. Quick dashes while it looks away work too, but they're riskier up close.
- Strike from about 2 WU. A long leap usually fails.
- **After the catch the fly struggles:** "IT STRUGGLES!" and a grip bar. Tap E / X (about twice a second) to keep the bar up until it goes still (about 3 s). Stop tapping and it tears free and flies off. Holding the button down doesn't count. Esc → "Struggling prey: hold on automatically" if tapping is hard.
- The spider twitches: snappy turns, stop-and-dart steps, a crouch while aiming, little flicks when still. It's display only. Esc → "Reduced motion" calms it.
- The pale dry leaf tip past the east leaf (upper route, far end) looks like a landing. Jump at it and it gives way; your silk catches you; W reels you back up. It grows back after 8 s.
- A checkpoint saved by the first build of this branch still loads (it's upgraded).

**Gates affected:** A01 and L01 still pass. The hunt tests now describe the new design (see T9b-02). U01: the struggle has an automatic option, as spec 17 requires.

**Open / to check by playing**
- Is ~17 s per approach the right amount of "slow and challenging", or too much? The knobs are four numbers in `data/species/fly_like_prototype.json` (rear_gain, motion_scale_deg_s, loom_scale_deg_s, glance_interval_s).
- Are two taps a second right for the struggle? Constants at the top of the struggle section in `scripts/needs/feeding_controller.gd`.
- Is the glance readable at a distance? The fly is small; a visible head turn may need a stronger cue later, e.g. the leg-animation pass, or an optional facing marker.
- Leg animation is welcome later (A-018 keeps it cosmetic); the twitch layer in `spider_body.gd` is where it would attach.

---

## T09c — living flies, the struggle fixed, a slower approach (2026-10-11)

After Nathan played T09b: the approach can be slower; the tapping wasn't working; flies should walk and fly about like real flies; Space for the taps. Chet's review 5 and native Windows run are folded in. Decisions T9c-01 … T9c-09.

**Evidence:** **25d403c1ee02**, full suite **519 / 519 passed** (Linux headless, fixed 60 fps), `docs/verification/t09c/full_report_t09c.txt`. Hunt, struggle, save and support tests 116/116 at each of fixed 30 and 144 fps; the F4 test file 11/11 at normal speed (on 3c6b1633485e, the same code but for where a struggling fly is drawn); main scene smoke run clean. Tuning: `docs/verification/t09c/tuning_run.txt`. Still: `t09c_struggle.png`. **Not run on Windows**, so please rerun `run_tests.bat`, especially for the F4 test Chet saw fail.

**What changed for the player**
- **Flies are alive.**
  - They walk about their spot in quick stop-start bursts, turning as they go, then stop to glance around, groom or fidget.
  - Every half minute or so one takes off by itself, often looping out through the open air before it lands somewhere else.
  - In flight they wobble a little.
  - A walking fly is a moving target: watch where it is, not where it was.
- **The approach is slower.** Shift creeps at 0.65 instead of 0.8, and flies notice looming a little more. Move while it looks away, freeze when it looks back. A careful approach takes about 20 s from 7 WU.
- **The struggle works.**
  - After a catch, tap **Space** (or E; A or X on a controller) to keep the grip bar up. It waits until you've landed.
  - You can see the fly buzzing and kicking in front of the spider's head.
  - When it goes still, the spider starts eating by itself ("Subdued."), and your last few taps don't hop or stop the meal.
  - Let the grip run out and "It tore free!" shows as the fly escapes.
- Prompts name your remapped keys everywhere.
- A newer-version or damaged checkpoint is never deleted. It's kept aside as `checkpoint.newer.json` or `checkpoint.damaged.json`.

**Chet's branch** (`codex/packaging-spider-legs`, PR #2) adds Windows and web export presets, a standalone leg prototype and his review. It's based on this branch's 3da4727 and touches no files of this round, so merging PR #1 first and then #2 should be clean. The leg prototype isn't wired in yet; when it is, it replaces the static legs in `spider_body.gd` and should keep the twitch layer.

**Open / to check by playing**
- Do the flies feel real now? Things to tune: walk frequency and distance, how often they fly off, and how wide the loops are.
- Is about 20 s per approach right?
- Is the struggle readable and fun with Space? Its constants are at the top of the struggle section in `feeding_controller.gd`.


## T09d — controller buttons and assisted-play presets (2026-10-11)

Claude did this while Chet's live-legs work waited for his usage to reset. Nathan's son (almost 6) plays, so Most help is meant for him. Decisions T9d-01 … T9d-05.

**Evidence:** **EVIDENCE_ID**, full suite **TOTAL_TESTS passed** (Linux headless, fixed 60 fps), `docs/verification/t09d/full_report_t09d.txt`. The new tests, the U01 tests and the T09c prompt tests pass at fixed 30 and 144 fps too (`fps30_access_tests.txt`, `fps144_access_tests.txt`). Stills: `t09d_pause_most_help.png`, `t09d_keys_and_buttons.png` (100 %), `t09d_keys_and_buttons_150.png`, `t09d_field_notes.png` (a remapped button named in the notes). **Not run on Windows.**

**What changed for the player**
- **Assisted play** at the top of the pause menu: Standard, Guided hunting, No held buttons, Most help. The line under it says what the chosen one does; change any switch and it says "Custom". Presets leave the camera, the text size, Reduced motion and the jump reach alone.
- **Controller buttons can be remapped.** Esc → **Keys and buttons...** now has a controller column. Choose a button, then press the controller button or pull the trigger you want (Esc or Menu stops). Walking and looking stay on the sticks; Menu and Guide can't be given away. **Reset keys and buttons** restores both.
- Every prompt names the player's key and button (the field notes, the rest prompt, the struggle and the eat prompts, the line and aim hints, the pause menu's labels).

**Files.** `scripts/core/input_setup.gd` (pad numbers and names, `events_for` with a pad), `scripts/presentation/settings.gd` (`get_pad`/`set_pad`, `[pad_bindings]`, `PRESETS`, `apply_preset`, `current_preset`), `scripts/presentation/key_names.gd` (buttons, two-pass replace, `both`), `scripts/presentation/pause_menu.gd` (presets row, controller column), `scripts/habitat/habitat_loop.gd` and `scripts/needs/feeding_controller.gd` (prompts), new `tests/integration/test_t09d_controller_presets.gd` (8 tests).

**For Chet (live legs).** None of your open files was touched: `main.gd`, `spider_body.gd`, `spider_legs.gd`, `test_spider_legs.gd`, `test_live_spider_legs.gd`, and your capture script. Commit your work on a branch, then merge `main` into it; there should be no conflicts. The evidence id will change because the scripts and tests changed.

**Still open from T09 part 2:** global slow time and a separate survival-pressure setting (they need `main.gd`, so after the legs are merged); a Windows interrupted-write test; the human U01, W01, E02, M04 and F01 sessions.
