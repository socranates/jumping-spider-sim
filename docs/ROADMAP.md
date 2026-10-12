# Jumping Spider Sim: the plan from here

Claude, 2026-10-11, at Nathan's request ("do you want to make a revised plan for moving forward"). It is a proposal: Nathan decides the order, and Nathan, Chet and Claude decide the platform together (PLATFORM-01). Update it when a step is done or the order changes. `docs/SPEC.md` section 26 is still the long-range roadmap; this file is the next few steps.

## The goal: release "The Windowsill" (Nathan, 2026-10-11; RELEASE-01)

"i definitely want to put it in the world, i love these little guys so much and many do. I dont want to get rich or anything but i want people to play it. I am willing to give it all the time it needs if you and chet are with me"

The first release is one complete, calm, true-to-life game:
- **What it is:** one windowsill done beautifully; one species (*Phidippus audax*); one whole life (hunting, resting, moulting, one predator); a field notebook of short, sourced facts that open as you play (LEARN-01); calm by default, with the help presets for younger players.
- **Where:** a Windows build and a web build. Free, or pay-what-you-want, on itch.io first. Steam later if people want it.
- **Size:** about 2–4 hours to see everything, plus open-ended play. More species and habitats (peacock spiders, the garden) come after, as updates or a second game; the project is already built for that.
- **The road there, in order:**
  1. **Hand back the slice** (step 6 below): measure speed on Nathan's laptop, make the first Windows and web builds, and let a few friends play.
  2. **One whole life** (spec phase 4): needs that matter, moulting, one predator, death and continuing as a new spider.
  3. **The field notebook and honesty fixes:** decide tuned gravity and depth from defocus; make the prey a real species; label every simplification.
  4. **Looks:** a realistic, detailed windowsill and spider. This needs an asset plan (free public-domain scans and textures where they fit, bought assets or an artist for the spider). Every asset's licence is recorded.
  5. **Release:** a store page, credits (including the research the game draws on), a final playtest, and 1.0 on itch.io.
- **Not goals:** getting rich, ads, data collection, pressure to keep playing.

## Where we are

