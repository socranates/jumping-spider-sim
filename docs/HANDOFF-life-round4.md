# One whole life, round 4: the mud dauber wasp (Claude, 2026-10-13)

Built from `main` 6c51cca (Chet's drawn growth, 618/618 on Linux too). Plan: `docs/LIFE_DESIGN.md` section 4. Decisions: LIFE-14 to LIFE-18.

## What changed
- `scripts/predator/wasp_director.gd`: the visits.
  - **When:** at most one a day by day, never on day 1, before the first meal, or during a rest or moult. The day and hour come from the seed.
  - **The visit:** the warning (8 s heard while arriving over the frame), then the search by sight between 15 places (`POINTS`), notice that grows fast for movement and slowly for stillness, the look (1.5 s at 1.2 WU), the strike (a 0.35 s lunge), losing the spider, leaving, and the catch and carry.
  - **Records and hooks:** `to_dict`/`problems` for checkpoints. `force_visit(at)` for tests and the developer views.
- `scripts/predator/wasp.gd`: the actor (no physics body; perceivable as movement only). `scripts/predator/wasp_body.gd`: **a placeholder drawn from primitives**.
- `SpiderMotor.seize()`: the stung spider stops and is moved by the wasp.
- `scripts/presentation/caught_panel.gd`: what follows a catch.
  - It shows a dim screen, one plain line, then "Back to your last rest" (or "Start a new life", `main.start_new_life()`) and the notebook.
  - It pauses the game and keeps the pause menu shut.
- Sounds and senses:
  - The `"wasp"` hum, made in code (`sound_bank.gd`), plays wherever it flies (`soundscape.gd`, WASP_DB, WASP_UNIT).
  - Captions on its arrival, when it turns toward the spider, and when it leaves.
  - "heavy landing" and "heavy footsteps" vibrations.
- The top line names each turn of the visit. The first visit says what wasps do and how to get away.
- Checkpoint schema 6 (the wasp's record); three notebook pages (sources in NOTEBOOK_SOURCES.md, snippet level only).
- Test worlds have the wasp off unless a test asks for it (`world_test_case.wasp_enabled`); played worlds have it on (`main.wasp_enabled`).

## For Chet
1. **The wasp's model and animation.** Replace `wasp_body.gd` and keep its API.
   - `pose(mode, beat, search)`, with `Mode` FLYING, WALKING and HOLDING.
   - `search` (0 to 1) is how busily the antennae flick.
   - In its own frame -Z is forward. It is about 2.5 WU long: *S. caementarium* is 2 to 3 cm.
   - The director only moves the `Wasp` node and sets `mode` and `search`.
2. **Its sound.** Tune or replace the `"wasp"` hum and its loudness (WASP_DB 6, WASP_UNIT 26). It has to be heard clearly 8 s before it arrives, on laptop speakers too.
3. **The stung spider's pose.** While `motor.seized` is true, the spider hangs under the wasp. A still, legs-drawn-in pose would read as "paralysed".
4. **Optional, the looming response:** *P. audax* backs away from something looming toward it (Spano, Long & Jakob 2012). For example, the front legs could rise while the wasp inspects within about 2.5 WU. That is cosmetic, and the player keeps control.
5. **Windows feel.** Is a visit fair and readable? Is it scary but not too much for Nathan's kids? Check frame time during a visit and the catch screen at 1080p and with large text.

## Verification
Stills: `docs/verification/life04/`. Reports and evidence: DECISIONS LIFE-18 and SESSION_LOG.
