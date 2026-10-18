# Handoff - Claude, 2026-10-18: the ant-mimicking spider

Branch **claude/roblox-antmimic** (origin/main e4a2b5a, published v20, plus the ant-mimic commits; bundle `claude-playtest/claude-antmimic.bundle`). Roblox only; Godot, SPEC
and earlier ledger entries are untouched. Ledger: **ROBLOX-54** (the spider and the drawn walk), **ROBLOX-55** (choosing it, the notebook page), **ROBLOX-56** (what it does
not do). The first spider (the black-and-white one, `Appearances.default`) and the peacock spider are untouched and still pinned by `tests/look.luau`.
**Nothing here has run in Studio or on a device.** Places rebuilt, evidence id **583da24b697d2b70**.

## What the player gets

- In the silk-lined crack, resting awake: **C** (controller **RB**, PlayStation **R1**, touch **Change**) cycles first spider, peacock spider, ant mimic, then back. Remembered for
  the session and saved in PlayerProgress (Player attribute `Appearance`; the Workspace attribute can preselect "myrmarachne_formicaria_female").
- As the ant mimic: standing still on a surface for 0.25 s, legs I rise above the head and wave in phase like ant antennae; they come down in 0.12 s when it moves.
  **Display key** (X, RB / R1 outside the crack, touch **Wave**): the antennae go higher and wave faster and wider (3 Hz, no faster). It does nothing else.
- Walking, the drawn body turns up to 12 degrees either side and sways 0.04 studs, with a wavelength of ten body lengths of walking, eased in and out, so it reads as an ant's
  trail-following zigzag. **The path is unchanged**: the wobble is on the drawn rig only. Slow motion (T / RT) slows it; `ReducedMotion` halves it and stops the waving.
- A tiny spider: 0.5 studs long. The camera stays 5 studs away, so zoom in with the mouse wheel. The collider, senses, jump, silk, LIFE and wasp are the first spider's.
- The notebook (N) gains "Walking like an ant" after the antennae have been up for a second; its To try entry says how.

## The science, and what is artistic

Source: Shamble PS, Hoy RR, Cohen I, Beatus T. 2017. Walking like an ant: a quantitative and experimental approach to understanding locomotor mimicry in the jumping spider
Myrmarachne formicaria. Proc. R. Soc. B 284: 20170308. doi:10.1098/rspb.2017.0308.

| Documented (in `Data/AntMimic`) | Value |
|---|---|
| gait | all eight legs walk; stationary, legs I raised above head height and moving in phase like antennae |
| stops | 83.3 +- 82.6 ms on average (a non-mimic jumping spider is stationary about 55 % of the time; ants 5 to 10 %) |
| path | sine-like, wavelength about ten body lengths (range 5 to 10), amplitude about five body lengths |
| playbacks | to Phidippus audax: non-mimic spiders attacked 4.5 times as often as ants and 3 times as often as mimics; ants and mimics did not differ |
| size | playback targets 5 mm |

**Artistic (marked ART in the data):** the antennae delay, rise, fall, wave rates and amounts; the display key; the drawn yaw (12 degrees) and sway (0.04 studs) and their ease times;
that the real amplitude is not drawn; every colour, proportion and the gloss. The female is drawn; the male is a possible later variant. No range or continent is claimed.

## Evidence (Linux, plain Luau CLI)

ANTMIMIC **86** (new: every number against the paper's, the pose's rates and order, distance-only dependence, the stop rule, reduced motion, the choice and words, the notebook page and
watcher), CLIENT_ANT **2** (new: C cycling, antennae, the drawn walk, X, slow motion, reduced motion, the page, the same ground as the first spider), LOOK **138** (was 102: size, budgets 79 / 69,
waist, glossy dark cuticle, thin legs, antennae and eye view), NOTEBOOK **828** (was 813), STATE **448** (was 432), STATE_CLIENT **104** (was 102); the rest unchanged: SUMMARY 189, PERCEPTION 4,669, SENSOR 507,
PREY 1,549, LIFE 20,846, CHECKPOINT 156, WASP 15,815, GAZE 67, PRESENTATION 11, BOXWORLD 15, PERCEPTION_CLIENT 1, WORLD 230, FLIES 187, EYES 231, HUD 69, PEACOCK 80, CONTINUING 87, GROWTH 433,
STATE_OFFLINE 8, SETTINGS 923, CLIENT (client_smoke) 12 + 12 in its two halves (the whole file now takes over three minutes on the slow VM; both halves pass, as does the untouched baseline). Strict types 0 diagnostics; every .luau compiles (178/178). Parts: 79 at full detail, 69 at low.
Previews (Godot layout renders of the real rig, not Roblox): `claude-playtest/previews/antmimic_standing.png`, `antmimic_walking.png`, `antmimic_top_and_low.png`
(`tools/preview/preview.py ... --ant stand|display|walk`).

## Chet's Studio checklist

1. Import the bundle (README-antmimic.txt), push, open `roblox_port/TheWindowsill.rbxlx` or rebuild with `tools/build.py`.
2. Run the Studio suite: the new **AntMimic** spec (`tests/studio/AntMimicSpec`: real parts, budget 100 / 70, display only, legs I rise and fall, the root never moves, the drawn
   walk turns the picture only, feet on the floor) and the Prompt spec (the crack's change-spider line now names three spiders; the touch button "Wave" must fit its button).
3. Play, rest in the crack (E), press C twice: the spider is rebuilt as the ant mimic. Zoom in with the wheel and look from above and from the side: it should read as an ANT at a glance
   (waist, small head, long gaster, thin legs) and as a spider on a closer look (eight legs, front eyes). The front and three-quarter views show a spider's big glossy front eyes on purpose.
4. Stand still: the antennae rise after a quarter second. Press X: higher and faster. Walk: the drawn wobble. Check that it never looks like the spider is sliding sideways or that its feet slip
   (feet are planted on the real surface; the body wobbles above them), that the raised legs do not clip the head, and the dark body's shading under Future lighting.
5. Walk it on a wall and the underside; the drawn body drops along the surface normal as the peacock does.
6. Touch layout on a phone-sized emulator: Change and Wave do not cover another button or the prompt.
7. Confirm the notebook page opens (stand still with the antennae up for a second) and that its text fits the reader on a phone.

## What Nathan and the kids should try

Keyboard: rest in the crack (E), press **C** twice, walk out, and watch it walk. Stand still and watch the antennae. Press **X**. Compare how it moves with the first spider and the
peacock spider: the paths are identical; only the drawing differs. PlayStation: **R1** in the crack (it says so on the screen). Slow motion (T / R2) shows the wobble slowly.
If it moves too much for someone: Player attribute `ReducedMotion` = true (also in the settings panel, O).

## Uncertain

How the 0.5 stud body reads at the fixed camera distance; whether the wobble amplitude (12 degrees, 0.04 studs) is too much or too little (it is deliberately small, because the real path
cannot change); the display key (the paper reports no display); Roblox's rendering of the dark glossy cuticle; the touch Wave button's place.

## Plan: a paid add-on (Nathan)

The ant mimic is intended as a one-time cosmetic add-on of about US$0.99, alongside the peacock spider, as a Roblox **Game Pass** on ROBLOX-48's pattern (server-checked ownership with
`UserOwnsGamePassAsync`, a replicated Player attribute the client reads, a Studio override, Studio specs for owned / not owned / purchase finished). Not built: it stays free for testing
until Nathan says to wire the sale. The first spider and the whole game remain free; the add-on is the look (and the pose) only, never advantage.
