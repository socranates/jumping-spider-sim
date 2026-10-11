# Jumping Spider Sim: the plan from here

Claude, 2026-10-11, at Nathan's request ("do you want to make a revised plan for moving forward"). It is a proposal: Nathan decides the order, and Nathan, Chet and Claude decide the platform together (PLATFORM-01). Update it when a step is done or the order changes. `docs/SPEC.md` section 26 is still the long-range roadmap; this file is the next few steps.

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
- **Tests:** 548 automated tests pass on Windows after T10b (evidence 829573aaf835); the 12 eye-view tests also pass at normal speed. Claude's prior Linux baseline was 544/544 (7169ecfd3663).
- **Gates (spec 25):**

  | Status | Gates |
  |---|---|
  | Pass (automated) | M01–M03, P01, A01, L01, S01-C, S02 |
  | Needs a person to play | U01 (controller only, remapped, muted), W01, E02, M04 (graphical) |
  | Needs a measurement | F01 (frame time on Nathan's laptop) |
  | Partly met | E01: Nathan and his son already play |

- **Direction from Nathan:**
  - scientific realism in vision and movement;
  - keep the twitch;
  - hunts slow and challenging by default, with help for his son;
  - eventually PlayStation and other devices.

## Next steps, in order

Each step is one handoff: one agent at a time, start from `main`, finish into `main`, then Nathan runs `update.bat`. The owner shown is a suggestion. Chet has the Windows laptop and its GPU; Claude works in a cloud copy.

**0. Completed: vision details (Chet).** Two narrow principal-eye detail fields sweep and twist within a stable view; Reduced motion freezes them. The blue-as-UV shortcut is removed and the green-weighted picture explicitly labels UV as unimplemented. See `HANDOFF-retinal-scan.md` and `VISION_RESEARCH.md`. Native Windows rendering checked; player comfort/readability belongs to step 1.

**1. Playtest round (Nathan and his son, about 20 minutes).** The checklist is written: `docs/PLAYTEST.md`. Waiting for the playtest.
- A short script to follow: hunt in the normal view and in the eye view, try Most help, catch a fly with a controller only, play muted, rest in the crack and use Return to checkpoint.
- Noting what felt wrong is the most useful output. It also covers most of the human gates (U01, W01, E02, M04) without extra work.
- Fixes from it come before anything below.

**2. Completed: one game clock and slow motion (Claude, T11a).** `scripts/core/sim_clock.gd`. T or the right trigger switches slow motion (25, 50 or 75 per cent). A test shows a whole stalk and strike at half speed matching full speed tick for tick. Nathan also asked for an easy switch between first and third person: V / Y, with a line on screen naming it and a button in the Esc menu. See `docs/HANDOFF-slow-motion.md`.
- Every system (jumps, the silk line, the senses, the flies, needs) reads one simulation clock that counts fixed ticks.
- This makes a correct **slow-motion setting** possible (T9e-01), which will help Nathan's son.
- It also makes pausing, replays and any later port sturdier.
- Done when: at half speed a whole hunt plays exactly as at full speed, only slower, and all tests pass.

**3. Sound and the spider's other senses (Claude).** The game is silent today. Two layers (spec 16):
- The room: a refrigerator hum, distant house sounds, light changing.
- What the spider senses:
  - flies buzzing in flight, with their direction;
  - wingbeats at take-off;
  - vibration through the surface when something walks on the same leaf or sill. Jumping spiders feel this through their legs; it would be heard as a low thrum and shown as a faint ripple, and only along connected surfaces (spec 7).
- Every meaningful sound also gets a caption or visual cue, so muted play still works (U01).

**4. Movement realism, part 2 (Chet).** The legs today are a cosmetic cycle (LEG-04). Next:
- feet that plant and stay on the surface;
- steps when turning in place;
- the back legs (pairs 3 and 4) pushing at take-off;
- the silk dragline fixed before every jump;
- a crouch and absorb on landing.

Keep the twitch.

**5. Vision realism, part 2 (Claude, building on Chet's current work).**
- **Depth from defocus** (Nagata et al. 2012): how sure the landing marker is depends on green light and distance.
- **UV markings** on flies and leaves, visible only in the sharp window. This needs authored, evidence-based UV reflectance for each material (EYE-08), not a guess from screen colour.
- A **motion-sensitive edge**: a moving thing flickers in the blurry part before you can tell what it is.
- **Comfort options:** a level horizon in the eye view, and a colour-free variant.

**6. Hand back the slice (spec T10; Chet on Windows, Claude on docs).**
- Measure frame time on Nathan's laptop (F01).
- Package a Windows build and a web build and play both.
- Mark every gate passed, failed or not run, with evidence.
- This closes spec phase 3, the complete slice.

## After that: one whole life (spec phase 4)

- **Needs that matter:** hunger has consequences, and rest matters. The survival-pressure setting becomes useful then (T9e-02).
- **Growth and moulting:** a few instars, with a vulnerable moult in the retreat.
- **One predator.** A windowsill candidate is a cellar spider (*Pholcus*), which is known to eat other spiders. A house centipede is another option. The choice should be checked against the literature first.
- **Death and continuation**, as spec 11 describes. No grind, and no forced breeding.

## The platform question (PLATFORM-01, to decide together)

- **What Godot does now.** Exports to Windows, Mac, Linux, Android, iOS and the web. The game already runs in the renderer the web build uses, and it supports a controller.
- **PlayStation and other consoles.** Godot does not export to consoles by itself. Console versions go through a licensed porting service and the console maker's developer programme. That is a business and licensing step more than a coding one, and it comes once the game is worth publishing.
- **Roblox.** A different engine and language (Luau). It would be a rebuild that reuses our designs, numbers and tests as a guide, not a port of this code. Chet's suggestion of a small Roblox feasibility prototype (movement, silk, one hunt) after the slice is handed back is a cheap way to find out whether the feel survives.
- **Claude's recommendation:** keep building in Godot. Ship desktop and web first, then decide on consoles or Roblox with a finished slice in hand.

## Decisions Nathan can make now

1. The order of steps 2–5. Proposed: playtest, clock (slow motion), sound, movement, vision.
2. Answered (2026-10-11): his son doesn't need more help than Most help gives, so there is no separate step. Slow motion "sounds cool", and it is now built.
3. Nothing about platforms yet; that waits until step 6.
