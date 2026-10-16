# Handoff — Claude, 2026-10-16: the mud dauber wasp

Branch **claude/roblox-next** (main b5e78c9 + LIFE + PlayStation button names + four wasp commits; bundle
`claude-playtest/claude-next.bundle`). Roblox only; Godot, SPEC and the earlier ledger entries are untouched. Ledger: **ROBLOX-26**
(the director and how it was checked) and **ROBLOX-27** (in the game, the catch, the checkpoint, the drawing). **Nothing here has run
in Studio, on Windows or on a device.**

## What the player gets

- **A visit**, at most one a day, in the warm middle of the day (10:00 to 15:30), never on day 1, never before the first meal is
  finished, never while the spider rests. The hum is heard for 8 s first: a caption, "[a deep, heavy hum outside, ahead-left, coming
  closer]", the direction from where the spider faces. The first time, the status line says what wasps do and how to get away.
- **A search by sight.** The wasp flies in over the window frame, then moves between 15 places on the sill (hover, look; on open
  surfaces sometimes land and walk, its antennae flicking). It sees only what is in range (7), in a clear line, outside the crack.
  A moving spider is noticed in about a second; a still one very slowly; the silk-lined crack never. Out of sight, notice fades.
- **Found.** It turns, comes to look (1.5 s at arm's length) and lunges (0.35 s) at where the spider was. A jump, a drop on the line,
  or getting out of sight breaks it off; then it is confused and searches elsewhere. After 45 s it gives up and leaves.
- **Caught.** The spider goes still (stung, paralysed, not killed), is held under the wasp and carried up and away over the frame.
  Then a plain screen: "A mud dauber wasp stung the spider and carried it away." / "Its sting does not kill: it paralyses.", with
  hours lived, meals, visits and escapes, and one choice: **Back to your last rest** (the checkpoint return; with none yet, **Back to
  the start**). Return, Space, E, controller A / Cross, or a click.
- **The drawn wasp**, about 2.5 cm: black, a very long thin yellow waist, black legs with yellow knees and feet, smoky wings (a soft
  blur in flight), curled antennae. Previews: `claude-playtest/previews/w1_wasp*.png`.
- **A checkpoint brings the wasp back to where it was:** the record has a `wasp` field (schema 1; older records restore with a fresh
  wasp).

## Evidence

- `tests/wasp.luau`, **WASP 15,815** checks: Godot's own director and wasp were run on a stand-in world in eight seeded scenarios
  (`tools/export_wasp_reference.gd` to `tests/wasp_reference.json`, 1.5 MB); the Luau director replays each with Godot's random draws
  fed in and agrees on the phase and events (within 1.5 ticks), positions, headings and notice (2e-3). Godot's hand-written
  `test_life04_wasp` expectations are ported. Changing `noticeMoving` or the hold timer fails hundreds of checks.
- The fifteen places on the sill's own boxes (box world), the words, the lines, the checkpoint record (CHECKPOINT 139), the client
  wiring (CLIENT 15), and the drawn wasp's parts, colours, proportions and poses.
- All other suites unchanged and green; strict 0 diagnostics; 121/121 compile. Studio spec `tests/studio/WaspSpec.luau` (new) runs on
  real casts.

## Please check in Studio (Chet)

1. Import the bundle, run the CLI suites on Windows, then the Studio suite (new row **Wasp spec completes**: the places clear on real
   Raycast and Spherecast; a whole search in the crack; a catch in the open; a lunge missed after a drop; the drawn wasp's flags).
   The one real unknown is that the engine's shape casts agree with the box world: if "every place has room..." fails, note which
   place and the ids of what it hit.
2. In the test place, set Workspace attribute `Wasp` = true (allows visits by day) or `WaspForce` = `floor_middle` (or any id from
   `Data/Wasp.points`) in the Explorer while playing: the wasp comes at once. Look at: the caption and the status line; whether the
   wasp reads as a mud dauber in flight, hovering, searching and holding; the wing blur; whether it clips any of the sill's detail
   (the casts see only the 33 authored pieces, not the drawn decor); the catch screen; "Back to your last rest".
3. Frame time with the wasp over the sill (56 parts, one BulkMoveTo; the director's casts are a few a tick).
4. Not run: controller, touch, tablet, Windows CLI.

## What Nathan should try

- **Keyboard:** the first visit can come on day 2 after the first meal. Eat a fly, sleep in the crack (E after 18:00) to "Morning,
  day 2", then keep playing through midday; on a day with a visit there is the caption about 8 s before it is on the sill (not every
  day has one). Hear the caption; stay in the open and walk and it finds you; try each way out: keep still in the open (slow), hurry
  to the crack and rest, jump (Space) or drop on the line (Q). Get caught once and read the screen; Return picks "Back to your last
  rest". (The `Wasp` and `WaspForce` attributes only work in the test place, for Chet.)
- **PlayStation controller:** the same; the screen's choice is Cross (X), and it is selected for the d-pad too. Drop is the
  controller's drop button as named on the prompts.

## Known limits and choices

- **No sound** (Godot's hum is synthesised; no audio asset here). **No Gentle mode** (the flag exists, nothing sets it). **No
  "continue as another"** after a catch and no notebook line (rounds 5 and the notebook are not ported).
- **The days are not Godot's**: a seed gives different visit days from Godot (the port's own hash); each is the same every run.
- **Walking uses a 0.3 sphere** (`Data.Wasp.walkRadius`): Roblox's casts do not promise to ignore an initial overlap with the ground.
- The "out of reach" scenario is covered by a hand-written test, not a golden.
- The wasp's cast world is the authored pieces and the same `RaycastParams` as the senses; the drawn decor is invisible to it.

## Next

- Chet: the checks above, then merge.
- Claude: LIFE round 5 (death and continuing, Easy/Standard/Gentle) so the catch can have its full ending, or growth and moulting.
