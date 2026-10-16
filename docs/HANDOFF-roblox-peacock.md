# Handoff — Claude, 2026-10-16: the peacock spider

Branch **claude/roblox-peacock** (origin/main 059811b + three commits; bundle `claude-playtest/claude-peacock.bundle`). Roblox only; Godot, SPEC and the
earlier ledger entries are untouched. Ledger: **ROBLOX-29** (the dance), **ROBLOX-30** (the drawn spider), **ROBLOX-31** (choosing and dancing in the game).
The default spider (the black-and-white one, `Appearances.default`) is untouched and still pinned by `tests/look.luau`. **Nothing here has run in Studio or
on a device.** Places rebuilt, evidence id **154e6bf13cccd87b**.

## What the player gets

- In the silk-lined crack, resting awake: **C** (controller **RB**, PlayStation **R1**, touch **Change**) turns the first spider into the peacock spider and
  back. Remembered for the session (Player attribute `Appearance`); the Workspace attribute `Appearance` ("maratus_volans_male") preselects it.
- As the peacock spider, standing still on a surface: **X** (controller **RB** / **R1** outside the crack, touch **Dance**) starts the courtship dance. A
  loop of about 14 s: bobbing and a rumble-rump on the approach (with the felt caption "[a fine buzzing through your feet]"), the abdomen goes up and the
  fan opens with legs III raised, the fan dance and leg waving, a freeze with fan-flapping, a second dance, then the fan folds. Walking, a jump, Cancel
  or X again stops it at once (the pose eases out in 0.2 s). Player attribute `ReducedMotion = true` halves the movement and stops the tremble.
- A **small** spider: 0.45 studs long (a male is 4 to 5 mm; 1 stud = 1 cm), standing low. The camera stays 5 studs away, so zoom in with the mouse wheel to see
  the fan. The collider, the senses, jump, silk, LIFE and the wasp are the first spider's: the peacock spider is a drawn appearance and a pose, nothing more.
- The prompts, the controls card (H) and the touch buttons carry the new words per device. The dance's words are never shown for the first spider; the crack's
  "C: become the peacock spider" is, so the other spider can be found.

## The science, and what is artistic

Source: Girard, Kasumovic and Elias 2011, "Multi-Modal Courtship in the Peacock Spider, Maratus volans (O.P.-Cambridge, 1874)", PLoS ONE 6(9): e25390
(PMC3181266); morphology from Otto and Hill 2011, Peckhamia 96.1. The design package from another AI was used as source material only (see ROBLOX-29).

| Documented (in `Data/Peacock`) | Value |
|---|---|
| courtship length | 6 to 51 min, mean 24.35 |
| pedipalp flicker | 3.5 +- 1.6 flicks/s |
| fan dance sway | 3.2 +- 1.5 cycles/s over a 19 to 35 degree arc |
| leg III waving | 3.2 +- 0.6 waves/s |
| fan-flapping (in the pauses) | 2.5 +- 1.8 flaps/s |
| rumble-rump (felt, not seen) | 2.44 +- 0.28 s long, 12.1 +- 2.9 bumps/s |
| order | rumble-rumps and bobbing, leg waving with fan dancing, fan-flapping in pauses, (pre-mount display, mounting attempt) |

The pre-mount display and the mounting attempt are **left out on purpose** (a family game). **Artistic:** the 14 s loop and its phase times, the fan raise angle
(80), the bob rate (4 Hz, in bouts), the sway arc used (27), the leg and palp angles, the flap depth, the tremble, the ease times; every colour, proportion and
size of the drawing; the fan's geometry (flat discs that widen rather than flaps that unfurl) and the pattern on its back face.

## Evidence (Linux, plain Luau CLI)