- **Playable slice:**
  - Habitat: the windowsill, with two routes, a retreat that keeps a checkpoint, and a passing shadow.
  - Movement: walking on any surface, aimed jumps, a safety line, the twitchy body and animated legs.
  - Prey: living flies that glance, walk and fly off.
  - The hunt: a slow stalk, the strike, the struggle, then feeding.
  - Options:
    - assisted-play presets ("Most help" is for Nathan's son);
    - key and button remapping;
    - text size;
    - Reduced motion.
  - The spider-eye view (V / Y).
- **Tests:** 591/591 on Windows after T13b/notebook, evidence 2c7264139c03 (Chet, 2026-10-12).
- **Gate audit:** [every gate and its evidence](verification/release-slice/GATES.md).
  - Passed regression gates: M01-M03, P01, A01, L01, S01-C, S02; W01 has automated pause plus rendered warning evidence.
  - F01 measurement/report clause completed; strict 16.7 ms p95 budget missed on this laptop. See [measurements and reduction plan](verification/release-slice/PERFORMANCE.md).
  - Not fully run: M04 graphical 30/60/144 matrix, U01 physical controller-only loop, E01 five-person study, E02 causal hunt feedback. Original S01 exact resume is superseded, not passed.

- **Direction from Nathan:**
  - scientific realism in vision and movement;
  - keep the twitch;
  - hunts slow and challenging by default, with help for his son;
  - eventually PlayStation and other devices.

## Next steps, in order

Each step is one handoff: one agent at a time, start from `main`, finish into `main`, then Nathan runs `update.bat`. The owner shown is a suggestion. Chet has the Windows laptop and its GPU; Claude works in a cloud copy.

**0. Completed: vision details (Chet).** Two narrow principal-eye detail fields sweep and twist within a stable view; Reduced motion freezes them. The blue-as-UV shortcut is removed and the green-weighted picture explicitly labels UV as unimplemented. See `HANDOFF-retinal-scan.md` and `VISION_RESEARCH.md`. Native Windows rendering checked; player comfort/readability belongs to step 1.

**1. Completed: playtest round (Nathan, 2026-10-11).** "everthing on the checklist functions the way it should. It is really fun, camera works great, 1st person is super cool." The one change asked for, a harder struggle that ends when the bar is full, is done (T11b); after playing it Nathan asked for harder still and a bright red bar (T11c, done). The controller-only part of U01 is unconfirmed. Results are in `docs/PLAYTEST.md`.
- A short script to follow: hunt in the normal view and in the eye view, try Most help, catch a fly with a controller only, play muted, rest in the crack and use Return to checkpoint.
- Noting what felt wrong is the most useful output. It also covers most of the human gates (U01, W01, E02, M04) without extra work.
- Fixes from it come before anything below.

**2. Completed: one game clock and slow motion (Claude, T11a).** `scripts/core/sim_clock.gd`. T or the right trigger switches slow motion (25, 50 or 75 per cent). A test shows a whole stalk and strike at half speed matching full speed tick for tick. Nathan also asked for an easy switch between first and third person: V / Y, with a line on screen naming it and a button in the Esc menu. See `docs/HANDOFF-slow-motion.md`.
- Every system (jumps, the silk line, the senses, the flies, needs) reads one simulation clock that counts fixed ticks.
- This makes a correct **slow-motion setting** possible (T9e-01), which will help Nathan's son.
- It also makes pausing, replays and any later port sturdier.
- Done when: at half speed a whole hunt plays exactly as at full speed, only slower, and all tests pass.

**3. Completed: sound and the spider's other senses (Claude, T12a).** See `docs/HANDOFF-sound-senses.md`. The plan as written: The game is silent today. Two layers (spec 16):
- The room: a refrigerator hum, distant house sounds, light changing.
- What the spider senses:
  - flies buzzing in flight, with their direction;
  - wingbeats at take-off;
  - vibration through the surface when something walks on the same leaf or sill. Jumping spiders feel this through their legs; it would be heard as a low thrum and shown as a faint ripple, and only along connected surfaces (spec 7).
- Every meaningful sound also gets a caption or visual cue, so muted play still works (U01).

**4. Implemented by Chet: movement realism, part 2.** See `docs/HANDOFF-surface-legs.md` for Windows evidence and the display-only timing compromise. Nathan's playtest is next. Added:
- feet that plant and stay on the surface;
- steps when turning in place;
- the back legs (pairs 3 and 4) pushing at take-off;
- the silk dragline fixed before every jump;
- a crouch and absorb on landing.

Keep the twitch.

**5. Vision realism, part 2 (Claude, T13a).** See `docs/HANDOFF-vision-2.md`.
- Done: a **motion-sensitive edge**. A moving thing shimmers in the blurry surround before the sharp eyes can tell what it is.
- Done: **comfort options**, a level horizon in the eye view and a grey (colour-free) variant.
- Waiting on Nathan: **depth from defocus** (Nagata et al. 2012). Done faithfully, jumps would be less accurate in poor or reddish light and at long range. That changes how the game plays, so it is his call (EYE-13).
- **UV markings:** kept unsimulated. Published numbers exist for glass and leaves, but none for the house fly, so it waits for that data (EYE-14).

**6. Friends slice packaged (Chet, 2026-10-12); remaining acceptance checks explicit.**
See [handoff](HANDOFF-release-slice.md), [export limitations](verification/release-slice/EXPORT-CHECKS.md), and [friend checklist](FRIEND_PLAYTEST.md). Windows/web ZIPs are on Nathan's laptop; nothing published. Native physical-key automation could not verify a full playthrough; sound/controller and human studies remain open.
- Measure frame time on Nathan's laptop (F01).
- Package a Windows build and a web build and play both.
- Mark every gate passed, failed or not run, with evidence.
- Phase 3 is not declared fully closed until the remaining gate evidence is obtained.

LIFE round 0 complete: [laptop eye comparison and refreshed notebook friend builds](HANDOFF-eye-perf-windows.md). Six-read T13b retained; GPU cost lower, strict frame-pacing target remains open. Claude: clocks and hunger next.

## After that: one whole life (spec phase 4)

**The plan, with the biology and the order of rounds: `docs/LIFE_DESIGN.md` (Claude, 2026-10-12). Death decided by Nathan: LIFE-01.**

- **Needs that matter:** hunger has consequences, and rest matters. The survival-pressure setting becomes useful then (T9e-02).
- **Growth and moulting:** a few instars, with a vulnerable moult in the retreat.
- **One predator.** A windowsill candidate is a cellar spider (*Pholcus*), which is known to eat other spiders. A house centipede is another option. The choice should be checked against the literature first.
- **Death and continuation**, as spec 11 describes. No grind, and no forced breeding.

## Long term: many species (Nathan, 2026-10-11)

"Eventually i want to add all the different species of jumping spiders and make this look realistic, add peacock spiders and little dances."

- **The project is already shaped for it.**
  - A species is a data file (`data/species/*.json`: size, speeds, jump reach, senses), and code reads the profile, not hard-coded numbers.
  - A new species needs:
    - a profile;
    - a realistic model and its colours;
    - its own behaviour;
    - a review of its vision, since species differ. Some *Habronattus* have red-sensitive filters, for example, so the eye view must not copy the *Phidippus* picture without checking (VISION_RESEARCH.md).
- **Peacock spiders (*Maratus*).**
  - The males' courtship display is a raised, colourful abdominal fan, waving third legs and a vibratory "song" through the ground.
  - Courtship is part of spec phase 5, so the dances belong there.
  - Their iridescent colours would need proper materials, not flat paint.
- **Realistic looks.** Moving from primitive shapes to detailed, accurate models (hairs, eye arrangement, markings) is spec phase 6 ("production art"). It can start with the player's own species.
- **A sensible order.** One finished life (phase 4) first. Then a second species chosen to test the system, ideally one that lives in the same windowsill. Then peacock spiders and courtship (phase 5), which need mates, displays and the vibration sense from step 3.

## Long term: calm, true to life, and a way to learn (Nathan, 2026-10-11)

"this could also teach people about jumping spiders right? it will be like a super beautiful, serene, slow play. Hyper real environment to slowly explore, very detailed and proportionate to tiny spiders, just super natural, presenting facts maybe as you learn to play etc. something to keep in mind." (LEARN-01)

- **Already pointing that way.**
  - The world is built at true scale: 1 WU = 1 cm, and the spider's body is about 1 cm long (spec section 6).
  - Hunts are slow on purpose, and slow motion exists.
  - The spec already plans a field notebook that belongs to the player (spec section 4).
  - Every vision and movement choice has a written source (`VISION_RESEARCH.md`, the leg handoffs).
- **Facts as you play.** A field-notebook page could open the first time the player does something:
  - the first jump: the dragline, Chen et al. 2013;
  - the first time in the eye view: the moving retinas, Land 1969;
  - the first fly that shimmers in the surround: the lateral eyes, Zurek et al. 2010.

  Short, optional, never in the way, and each with its source.
- **Honesty first.** A game that teaches must not teach what it fakes. Before facts are presented as facts:
  - the tuned gravity (35 WU/s² against a real 981) and its effect on jumps need a decision;
  - the "fly-like" prey becomes a real species (spec section 8);
  - the UV and depth-from-defocus gaps stay labelled.

  The notebook can say plainly where the game simplifies.
- **Hyper-real, serene environment.** Detailed, accurately proportioned surfaces, light and plants are spec phase 6 (production art), together with realistic spider models (SPECIES-01). Calm ambience and the slow pace come first; no timers or pressure by default.

## The platform question (PLATFORM-01, to decide together)

- **What Godot does now.** Exports to Windows, Mac, Linux, Android, iOS and the web. The game already runs in the renderer the web build uses, and it supports a controller.
- **PlayStation and other consoles.** Godot does not export to consoles by itself. Console versions go through a licensed porting service and the console maker's developer programme. That is a business and licensing step more than a coding one, and it comes once the game is worth publishing.
- **Roblox.** A different engine and language (Luau). It would be a rebuild that reuses our designs, numbers and tests as a guide, not a port of this code. Chet's suggestion of a small Roblox feasibility prototype (movement, silk, one hunt) after the slice is handed back is a cheap way to find out whether the feel survives.
- **Claude's recommendation:** keep building in Godot. Ship desktop and web first, then decide on consoles or Roblox with a finished slice in hand.

## Decisions Nathan can make now

1. The order of steps 2–5. Proposed: playtest, clock (slow motion), sound, movement, vision.
2. Answered (2026-10-11): his son doesn't need more help than Most help gives, so there is no separate step. Slow motion "sounds cool", and it is now built.
3. Nothing about platforms yet; that waits until step 6.
