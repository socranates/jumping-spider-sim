# Handoff — Claude, 2026-10-16: LIFE clock, hunger by the hour, rest and sleep, day and night, retreat checkpoints

Branch **claude/roblox-life** (main b5e78c9, four commits; bundle `claude-playtest/claude-life.bundle`). Roblox only; Godot, SPEC and
the existing ledger entries are untouched. This is the order HANDOFF-roblox-flies.md set: the LIFE clock with day/night and
range_scale, NeedsModel, then in-memory retreat checkpoints. Ledger: **ROBLOX-24** and **ROBLOX-25**. Results:
`docs/verification/roblox-life/RESULTS.md` (Linux; evidence **68090eafdba72ba0**). **Nothing here has run in Studio.**

## What the player gets

- **A day.** The game starts at 9:00 on day 1. About 12 waking hours pass in 15 minutes of play (LIFE-03/04). The day and its part
  ("Day 1, midday") sit in a small pill in the top-left corner, with one line under it in the evening, at night, or when hungry.
- **Rest and sleep in the silk-lined crack.** Stand still in the crack (west end) with nothing in the jaws: the prompt says
  "E: rest", or "E: sleep until morning" from 18:00 to 07:00. E (controller L3, touch Eat relabelled Rest/Sleep/Wake/Leave) rests;
  E or Q again, or walking, ends it. A rest in the evening or at night sleeps: the night passes in about 8 seconds, never more than a
  tick's worth at a time, to "Morning, day N". Moving wakes the spider early ("Awake before morning: it is still night."). A rest
  by day passes no extra time (Godot's behaviour, LIFE-04).
- **Hunger by the hour.** Energy now drains with game hours (0.021 an hour awake, 0.007 asleep) and has no floor (LIFE-05). One
  fly feeds the spider for about a day. The reserve can reach zero and the hours at zero are counted; **nothing follows yet**: weakness,
  starving to death and continuing are LIFE round 5 and need the death rules, which are not ported. "Hungry: time to hunt." below
  0.25; "Starving: ..." at zero.
- **Day and night light.** Full daylight is exactly the accepted look (Lit's values and SunPick's clock). Dusk runs the picked
  morning backwards toward ClockTime 4.0, so the sun sinks on the window's side and the sky turns to night; the room's light, haze,
  sun rays, the light shafts and the dust motes dim; night is dim blue, never black. Dawn runs it forwards. Every number is in
  `Data/Graphics.dayNight` and is a **first guess until seen in Studio**.
- **The eyes reach 30% as far at night** (LIFE-06): the sensor's `rangeScale` comes from the clock, never from the lighting.
- **Checkpoints.** Starting a rest, and each morning of a night's sleep, keeps a retreat checkpoint ("Checkpoint kept."). Backspace
  (controller View) returns to it: the whole sill as it was, flies, meal, reserves, clock and memory together, with the notice
  "Returned to the checkpoint ... checkpoint recovery, not an exact resume." With none yet, Backspace goes back to the start and says
  so. Checkpoints live **in memory for the session only**; no DataStore is written. Touch has no return button yet.

## How it is built

- `Shared/Life/LifeClock.luau`, `NeedsModel.luau`, `LifeLoop.luau`: ports of `life_clock.gd`, `needs_model.gd` and the rest/sleep/light
  part of `habitat_loop.gd`. Goldens from the frozen Godot code by `tools/export_life_reference.gd` (Godot's real habitat loop on a
  stand-in world, recorded every tick). `tests/life.luau` replays them: LIFE 20,846 checks.
- `Feeding` no longer keeps its own energy: it advances and grants into the NeedsModel (Godot's feeding controller does the same).
  The client gives it the life-mode model; one model is shared by feeding, the loop and the checkpoint. E with nothing to eat no
  longer flips Feeding's `feeding` flag (it is the retreat's press now).
- Client tick order: sensor, prey before, jump, motor, prey after (feeding), **then the life loop** (Godot's habitat loop runs last),
  whose reach the sensor uses from the next tick. Presses of E and Q are held for the next fixed tick (Godot's `just_pressed`).
- `Shared/Habitat/DayLight.luau` owns: ClockTime, Brightness, Ambient, OutdoorAmbient, ColorShift_Top, ExposureCompensation, the
  Atmosphere's Color and Decay, SunRays.Intensity, the Shafts beams and the Motes' brightness. **Not** EyeGrade, EyeBlur, MacroDOF
  (SpiderEyes) or the world's Grade (ROBLOX-23's request: SpiderEyes keeps its effects). It sets them only when daylight changes by
  0.002 (or reaches 0 or 1). The client reads the day's ClockTime once, after the server's `SunPick` attribute appears.
- `Shared/Persistence/`: `ObjectRecord` (records the world's object graph from named roots, keeping who points at what; refuses an
  unknown class, function or Instance with its path; decodes everything fresh before touching anything live; commits in one pass),
  `Checkpoint` (boundary, capture, the checks on the record and on the rebuilt world, restore), `CheckpointStore` (current, backup,
  temporary and set-aside keys; a checksum over canonical JSON; never loses the last good checkpoint), `Json` (what a DataStore can
  hold, canonical text, FNV checksum). Schema 1: Godot checkpoints are not read (different fly implementation).

## Please check in Studio (Chet)

1. Import the bundle, rerun the CLI suites on Windows, then the Studio suite (new: **Life spec**, four rows) and the client
   playback (new: two LIFE rows). Record `PORT_LIFE_LIGHT`, `PORT_LIFE_NIGHT` and `PORT_CHECKPOINT`.
2. **Night and dusk look.** Rest in the crack at 18:00+ and watch a night pass; or set `life.clock.hour` through the driver. Is dusk
   readable, is night dim but never black, does the sun sink on the window's side or somewhere odd, do the shafts and motes go out,
   does the eye view still work at night? Tune `Graphics.dayNight` if needed. Screenshots at noon, 19:45, 21:00, 06:30 would help.
3. Does the morning's daylight 0.5 at 07:00 look right? (Godot's curve: full day from 08:00.)
4. Does HttpService's JSON keep every number exactly? LifeSpec's repeat check depends on it; if it fails there and passes in the CLI,
   the encoder is the cause.
5. Frame time with the light changing during a night (DayLight sets about a dozen properties a few times a second while asleep).
6. Not run: controller, touch, tablet, Windows CLI.

## Known limits and choices

- No death, weakness or continuing; no growth or moulting; no wasp; no passing shadow (T08); no notebook; no Easy/Standard choice
  (the port plays Standard). The NeedsModel still has `gentle` for when modes arrive.
- Checkpoints are session-only (MemoryDataStore). A live DataStore needs the server-owned design in ROBLOX_PORT.md section 6.
- The checkpoint includes the prey's and sensor's CPU timing rings (instrumentation). Harmless, a few KB.
- Feeding's conservation checks now allow 1e-9: the reserve records what it rose by (`after − before`), as Godot's does, which can
  exceed the fly's share by about 1e-14.
- Backspace used to mean "back to the start" always; now it means "the last checkpoint, else the start".

## Next

- Chet: the Studio checks above, then merge.
- Claude, after that: the wasp director (LIFE round 4) on top of the clock, or LIFE round 5 (death and continuing) first, whichever
  Chet and Nathan prefer; growth and moulting (round 3) also hang off this clock now.