PEACOCK **80** (new: the rates measured off the pose, the order, bounds, frame-rate and slow-motion independence, the 0.2 s fade, reduced motion, the choice
and every word), LOOK **102** (was 72: the peacock spider's size, budgets, stance, fan, legs III, eye view), CLIENT **19** (was 18: choosing in the crack with
C and RB, the dance with X, its stops, the caption, slow motion, reduced motion, the eye view carried over); SUMMARY 184, PERCEPTION 4,669, SENSOR 507, PREY 1,549,
LIFE 20,846, CHECKPOINT 139, WASP 15,815, GAZE 67, PRESENTATION 11, BOXWORLD 15, PERCEPTION_CLIENT 1, WORLD 230, FLIES 187, EYES 231, HUD 69 unchanged; strict
0 diagnostics; every .luau compiles. Parts: 113 at full detail, 80 at low (the first spider: 624 and 266).
Previews (Godot layout renders of the real rig, not Roblox): `claude-playtest/previews/peacock_folded.png`, `peacock_fan_raised.png`, `peacock_low_detail.png`
(`tools/preview/preview.py ... --appearance maratus_volans_male [--dance SECONDS]`; views `p_front`, `p_back`, `p_three`, `p_side`, `p_top`, `p_face`, `p_game`).

## Chet's Studio checklist

1. Import the bundle (README-peacock.txt), push, open `roblox_port/TheWindowsill.rbxlx` or rebuild with `tools/build.py`.
2. Run the Studio suite: the new **Peacock** spec (`tests/studio/PeacockSpec`: real parts, budget 130 / 80, fan opens, legs III up, feet on the floor) and the Prompt spec
   (the controls card with the two new lines must fit eight to ten lines; the touch buttons "Change" (56 px, 13 pt) and "Dance" (56 px, 14 pt) must fit their buttons).
3. Play, rest in the crack (E), press C: the spider is rebuilt as the peacock spider. Look at it close (wheel zoom) from the front and behind: the blue-green fan
   with its red arches and white fringe should be the star; check the folded lens on the abdomen is not a hat, legs III read as dark with white tips, no z-fighting
   in the fan's layers (they are 0.0022 studs apart) at the game camera's distance and at zoom, the Future lighting's shading on the flat discs.
4. Press X on the sill: the whole loop (about 14 s). Check the fan's size against the body (the real fan is about as wide as the body is long), the sway and wave at
   the documented rates, the abdomen pivot at the pedicel, and that the raised abdomen does not look broken against the head.
5. The touch layout on a phone-sized emulator: Change sits beside Eat, Dance above Silk; neither covers another button or the prompt.
6. Not changed, but worth a look: the peacock spider's legs reach the floor with its body 0.21 studs under the collider's centre (walk it on a wall and the underside;
   the drawn body drops along the surface normal).

## What Nathan and the kids should try

Keyboard: rest in the crack (E), press **C**, then walk out and stand still and press **X**. Watch the whole dance, then walk away mid-dance: it stops at once.
PlayStation controller: rest in the crack (L3), press **R1** (it says so on the screen), walk out, stand still and press **R1** again. Cross hops, Circle cancels
(and stops the dance). Slow motion (T / R2) slows the dance. If it moves too much for someone: Player attribute `ReducedMotion` = true.

## Uncertain

The look in Roblox (SmoothPlastic flat discs, Reflectance 0.12 on the blue field; the real fan is iridescent, which Roblox cannot show); how small 0.45 studs feels
at the fixed camera distance (the camera's zoom reaches it); whether the "C" key and RB belong on these actions for Chet and Nathan; the pale margin and stripes at
this size; the touch Dance button's place.

## Nathan's plan: a paid add-on (2026-10-16)

Nathan: the peacock spider will be an add-on "for 99 cents or something later on". Not built yet; keep it unlocked for testing until Nathan says to wire the sale. When he does:
- Use a Roblox **Game Pass** (a permanent unlock; priced in Robux, Nathan picks the price), not a Developer Product.
- Check ownership on the server (MarketplaceService:UserOwnsGamePassAsync, cached, with PromptGamePassPurchaseFinished for a purchase in session) and replicate a Player attribute the client reads; the client never decides ownership. Without the pass, the crack's change-spider prompt offers the pass instead.
- Keep a Studio/test override so the peacock stays testable, and add Studio specs for owned / not owned / purchase finished.
- The default black-and-white spider and the whole game stay free; the add-on is the peacock spider's look and dance only.
