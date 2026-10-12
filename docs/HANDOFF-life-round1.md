# One whole life, round 1: clocks and hunger (Claude, 2026-10-12)

Built while Chet's measuring round was paused (he was out of usage), on Claude's branch only, and merged into main after his round. Plan: `docs/LIFE_DESIGN.md`. Decisions: LIFE-04 to LIFE-08.

## What changed
- `scripts/life/life_clock.gd`: day and hour, daylight, parts of the day, sleep rules. It is saved in checkpoints (schema 4).
- `scripts/habitat/habitat_loop.gd`: runs the clock each tick and decides when a rest is a night's sleep.
  - A morning while still resting keeps a checkpoint and emits `woke(day)`.
  - It sets the light (`apply_light`) and the sensor's night reach (`NIGHT_SIGHT` 0.3).
  - The caption names the day and part of the day, with evening, night and sleep lines.
- `scripts/needs/needs_model.gd`: **life mode**, on wherever the windowsill runs.
  - Energy drains by game hours (`add_hours`), applied at the existing 2 Hz update, and can reach 0 (`starving_hours`). There is no death yet.
  - Legacy mode is unchanged elsewhere.
- `scripts/habitat/windowsill.gd`: `set_daylight(light, hour)` sets the sun's strength, colour and height, the ambient light, the sky and the window glow. The passing shadow is folded in.
- `scripts/perception/sensor_system.gd`: `range_scale` and `reach_wu()`.
- `scripts/presentation/spider_body.gd`: `condition` and `abdomen_scale()`. The abdomen follows the reserve slowly; display only.
- Notebook: three pages (`sleep`, `hungry`, `well_fed` triggers), sources in NOTEBOOK_SOURCES.md.

## What stays out
- Death and starvation's end.
- Moulting (round 3) and the wasp (round 4).
- Flies resting at night. They still fly in the dark; a later round should give them a day too.
- Weather and seasons.

## Verification
Results, evidence and frame-rate runs: DECISIONS and SESSION_LOG. Stills of four hours and of a thin and a plump spider: `docs/verification/life01/`.

## For Chet (round 2 in LIFE_DESIGN)
- Night lighting and the abdomen in real play on the laptop, and the frame time with the moving sun.
- The sun's height changes its shadows through the day.
