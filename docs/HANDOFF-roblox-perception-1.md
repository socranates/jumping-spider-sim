# Handoff — Roblox perception, part 1: the pure logic (Claude, 2026-10-15)

Chet's order (where-we-left-off, 2026-10-14): "perception, beginning with observation/association/memory fixtures, then cone/peripheral/Focus." This is the first half and **pure logic only**: no raycasts, no client wiring, no presentation. It is ported line for line from the frozen Godot sources and checked against values Godot itself produces. Branch **`claude/roblox-perception`** from origin/main 61f2d49 (five commits; bundle `claude-playtest/claude-perception.bundle`). Roblox only; Godot, SPEC and DECISIONS untouched. **Not run in Studio** (nothing in the places uses the new modules, so the places were not rebuilt; run `tools/build.py` when part 2 wires the sensor in).

## What is ported (`roblox_port/src/Shared/Perception/`, all `--!strict`, no engine services)

| Module | Godot source | Holds |
|---|---|---|
| Observation | observation.gd | the record, its spec 21.3 checks, the three ordered categories |
| PerceptionMath | perception_math.gd | cone and peripheral angles, the coarse cue direction (22.5 degree sectors, 30 degree bands), sight tolerance min(0.05, 0.1 x radius + 1e-5 x ray), apparent size, exposure and classification (0.40 s, 1.00 s, longer when it looks small), confidences, decay, the plausible region, size and category compatibility |
| Signal | Godot signals | the small synchronous signal the memory announces with |
| ObservationMemory | observation_memory.gd | contacts, hold times (0.15 s inspection, 1.0 s cue), loss (the world link dropped), linear decay to nothing over 6 s, expiry, the fixed last-seen mark, invalidation, merge, familiarity, capture resolution |
| SensorCore | sensor_system.gd, the half that needs no world | tracks and the unbroken-sight link; exposure with the 0.15 s grace and what a new stretch inherits (kept exposure x what is left of the memory); the cap by what a thing can look like; the cue and its cooldown; the A-027/D-040 association rule (exactly one candidate within 0.5 x (old + new size) + max(2.0 WU/s, seen speed) x elapsed, size ratio at most 1.5, category compatible, and no other sighting of the same tick could be it either; else a fresh contact, nothing transferred); the remembered-spot check (an empty spot in plain view for 0.40 s drops the mark); forgetting tracks of vanished things (A-029) |

Tuning is read from `Species.phidippus_audax_prototype.perception` (`SensorCore:configureFrom`); a test pins that the data gives the numbers Godot's loader gave. **The seam to part 2:** SensorCore never casts a ray. The caller does what `_physics_process` does (`beginTick`, `trackOf`, `cue`, `fileSightings`, `checkSpots`, `endTick`; the order is in the module header) and passes `allVisible(eye, position, radius, up)` to `checkSpots`. Deliberately not ported: `_sense`, `_visible_points`, `_clear`, `_sample_points`, `could_sense`, the developer overlay, `motion_seen` (T13a), `on_capture` (feeding chunk) and `vibration_sense.gd`.

## Fixtures: Godot made every expected value

`roblox_port/tools/export_perception_reference.gd` (`godot --headless --path . -s roblox_port/tools/export_perception_reference.gd -- roblox_port/tests/perception_reference.json`, then `python3 tools/reference_to_luau.py tests/perception_reference.json`) calls Godot's PerceptionMath and Observation directly (15 function tables, 28 record cases) and drives the real SensorSystem bookkeeping and ObservationMemory through **29 scripted scenarios** tick by tick. The only thing replaced is the world half: a scenario scripts the sightings and cues of each tick, which spots the world hides and where the gaze points. Scenarios: timing (easy and small targets, caps), breaks of 5, 8 and 9 ticks, decay and expiry at tick 460, a mark that is kept (hidden, out of the cone) or dropped (empty in plain view, looked at with short and long interruptions), and the association accept and reject cases (one fit, outside the region, size 1.48 and 1.6, appearance cap, seen speed 5 and 0.8 WU/s, two lost contacts with an early and a late newcomer, look-alikes that cross and come out together and a place two newcomers could each be, each in both listing orders, a stranger in view, a cue then the inspection that folds it in, a cue-only contact, a thing leaving the world). `tests/perception.luau` also ports all 17 hand-written cases of Godot's `test_observation_memory.gd` and the unit expectations of `test_observation.gd` and `test_perception_math.gd`. Never regenerate the reference from the port.

## Test numbers (Linux)

```
SUMMARY passed=182 failed=0      BOXWORLD passed=15 failed=0     CLIENT passed=11 failed=0
PERCEPTION passed=4669 failed=0  LOOK passed=72 failed=0         WORLD passed=71 failed=0
```
Strict luau-lsp analysis of src: 0 diagnostics. `luau-compile` of every .luau under src, tests and tools: 60/60. Three deliberate breakages of the port (the claims rule, the hold off by one, the spot time) failed 118, 89 and 71 checks.

## Worth knowing

- **A boundary in Godot's design, kept as is.** Nine ticks without a sighting (0.15 s): the next sighting is 10 ticks after the last, past the hold, but the contact is still live because the memory advances after the sensor files. It is not "linked", no lost contact exists yet to compare with, so it starts a fresh contact in the same tick the old one is lost; with eight ticks away it continues the same contact. The golden pins both (`the_longest_break_that_keeps_the_contact`, `a_break_one_tick_longer_starts_a_new_contact`). Chet may want to decide whether a rejoin should be possible in that tick; the port does not change frozen behaviour.
- A new stretch of exposure is restored from `kept` only when a lost contact is rejoined (or a cue-only contact is merged): for a still-linked contact the gap can never exceed the grace.
- Where Godot walks a dictionary, the port walks contacts oldest first, so announcements come in a fixed order (Godot's own tie order in `contacts()` is unspecified; no scenario depends on it).

## Next: part 2 (sensor sampling and presentation)

1. The world half of the sensor: eye, gaze, up and heading from SpiderMotor; `_sense` with the five sample rays per thing and `PerceptionMath.sightTolerance` (A-024: Chet's small-target arrangement gives 0 contacts, partial visibility kept, a last-seen spot behind the same barrier not declared empty); the 300 degree field, 30 degree cone, 40 WU range, 10 Hz broad scan with 4 WU close checks and things already tracked every tick. Replay the same 29 scenarios through BoxWorld rays and in the Studio specs.
2. The peripheral cue (speed 0.3 WU/s, cooldown, bearing only) and the inspection cone feeding `SensorCore`.
3. Focus (D-036, D-041): 180 degrees/s turn toward the aim, 35 degree gaze tilt, the toggle setting and "FOCUS ON"; the camera alone never turns the cone.
4. The last-seen mark's presentation and plain words from memory only; nothing drawn for what was never sensed.
5. A labeled test target (D-038: magenta marker, 0.8 WU/s, on a stage watched from a 2 WU ledge) and P01 in Studio; measure candidates, rays and CPU time with 3 to 6 flies later (A-029).
