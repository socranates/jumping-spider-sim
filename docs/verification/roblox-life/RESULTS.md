# Roblox LIFE clock, needs, rest and retreat checkpoints — Linux results

Claude, 2026-10-16. Branch `claude/roblox-life` on main b5e78c9. Evidence **68090eafdba72ba0** (`tools/build.py`). **Not run in Studio,
on Windows, or on any device.** These are CLI results under the shim and box world: they say the logic is right, not how anything looks
or runs in the engine.

## Commands

From `roblox_port/`:

```
python3 tests/run.py path/to/luau            # luau 0.742
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --platform roblox --definitions=globalTypes.d.luau --sourcemap sourcemap.json src   # luau-lsp 1.70.1
python3 tools/build.py path/to/rojo         # rojo 7.7.1
```

Goldens: `godot --headless --path . -s roblox_port/tools/export_life_reference.gd -- roblox_port/tests/life_reference.json`
(Godot 4.7.2.stable.official.ed1daf0bf, Linux), then `python3 tools/reference_to_luau.py tests/life_reference.json`.

## Results

| Suite | Result | What it covers |
|---|---|---|
| LIFE (new) | **20,846 / 20,846** | LifeClock, NeedsModel and the rest-and-sleep loop replayed against Godot's own code (14 loop scenarios tick by tick, 7 clock sequences, a night of sleep, record checks, 6 needs sequences, 600 ticks at 60 Hz, 14 needs records); Godot's test_life01 cases that need no world; DayLight; LifeText; the retreat box |
| CHECKPOINT (new) | **123 / 123** | A whole world (real motor, flies, sensor, memory, needs, feeding, life loop) on the box sill: rest keeps a checkpoint; after a restore, 600 ticks (with a walk out of the crack) repeat the original run exactly; a fly eaten after the checkpoint comes back with its energy; a part-eaten meal in the jaws; boundaries; 22 kinds of bad record refused with nothing changed; the store's backup, failed write, cut-short entry, set-aside, newer schema, never-write-invalid; the DataStore stand-in's rules; ObjectRecord cycles, sharing and refusals |
| CLIENT | **14 / 14** (was 11) | + Backspace with no checkpoint goes to the start and says why; rest in the crack, evening sleep to morning, light and the eyes' reach, walking wakes; Backspace returns to the checkpoint with the reserves |
| SUMMARY, PERCEPTION, SENSOR, PREY, GAZE, PRESENTATION, BOXWORLD, PERCEPTION_CLIENT, LOOK, WORLD, FLIES, EYES, HUD | unchanged counts, all pass | |
| **Total** | **28,773 checks, 0 failed** | `cli.txt` |
| Strict analysis | **0 diagnostics** | `strict.txt` |
| Compile | **108 / 108** | `compile.txt` |

Checkpoint size on the box sill after a rest: about 21,300 characters, 85 tables (limit 4,194,304).

## New Studio checks, not run

- `tests/studio/LifeSpec.luau` (in `Runner.server.luau`): the modules in the engine; night set on the real Lighting (sun below the
  horizon, shafts off) and day put back exactly; a checkpoint through HttpService's own JSONEncode/JSONDecode on a private sill, then
  300 ticks repeated exactly; the store's backup and a refused record changing nothing. Prints `PORT_LIFE_LIGHT` and `PORT_CHECKPOINT`.
- `tests/client/SilkPlayback.luau`: two rows: E rests in the crack and keeps a checkpoint, an evening rest sleeps to morning with the
  light and the eyes' reach measured (`PORT_LIFE_NIGHT`); Backspace returns to the checkpoint.
- Changed: PreySpec and the playback's feeding row allow 1e-9 in `granted <= taken` (ROBLOX-24).

## Not run

Studio (engine suite, client playback, the look of night and dusk), Windows, frame time, controller, touch, tablet.
