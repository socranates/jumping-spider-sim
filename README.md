# Jumping Spider Sim

A third-person prototype about living as a jumping spider. The design is in `docs/SPEC.md` (frozen) and `docs/DECISIONS.md` (accepted changes).

Shared development: see [the agent handoff](claude/where-we-left-off.md), [GitHub workflow](docs/SHARED_WORKFLOW.md), and [verification reports](docs/verification/).

## New: sound and the spider's other senses (2026-10-11)

- The room hums, flies buzz from where they are, and a fly struggling in the jaws buzzes louder.
- When a fly lands, takes off or walks on a surface joined to the spider's, the spider **feels** it: a low thrum, a ripple on that side of the screen, and a caption such as "[felt: footsteps, behind-left]". It never crosses an air gap.
- Captions show every cue, so the game works muted.
- Esc menu: Volume, Room sounds, Flies and vibrations, Captions, Controller rumble, and **Headphones**. Off by default, which is tuned for laptop speakers; turn it on with headphones for the deep, full sound.

## New: slow motion, and an easy view switch (2026-10-11)

- **Slow motion:** press **T** (controller **right trigger**). The whole world slows evenly: the spider, the flies and the jump. Press again for normal speed. Esc → Slow-motion speed: 25, 50 or 75 %.
- **First or third person:** press **V** (controller **Y**), or use the button in the Esc menu. A line at the top right says which key does it.
- A 20-minute playtest checklist is in `docs/PLAYTEST.md`.
- **The struggle (after Nathan's playtest):** tap fast to fill the grip bar. A full bar subdues the fly at once. Two taps a second isn't enough any more, and the fly weakens as the bite's venom works.

## New: spider-eye view (2026-10-11)

Press **V** (controller **Y**), or Esc → **Spider-eye view**, to see through the spider's eyes. Only a small oval in the middle is sharp: that is where the two big front eyes point, and they see green and ultraviolet but no red. The rest is soft and nearly colourless, as the six other eyes see it. Look further than the front eyes can reach and the spider turns to face it. It's an impression, not a recording of what a spider sees (`docs/HANDOFF-eye-view.md`). Press V again for the normal camera.

## Getting the latest version

After Claude or ChatGPT says their work is done, **double-click `update.bat`**. It downloads the newest version from GitHub into this folder; then double-click `play.bat`. It never throws away your own changes: if it finds any, it stops and shows them. (By hand, in a command window in this folder: `git checkout main` then `git pull`.)

## Current build: T09 part 1 — checkpoints and first accessibility pieces

Claude added these on 2026-10-10 on top of chunk 8 (see `docs/HANDOFF-chunk-9.md`). Movement, camera, hunting and feeding are unchanged.

- **Checkpoint.** Resting in the silk-lined crack (E / X) keeps a checkpoint of the whole sill: the spider, its energy, every fly and the shadow event. The caption says "Checkpoint kept." **Esc → Return to checkpoint** puts the whole sill back to that moment from any state (walking, in the air, on silk, eating). It is recovery, not an exact resume. Checkpoints are in `%APPDATA%\Godot\app_userdata\Jumping Spider Sim\saves\` (`checkpoint.json` and the previous one, `checkpoint.bak.json`). A damaged file falls back to the backup and is never overwritten by loading.
- **Keys and buttons.** Esc → **Keys and buttons...**: choose an action's key or controller button, then press the key, button or trigger you want (Esc or Menu stops). One in use is swapped. Walking and looking stay on the sticks. Reset keys and buttons restores the defaults.
- **Text and panel size** (Esc), 100–150 %.
- **Field notes**: H or the controller's View / Back button.

**T09d — assisted play (2026-10-11).** Esc → **Assisted play** sets several switches at once, and the line under it says what each does. **Standard** is the hunt as designed. **Guided hunting** adds a wider reach for the bite, shows the jump arc and where the spider looks, and holds a struggling fly for you. **No held buttons** turns aiming, stalking and Focus into press-to-start, press-to-stop. **Most help** combines both and is a good start for young players. Controller buttons can now be remapped too (above).

**T09c — living flies (2026-10-11).** Flies walk about in quick stop-start bursts and sometimes take off by themselves, looping through the air before landing elsewhere. Shift creeps more slowly (0.65). After a catch, **tap Space** (or E) to keep your grip: the fly buzzes and kicks in front of the spider's head. When it goes still the spider starts eating by itself; if the grip runs out it tears free.

**T09b — the feel of the hunt.** The fly now glances to and fro: move while it looks away, freeze when it looks back. A steady creep in plain view gets you spotted, so hunts are slow on purpose. The spider twitches like a jumping spider (display only; Esc → Reduced motion). After a catch the fly struggles: tap E / X to keep the grip bar up until it goes still, or it tears free (Esc → "Struggling prey: hold on automatically"). The pale leaf tip past the east leaf gives way when you jump at it, so your silk catches you.

## Chunk 8 — the windowsill

Chet implemented T08 on 2026-10-10. **Run `play.bat` for the windowsill** or `play_lab.bat` for the previous traversal lab. The mechanics and tuning remain unchanged. The sill has four flies, a ground route, an upper leaf/rim route and a physical silk-lined crevice at the west end. Walk into the crevice and press E / controller X to rest; movement, jumping or cancel ends rest immediately. Holding prey gives feeding priority.

H opens field notes. A harmless shadow approaches after about a minute (deferred while resting or feeding); it warns before crossing the sill. It changes no collision or jump forces. (Chunk 8 had no save system; T09 above adds the retreat checkpoint.) See `docs/HANDOFF-chunk-8.md` and `claude/where-we-left-off.md` for verification and continuation.

The following chunk-7 description is historical background; the new launch scene is the windowsill.
This is chunk 7, part B, of the build: the first living prey (task T07, gates A01 and L01), described under "The first fly" below. It follows chunk 7's part A (below) and chunk 6 (parts A and B): chunk 6's part A, a recovery-readability check and small corrections after the design review (A-017 to A-020, below); part B, the first perception (task T06, gate P01): the spider notices movement at the edge of its sight, can turn to look at it and learn what it is, remembers it for a while, and the screen shows only what it has sensed. All of it sits on top of chunk 5 (task T04 of spec section 26, one safety line, and the first handback for review, T05, `docs/HANDOFF.md`), chunk 4's T03 (the shared jump solver), chunk 3's T02 (supported locomotion) and chunk 2's T00 and T01. The placeholder spider walks on floors, up walls, over edges and upside down along undersides in a graybox lab, with an orbit camera that never rolls, named inputs, a pause panel with saved settings, and an automated test runner. It jumps: tap Space for a short hop, hold it to aim at any surface under the screen-centre reticle, and a landing patch tells you before you let go whether the leap will work. Leaps now reach about 11 WU on the level, and a leap from a surface that can hold silk trails a safety line: miss, and the line catches you, you hang below the edge, and you can reel in, lower yourself or let go. Chunk 6's labelled test target, not a fly, still stands on its stage ("What the spider senses", below), and now there are flies too ("The first fly", below). Chunks 6A and 6B did not change how it walks, jumps or hangs. 6A changed how the catch is shown (the camera turns side-on to keep the spider, the edge and the line in view; the line is a dark thread with a light rim that reads on pale and dark backgrounds; a note says when its anchor is out of sight; the catch gives the model a small cosmetic recoil) and how a test result is tied to what produced it; 6B added what the spider senses and capped the camera's turn at the catch at 45 degrees. Chunk 7A, after the design review of chunk 6, changed how the spider senses and remembers and not how it moves: a small thing wholly behind a thin barrier is no longer seen through it (A-024); what the spider remembers is its own idea of "that thing", matched by evidence after it has lost sight and no longer by the world's name for it (A-027); and Focus can be set to toggle (A-026). Walking, the camera, the leaps and the line are as they were. Chunk 7B adds the first living prey and nothing else about how the spider moves: one kind of fly that watches with its own senses and flies off when it sees something worth fleeing, a strike that can catch it, a short cancelable meal that gives energy, and a quiet energy bar. Walking, the camera, the leaps and the line are still as they were.

## Engine

- Godot 4.7.2 stable, standard build (not the .NET build). Checked headless on Linux as `4.7.2.stable.official.ed1daf0bf`.
- Renderer: Compatibility (`gl_compatibility`).
- Physics: Jolt Physics, 60 ticks per second, physics interpolation on.
- Units: 1 world unit (WU) = 1 cm. The reference body length is 1 WU.

The test suite passed 177 of 177 on Windows with Godot 4.7.2.stable.official.ed1daf0bf (chunk 4, report 2026-10-05T09:46:22Z), and chunk 5's 209 of 209 on Windows in Chet's run (report 2026-10-07T06:24:11Z, A-014). Chunk 6B's suite, 338 tests, passed on Windows too: a report dated 2026-10-07T15:40:54Z (`evidence_id` 4b9098e032ed), and Chet's own native run at `--fixed-fps 60`, 338 of 338 (review 3, A-023). Chunk 7A's suite, 381 tests, and chunk 7B's, 469 tests (468 passed and one marked not run: the save and load part of gate L01, because there is no save system yet), have so far only run on Linux (inside the Cowork VM), not on Windows. The intermittent failure of `test_camera.gd` in the Windows run of 2026-10-07 (report 06:14:45Z) was a race in placing the camera on the first frame; 6B fixed it and tests it at 15, 30, 60 and 144 frames a second, and the two 338-test Windows runs above had the fix. `run_tests.bat` writes the exact Windows engine version into `tests\reports\last_report.txt`.

## Play on Windows

1. Download Godot 4.7 stable for Windows from godotengine.org and unzip it anywhere, for example into Downloads.
2. Double-click `play.bat`.

`play.bat` reads the exe path from `godot_path.txt` (one line, the full path). If that file is missing it searches Downloads, Desktop, OneDrive\Desktop and OneDrive\Documents, up to two folders deep, for `Godot*_win64.exe` and saves the first match to `godot_path.txt`. If it finds nothing it tells you how to fill the file in. `godot_path.txt` is local to your machine and ignored by git.

From the editor: open the folder in Godot and press F5.

## Run the tests

Double-click `run_tests.bat`. It uses the console build of Godot (`Godot*_win64_console.exe`, next to the normal exe), imports the project, runs `tests/test_runner.tscn` headless, and ends with an exit code: 0 only if every test passed. It takes about seventeen minutes (16.4 in the Linux VM: the fly tests wait in game time).

- `tests\reports\last_report.txt`: timestamp, engine version, three hashes that say what was tested (`source_hash_md5` for `scripts/`, `scenes/` and `data/`, `settings_hash_md5` for `project.godot`, `tests_hash_md5` for the tests) and the `evidence_id` made from them, test count, passed, failed and not-run counts, fixture seed, one line per test. The `evidence_id` is also printed before the `SUMMARY` line and at the top of the gate reports.
- `tests\reports\last_console.txt`: everything Godot printed, both streams.
- `tests\reports\m01_report.txt`: the M01 route gate (spec 25), one line per run: 20 spiders walk floor, wall, over the edges and along the underside and back.
- `tests\reports\m02_report.txt`: the M02 jump gate (spec 25): 100 legal jumps between static surfaces, reach 2 to 5 WU and several heights, through the real jump controller, one line per jump with the planned and the actual landing centre and the error (the gate is 0.25 WU or less), then the max and mean, then the invalid candidates, which must show invalid feedback and must not launch.
- `tests\reports\m03_report.txt`: the M03 safety-line gate (spec 25): ten fixtures where a leap misses and the line must catch the spider, and recovery by reeling in, lowering or letting go must reach a surface or report that it is blocked. One result per fixture, with how long the catch took, how much line was out, the bend point, how it ended, and how many ticks were checked for overlap with the world, a push from the line and an unexplained energy gain (the gate is "no unexplained energy gain within the documented allowances"). Lengths are in WU, and 1 WU = 1 cm = 10 mm.
- `tests\reports\p01_report.txt`: the P01 perception gate (spec 25): eight fixtures with the labelled test target. A cue gives a direction and nothing finer; orbiting the camera grants no inspection; holding Focus turns the body and the classification improves after the configured inspection period (0.40 s, then 1.00 s); a hidden target does not update the observation and no coordinates of it reach the screen; the last-seen mark stays put, goes stale and expires; when the target is seen again it is picked up as the same contact by the evidence (where it was, how long it was away, its size), even if the world has renamed it meanwhile; inspecting the empty remembered spot drops the mark; a target never sensed leaves nothing on the screen. One block per fixture, with what was measured.
- `tests\reports\a01_report.txt`: the A01 gate (spec 25, chunk 7B): five fixtures. Pressing the jump button, Focus, the camera and interact with the spider standing still changes nothing for the fly (it does exactly what it does with no buttons at all) while walking at it does; the spider's motion behind a wall does not startle it and the same motion in plain view does; a fly that is walked up to flees and its trace and its F4 label explain every step; one strike makes one capture, with a stable event id and an owner, before any energy exists; and the fly's scripts name no input, aim, jump, Focus, camera, feeding, needs or spider. One block per fixture, with what was measured.
- `tests\reports\l01_report.txt`: the L01 gate (spec 25, chunk 7B): four fixtures. A whole meal audited tick by tick (energy rises only while the meal is valid and every gain is in the ledger); nine meals cancelled at random moments by every route leave one fly, captured once, and a ledger equal to what it gave up; refusals grant nothing and say why, and a full reserve is not overfilled; the real E and Q buttons start and stop it and the stick is the player's again at once. The save and load part is reported as not run (there is no save system yet, T09).
- `tests\reports\t07_cost_report.txt`: what six flies cost (spec 24): CPU microseconds per tick (average, median, 95th and 99th percentile, largest) for the prey tick and the sensor tick, over 15 s of the spider walking among them, and how many candidates, rays and sweeps they asked for per tick. A measurement of the machine that ran it, not of any player's.
- `tests\reports\catch_camera_report.txt`: the catch camera check (A-017): the cliff-cap catch and grab, and the slab-edge catch, with no camera input, measured every physics tick, with the camera of chunk 5, with the line framing as it ships (turns capped at 45 degrees) and with chunk 6A's uncapped framing, how long the view of the recovery is crowded, and a verdict.

Old reports are deleted before each run, so a report always belongs to the run that just happened (`tests\reports\snapshots\` is never deleted). Zero tests counts as a failure. Two tests deliberately trigger an engine error message (a corrupt settings file and a rejected setting); the runner marks them as expected.

**Keeping the state that was tested.** After a run, double-click `snapshot.bat`: it writes `tests\reports\snapshots\<UTC date>_<evidence id>.zip`, a complete copy of the project (everything except `.godot\` and `tests\reports\`), with a `SNAPSHOT.txt` first that carries the hashes. It is an ordinary zip: right click, Extract All. If nothing changed between the test run and the snapshot, the file name carries the same `evidence_id` as `last_report.txt`. Details are in `docs/TOOLCHAIN.md`.

The same thing by hand: `godot --headless --path . res://tests/test_runner.tscn`. Add `-- --seed=123` to change the fixture seed. To run part of the suite, add `-- --only=unit`, `-- --only=integration` or `-- --only=gates` (a comma-separated mix works), `--part=1/2` for the first of two slices of the selected files, or `--files=tether` for the files whose names contain that text. The run's last line, `SUMMARY tests=... result=PASS`, says what ran and how it was filtered. `--fixed-fps 60`, an engine option that goes before the `--`, runs faster than real time: fine for checking logic, not for timing. The whole suite is about 981 s of real time, so a tool that cuts a call off at three minutes needs it in parts: `--only=unit`, `--only=integration --part=1/12` to `--part=12/12`, `--only=gates` (`docs/TOOLCHAIN.md`).

## Controls

| Action | Keyboard and mouse | Controller |
|---|---|---|
| Walk | W A S D | Left stick |
| Look | Mouse, or the arrow keys | Right stick |
| Stalk (slower) | Hold Shift | Left shoulder |
| Hop | Tap Space | Tap the south button (A) |
| Aim a leap | Hold Space (about 0.15 s) | Hold the south button |
| Leap | Release Space | Release the south button |
| Cancel the jump | Q | East button (B) |
| Reel in (on the line) | W | Left stick up |
| Lower (on the line) | S | Left stick down |
| Let go of the line | Hold Q (0.6 s) | Hold the east button (B) |
| Recenter camera | R or middle mouse | Right stick click |
| Focus (turn the body to look where the camera points) | Hold the right mouse button | Hold the left trigger |
| Eat the prey you are holding (standing still) | E | West button (X) |
| Stop eating | E again, or Q | East button (B) |
| Pause and settings | Esc | Menu button |
| Debug overlay | F3 | none |
| Support view | F4 | none |

The stalk key can be changed to press-to-toggle in the pause panel. The overlay shows FPS, motor state, position, velocity, whether the spider is supported, the support surface and its profile, the support normal, camera boom length and the engine version, and, when a safety line is out, the line: its mode, anchor surface and point, the length paid out, the rest length and the maximum, whether it is taut and whether the spider is held at rest, the bend point, the reel intent and why reeling stopped, if it did. The support view draws the support normal (yellow arrow), the contact point (magenta dot) and the probe rays of the last physics tick (green where they hit, red where they found nothing), on top of everything, and the safety line: anchor (white dot), bend point (magenta dot), the line itself (cyan while slack, red while taut) and the circle the line will not let the spider leave (yellow, dashed). Jumping and the line are described below. F3 also shows the Senses: what the sensor has tracked, how many cues and rays it made, and what the memory holds (each contact's state, category and confidence). The support view (F4) also draws the spider's two cones, a developer's view of the senses: the 30 degree inspection cone (cyan) with the gaze axis (white), the 300 degree peripheral field (a violet arc), a green or amber sphere where the memory has the target (live or lost), and a small red marker where the target really is, so that you can see the memory not following it.

Hold Focus to turn the spider's body toward where the camera points, at up to 180 degrees a second ("What the spider senses", below); while it is on, four small ticks mark the centre of the screen. If holding a button is hard, the pause panel's "Focus toggles (press to start and stop)" makes it a press to start and a press to stop (Q / B stops it too when it has nothing else to cancel): "FOCUS ON" shows at the top of the screen while it is on, it ends by itself when the spider leaves its surface in a leap, a fall or on the line, and a press while off the surface does nothing, so it never gets in the way of a leap or a recovery. Also registered, with no behavior yet: interact (E, west button). On the line, W and S reel and lower instead of walking.

## Walking on walls and undersides

Walk into a wall and keep pushing: the spider climbs it. Walk over an edge: it rolls round the edge onto the face beyond, if that face can hold it. Walk off an edge where nothing can hold it and it falls. Gravity only acts while it is falling.

- On floors and undersides, forward is away from the camera. On walls, forward is up. Right is always the camera's right.
- When the surface turns sharply at an edge, the spider keeps going the way it was going for as long as you hold the stick the same way, even if the camera's idea of "forward" has flipped. Release the stick or turn it by more than about 30 degrees and the camera mapping takes over again.
- Surfaces come from `data/surfaces/*.json` (spec 21.2). A surface holds the spider if it is attachable, or if it is within 45 degrees of level. The violet coating (`ptfe_coated`) is not attachable: you can stand on top of it but not climb it.
- The camera never rolls. Its pivot sits off the surface the spider is on, so under a ceiling it hangs below the spider. Under a ceiling the boom is short at the default pitch; look up (arrow up or mouse) to see the spider from below.

## Jumping

- **Hop**: tap Space. A short hop, 1.5 WU forward along the floor or ledge top you are on, planned the same way as a leap. It is refused, with a few words on screen, if something is in the way or there is nothing to land on ahead. Hops only start from surfaces that face up.
- **Leap**: hold Space for about 0.15 s. A reticle appears at the screen centre and a landing patch lies on whatever surface the reticle is on (the camera's centre ray, no snapping to targets). The spider turns toward it. Release Space to leap, or press Q to cancel. Nothing is ever launched at a spot the patch did not show, and the spider lands where the patch was, within a few hundredths of a world unit.
- **The patch** says what will happen by shape, colour and words under the reticle: a solid green ring is Reachable; an amber ring with a cross is Blocked (no room for the spider to land, or something is in the way); a dashed red ring is Out of reach; a dotted violet ring is Can't land there (that surface cannot hold the spider). Release on anything but Reachable and the jump is cancelled with a message; the spider stays where it is. Beyond 6 WU from the camera the whole patch grows in proportion to the distance (up to four times) so it stays readable across the lab; its centre is still the exact landing point. Opening the pause panel, or losing the window focus, drops an aim in progress, so it can never get stuck.
- **Aiming higher**: while aiming, vertical look tilts the view about the camera instead of orbiting, so a ledge top above the spider's head can be aimed at. Sideways look still orbits. The tilt eases back when you let go, and the camera does not swing round behind the spider at release.
- **In the air** the leap follows a fixed arc: no steering. If it comes down on something that can hold the spider, the spider attaches (floor, ledge, wall or underside, using the surface normal it hit). If it only grazes a surface or lands on something that cannot hold it, it falls. Leaving the lab's play area puts the spider back at its last supported spot, with a message.
- **Reach** (gravity 35, launch speed up to 20 WU/s, flights of 0.35 to 0.9 s; chunk 5 raised the launch speed and the longest flight from spec 21.1's 14 WU/s and 0.6 s so that jumps can go farther): about 11 WU on the level, 10 WU up onto a 1 WU rise, 9 WU up onto a 2 WU rise, 7.5 WU up onto a 3 WU rise, and about 14 WU down onto a surface 3 WU lower. The pause panel's "Jump reach (playtest)" scales this from 50 percent (about 5.5 WU on the level) to 150 percent (about 17 WU). A leap from a wall or an underside back onto the same plane is Out of reach, because nothing launches away from it.
- **F4** (support view) also draws the last jump: the predicted arc (cyan, dashed), the path actually flown (orange), and markers at the planned landing and where the spider first touched down.
- The pause panel has three jump options: "Jump aim toggles" (press Space to start aiming and again to leap; Q cancels; there is no tap hop in this mode) and "Show the jump arc while aiming" (draws the predicted arc along with the patch), both off by default, and "Jump reach (playtest)", 50 to 150 percent, default 100.

## The safety line

Every leap that starts on a surface that can hold silk anchors a line there at takeoff and pays it out behind the spider, up to 20 WU. The jump itself is unchanged by the line: it never steers or slows a leap that lands. A leap that lands completes the line: it is left behind, fades after about six seconds, and at most six old lines are kept.

- **Before you leap**, a line under the patch's label says "Safety line: anchored here". If the surface will not hold silk (the violet coating), it says "No safety line: this surface won't hold silk" and an amber cross shows on the spider (a white dot shows when the line can be anchored). The leap works the same, but a miss will not be caught.
- **A miss**: if the spider reaches the end of its leap with nothing to land on, or touches something that cannot hold it, the line locks at the length paid out (plus a short run-on) and the spider falls until the line takes the load: "Caught by your line". The line only pulls when it is taut and never pushes, so the spider swings like a pendulum, settles hanging below the last edge the line passes over, and then rests. One bend point is kept. If the line would need a second bend it snags: reeling stops, with a message, and lowering and letting go still work.
- **On the line**, W (left stick up) reels in and S (left stick down) lowers, both at 1.5 WU/s. Reel up under an edge and the spider takes hold of it and climbs on: "Holding on again". If something is in the way, reeling stops with a message and gives the line back. Hold Q (the east button) for 0.6 s to let go; a tap does nothing, so an accidental press cannot drop you. The pause panel's "Hold Q / B to let go of the line" can make it a single press, which still ignores the first 0.4 s after the catch. Q is also the cancel-a-jump button, so the prompts at the bottom of the screen change with the state.
- If the surface the line is tied to goes away, the line comes loose: "Your line came loose: its anchor is gone".
- **The camera at the catch** turns by itself while you are on the line: in steps of 15 degrees, only as far as it takes to keep the spider, the edge the line passes over and the line itself in view, eased over about a tenth of a second. It never rolls, never goes through terrain, and any look, recentre or aim takes the view back at once and keeps it where it is. When the line ends, the view stays where it is. The turn is capped at 45 degrees, and the pause panel's "Frame the line after a catch" (on by default) switches it off; any look input cancels a turn in progress. (Measured with no camera input, `tests\reports\catch_camera_report.txt`: in the cliff-cap catch from the default view, the camera behind the spider, the smallest turn that clears the cliff is 90 degrees, so at the cap nothing turns and the view of the recovery is as crowded as in chunk 5, 1.83 s and 3.83 s on the line and about 1.5 s in the 2 s after the grab; chunk 6A's uncapped turn made it 0.53 s and 0.57 s and none after the grab. A view turned 45 degrees to the side is framed within the cap: 0.40 s crowded, none after the grab. The catch under the arch slab is crowded for 2.35 s on the line and 1.53 s after the grab at the cap, as in chunk 5; chunk 6A's uncapped turn made it 1.52 s and none after the grab.)
- **The line** is a dark thread inside a thin light rim, never thinner than 2 px at 1080p (a little heavier while taut or reeling), hidden by the world where the world is in the way. Old silk is thinner, pale and translucent, and fades. When the line's anchor is out of sight, because the edge it passes over hides it, the prompts at the bottom say so: "Anchored out of sight, behind the edge your line passes over".
- **The catch** gives the spider's model a small, quick recoil along the line (under a tenth of a body length, about a third of a second). Only the model moves: the physics body, the line's length and the camera do not, and nothing shakes.
- **Practice**: the yellow perches (between the two towers, and east of the coated cliff) drop away when you aim a leap at them, so you can miss on purpose, hang, reel in and try again. They come back four seconds later.

## What the spider senses

Chunk 6B (task T06). The spider now notices things by evidence, as the design asks (spec 7), and the screen shows only what it has sensed. There is no prey yet. A labelled **test target** stands in for it: a magenta ball on a rod, not a fly, with no senses and no goals, which walks to and fro along a dark line behind a white screen.

**Where.** The stage is in the north-west of the lab. You start at (-22, 12) facing east. Turn to face north (the far wall), bear a little left and walk about 13 WU to the low block (x -26.5 to -22.5, z -4.2 to -1.2, 2 WU high), climb its south face and stand on top, facing north. The white screen (3 WU high) is 2.5 WU ahead and the ball's path is behind it; a sign on the wall behind says what it is. From the ledge the ball is in plain view at both ends of its path and hidden behind the screen for the middle of it. It walks at 0.8 WU/s and waits 1.2 s at each end.

**What you see, and what each thing means.**

- *A soft marker on the edge of the screen, with a small arrow:* something moved off to that side, in the corner of the spider's eye (it sees 300 degrees about where it looks and is blind straight behind). It says which way and nothing else: no place, no name. It pulses about every 0.8 s while the thing keeps moving in view.
- *Turning the camera toward it changes nothing.* The camera is yours, not the spider's. To look, hold **Focus** (right mouse button, left trigger; or press it to start and again to stop, if you switch that on in the pause panel): the body turns toward where the camera points, at up to 180 degrees a second, and the gaze tilts up or down a little to follow.
- *A thin ring and a word:* the spider's narrow cone of attention (30 degrees, along its gaze) has found it. The longer the thing stays in the cone, unhidden, the better the spider knows it: "movement", then "possible prey" after about 0.4 s, then "fly-like prey" after about 1 s. Never a number.
- *"lost sight" and a faint dashed ring:* the thing is gone (behind the screen, out of the cone). The ring marks where it was last seen. It does not follow the thing; it is fainter and more broken the older it is; it is gone after about 6 s; and it is gone sooner if you look at the place while it is in plain view and nothing is there. When the ball comes out again and you look at it, the spider takes it for the same thing if it is the only remembered thing it could be ("What counts as the same thing", below), and then it is known again faster. Where the screen is between you and the place, the ring is drawn a little fainter.
- *Nothing at all* for what the spider has never sensed, even where the camera can see it (spec 6.4).

**What counts as the same thing (chunk 7A).** The spider is never told the world's name for what it sees: a remembered thing is its own idea of "that one". While it keeps seeing a thing, it is the same one, and a blink of cover does not break that. After it has lost sight, a thing it looks at again is taken for the remembered one only if exactly one remembered place could fit: near enough to where it was last seen for the time that has passed (nothing is assumed to move faster than 2 WU/s, or than it was seen to move), about the same size (within a factor of 1.5), and not something that can never look like what was learned. If two fit, or none, it is a new thing that starts again at "movement", and the old marks fade on their own or are looked at and found empty. Nothing the thing did while it was out of sight is used. With one test target you will see it recognised as before; the tests put two look-alikes behind the screen to see the difference.

In the pause panel: "Show the last-seen mark" (on by default) and "Show where the spider looks" (off by default: a faint footprint on whatever the gaze lands on, which stops at walls and says nothing about what is behind them). F3 and F4 show the developer's view described under Controls.

## The first fly

Chunk 7B (task T07). There is something alive to hunt now: **fly-like prey**, one kind, a prototype that makes no claim about any real species (`data/species/fly_like_prototype.json` holds every number as visible data). It is a small dark body 0.7 WU long with red eyes and a pale wing. It sits on authored perches in the lab (21 of them: floor spots, the tops of ledges, the block, the towers and the slabs, two undersides and four wall spots; a small dark blot marks where there is food), fidgets, grooms for a second or two every so often, and now and then hops to another perch. The labelled test target of chunk 6B is separate and is still on its stage.

**Where.** A played world starts with four flies. You start at (-22, 12) facing east: one sits on the floor straight ahead, 9 WU away at (-13, 11.5); one on the open floor further east at (4, 11); one on top of the block at (-3, 3.4, 5); one on the top of the second ledge at (-8.5, 2, -12.5). The console prints "prey seed N" when the world starts; the same seed gives the same choices and reactions.

**What it senses, and what it does not.** Only what its own eyes would give it: how fast the spider's body moves across its field of view and whether it looms, how near it is (it sees to 14 WU, best within 3 WU, and less behind itself), and whether the line of sight is clear (three rays: a wall, a block or a ledge hides you). It never reads your buttons, Focus, the camera, what you aim at, or where you are when it cannot see you. Its awareness rises while it sees motion and falls when it does not: at 0.30 it goes ALERT (wings up, still on its perch), at 1.00 it flees; a sudden fast motion within 7 WU (70 degrees a second across its view) startles it at once. Between noticing and taking off there is a reaction delay, drawn from the fly's own seeded stream: 0.04 to 0.10 s if it was already alert, 0.16 to 0.36 s if it was calm, 0.28 to 0.48 s if it was grooming. A fleeing fly flies at about 15 WU/s to a perch away from you, swept against the world (never through a wall, never a jump from place to place), lands, and calms down again.

**Hunting it.** Walking up to it (2.5 WU/s) alerts it at about 4 to 5 WU and it is gone while you are still 2.5 WU or more away. Stalking (hold Shift, 0.8 WU/s) does not wake it, down to about 2 to 3 WU; closer than about 2 WU it wakes anyway. A leap is always seen: the fly startles at once, but needs its reaction delay to get off the perch, so a leap from 2 to 3 WU often gets there first (in 8 of 12 scripted trials from 2.6 WU) and a leap from 5.5 WU never does. A fly that is grooming is the moment to strike. If the strike misses, the fly escapes while you recover (hanging on your line, if you missed a leap). Nothing is a dice roll: a strike catches a fly if the spider's body passes within 0.7 WU of it (the fly's 0.4 and the spider's 0.3) with nothing solid between; one strike makes at most one capture; the spider holds one fly at a time. The pause panel's "Strike assist: a wider reach for the bite" (off by default) widens that reach by 1.6.

**Eating.** While you hold prey the screen says "Holding prey" (and "stand still on a surface, then E to eat" until you do). Press E (the west button) standing still on a surface: "Eating", and the energy bar rises by 0.1 a second, 3.5 s for a whole fly, 0.35 in all. Moving, jumping, leaving the surface, or pressing E again or Q (B) stops it at once and the controls are yours again; what the fly gave up stays given, the fly keeps the rest, and pressing E again carries on. A full bar ends the meal. The bar (bottom left, "Energy 55%") starts at 55% and drains very slowly (0.06% a second down to a floor of 20%): nothing in this build starves you or needs a meal.

**Replacements.** A fly that is caught or eaten is replaced after 25 to 45 s by a new one that comes in through one of four wall vents, only while the vent is outside the picture (the screen's edge plus 12 degrees), outside the spider's sight and at least 10 WU away; it appears on the vent and flies to a perch, never in view. This is a placeholder rule for the later ecology. Test worlds do not replace flies.

**The developer views.** F3 gains a "Needs" line, a "Feeding" line and a "Prey" block (the seed, the counts, the cost of a tick, one line per fly). F4 draws, for every fly, a label above it (id, state, goal, awareness, perch, the winner of its choice and the reason of its last change of state), a line from its eye to the spider while it sees it, its flight path in orange, and the perches and the vents (green: valid, red: the world refused it, amber: taken).

## Settings

The pause panel (Esc) sets look sensitivity, invert X and Y, field of view (default 65 degrees vertical), camera distance (default 5 WU, range 4 to 7), stalk toggle, jump aim toggle, Focus toggle (off: Focus is held), the jump arc display, jump reach (playtest), whether letting go of the line needs a hold, whether the camera turns to frame the line after a catch (on), whether the last-seen mark is shown (on), whether the footprint of the gaze is shown (off) and strike assist (off: a wider reach for the bite). Every change is saved at once to `user://settings.cfg`, which on Windows is `%APPDATA%\Godot\app_userdata\Jumping Spider Sim\settings.cfg`. Delete that file to go back to the defaults. A missing or damaged file also gives the defaults.

The mouse is captured while you play and shown while paused.

## The lab

`scenes/testbeds/traversal_lab.tscn` is a graybox room, 60 by 35 WU, floor top at y = 0, built by `scripts/habitat/traversal_lab.gd`. Each piece is one static body with one box shape, a flat colour per surface kind, and the metadata `surface_profile_id`. The spawn is at (-22, 0, 12) facing +X.

| Piece | Where |
|---|---|
| Ledges 1, 2, 3.5 and 5 WU high, 3 WU apart | x -16 to 5, z -14 to -11 |
| Ramp (about 25 degrees) up to a block 3.4 WU high with convex edges | ramp x -13.2 to -6, block x -6 to 0, z 2 to 8 |
| Gap: two 2 WU platforms 3 WU apart; the east one (violet) is coated and cannot be climbed | x 8 to 19, z -6 to -2 |
| Broad overhang, underside 3 WU up, joined to the east wall: climb the east wall to reach it | x 21 to 30, z 0 to 10 |
| Concave corner: two free-standing walls at a right angle | around (-20.6, -9.6) |
| Glass pane (surface `glass_clean`, attachable: jumping spiders climb glass) | x -12 to -6, z 15.5 |
| M01 arch: a 4 WU post carrying a slab that overhangs it by 8 WU. Up the post, over the top, round the far end onto the 8 by 6 WU underside, down the post | post x 9 to 11, slab x 9 to 19, z 4 to 10 |
| Coplanar seam: two 1 WU platforms touching, tops level | x 21 to 29, z -15 to -11 |
| Thin shelf, 0.2 WU thick, on the west wall | x -30 to -26, z -15 to -11, 1.5 WU up |
| Coated panel (violet), free-standing: cannot be climbed | x 11 to 16, z 14 |
| Two climbable 10 WU towers, 9 WU apart edge to edge, with a practice perch between their tops that drops away when a leap is aimed at it | towers x -18 to -15 and -6 to -3, z -4 to -1 |
| Coated cliff 6 WU high (cannot be climbed) with a wooden cap that overhangs it by 0.4 WU, and a practice perch east of it that drops away. Climb the east wall to 5 WU or more and leap west onto the cap | cliff x 21 to 25, z -9 to -5 |
| The prey's perches and vents (chunk 7B): 21 perches (small green boxes in the F4 view), four slits high on the walls that replacement flies come in by, and sticky blots where there is food | see `PREY_PERCHES` and `PREY_VENTS` in `scripts/habitat/traversal_lab.gd` |
| The perception stage (chunk 6B): a 2 WU ledge to watch from, a 3 WU white screen 2.5 WU in front of it, and a dark path behind it where the labelled test target walks | ledge x -26.5 to -22.5, z -4.2 to -1.2; screen x -25.6 to -23.4, z -6.3 to -5.8; path z -7.9, x -28.8 to -20.2 |

## Layout

```
scenes/          main.tscn, actors/spider.tscn, testbeds/traversal_lab.tscn
scripts/core/        main scene wiring, input actions, species and surface profile loaders
scripts/movement/    spider motor, player controller, camera rig, boom math, support math, surface input,
                     jump math (the solver), jump plan, jump planner, jump controller (input and aiming),
                     tether (the line's state and constraint), tether controller (reel, lower, let go)
scripts/habitat/     the lab (with the prey's perches and vents) and the test target
scripts/prey/        the fly: its data and maths, senses, mind, flight, body, the perch graph, the population, the director
scripts/needs/       the needs model (energy and rest) and the feeding controller
scripts/perception/  the sensor (evidence), the observation record, the memory, pure helpers
scripts/presentation/ settings, pause panel, debug overlay, support view, cosmetic spider body,
                     landing patch, jump HUD, jump feedback texts, jump arcs, jump debug view,
                     anchor cue, silk lines (and silk.gdshader), tether debug view,
                     perception HUD, gaze footprint, perception debug view, the words (perception_text),
                     the needs HUD (energy bar and the holding and eating words), the prey debug view
data/species/        phidippus_audax_prototype.json (spec 21.1 with chunk 5's jump numbers), fly_like_prototype.json (the fly)
data/surfaces/       surface profiles (spec 21.2), one file per id
tests/               test runner, test base classes, evidence.gd and snapshot.gd (evidence identity and the archive),
                     the catch camera probe, the bare sensor rig (sensor_rig_case.gd), unit/ and integration/
snapshot.bat         writes tests/reports/snapshots/<date>_<evidence id>.zip
docs/                SPEC, DECISIONS, TOOLCHAIN, SESSION_LOG, HANDOFF, reviews/
```

See `docs/TOOLCHAIN.md` for the pinned setup and `docs/SESSION_LOG.md` for what was verified and what was not.
