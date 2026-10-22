# Prompt for Chet — v49: feeding prompts and animation, starvation, dusk rest prompt, optimisation and clipping pass

Nathan played v48 (Roblox place version 137) and asked for this. Build on your own branch `codex/v48-living-habitat` (source 1ba2eb3 plus your
receipt commits), the published baseline. Claude is not editing in parallel, so you own the fly, feeding, settings and menu code for this round.
The same release route and rules as v48 apply: publish only the existing playtest place, File > Publish, never Publish As, test in the foreground,
and Nathan logs in himself.

## Nathan's words (verbatim)

"There should be button prompts for eating prey to let you know to tap and then an animation for eating the prey. I didn't die from hunger. It
should tell you to go rest in the Crack when it gets dark and let you know to press the correct button. Consider techniques for optimization.
Debug and check for clipping etc."

**HUD rule change.** This narrows the v48 rule that the only persistent HUD element is the 120×4 hunger bar with no routine messages. Nathan now
wants contextual button prompts for **feeding** and the **dusk rest**. Keep them small, short-lived and device-correct (keyboard, gamepad and
touch words from `Shared/UI/ControlText`), and gone the moment they are acted on. Everything else stays as minimal as v48. Record the change as a
decision in `docs/DECISIONS.md` with his quote.

## 1. Feeding: a prompt, then an eating animation

- **Find the current behaviour first.** Trace how a catch becomes a meal (`Shared/Catch`, the feeding state, `LifeLoop`, the client's
  caught panel `Client/CaughtPanel`, and whatever input "feeding" listens for). Write down what the player must press now, whether a tap or
  hold is expected, and why Nathan saw no cue.
- **The prompt.** Once prey is held, show a small prompt with the device's button and verb, e.g. "Tap [E] to feed" / "Tap (X)" / a
  touch button. If feeding is a series of taps (the partial-feeding rule), the prompt stays while feeding is possible and goes as soon as the
  meal ends or the prey is dropped. Show it every time in Easy and Free play. In Normal, decide whether it shows only for a life's first
  meals or always; Nathan's words suggest always for now. Say which you chose.
- **The animation.** The spider should visibly eat. Hold the prey in the chelicerae, with the palps working and the fangs in. Add small
  rhythmic head and chelicerae pulses on each tap or each feeding tick. Shrink or darken the prey a little as the meal progresses, or empty it
  if you can (a spider sucks prey dry and leaves a husk). Drop the husk at the end. Use the existing rig (`Rig/SpiderRig`, `Rig/Living`, the
  groom cue) and the prey bodies. It is drawing only: no change to meal credit, the seven-and-ten fly moult thresholds, or partial-feeding
  rules. In Reduced Motion, keep the pulses subtle.
- **Tests.** Cover a client suite where a catch shows the prompt with the right device words, taps advance the meal and the animation state,
  the prompt clears at the end, and meal credit is unchanged from v48. Add a SelfTest check that a scripted catch shows the prompt and
  completes.

## 2. "I didn't die from hunger": starvation must happen

- **Reproduce it.** Find why a starving spider survived. Candidate causes:
  - the difficulty Nathan played (gentle modes never starve by design)
  - the hunger drain rate (ROBLOX-102 set drain 2.4)
  - a night or rest refill
  - the new ambient animals or progression changing the reserve
  - the "too hungry to sleep" check
  - a save restore resetting hunger
  - the reserve clamped above zero
  - death being gated on something that never fires
  Use the CLI life suites and a fast-clock run to find the actual path from empty to dead.
- **Fix it in Normal**, so that an unfed spider in Normal dies of hunger within a predictable number of days. Keep the hunger bar's colour
  shift and the existing words for "will not last another day". Write down the expected time-to-death and pin it in a test. Keep Easy and Free
  play gentle, and say so.
- Check that the end screen and lineage continue correctly after a starvation death.

## 3. Dusk: tell the player to rest in the Crack

- When dusk falls (LifeClock's dusk), show a short prompt telling the player to go to the Crack to rest, then a button prompt when they
  are at it: "Press [R] / (Y) to rest", with the device's real binding. Check what the rest input is actually bound to on each device after v48's
  control changes (L1 creep, L2 run, R2 Focus, lock-on).
- In the preserve, the Crack is the rest spot in the hut, so name it as the player knows it. If the spider is far away, consider a subtle
  direction cue that is not a map marker, or the words only; keep discovery.
- Clear it once they rest, and repeat it at the next dusk if they did not. Show it every dusk in Easy. In Normal, decide on the first nights or
  every night, and say which.
- Pin it with tests: dusk triggers the prompt, the device words are right, resting clears it, and there is no prompt by day.

## 4. Optimisation pass (measure first, then change)

Profile with the in-Studio self-test's frame lines and Studio's MicroProfiler, in the foreground with no CLI load. Cover the sill, the hut
garden, the meadow edge, the pond and the can/doorway, at full and low detail. Then consider these, keeping the ones that measurably help:

- **Instance count and streaming.** Check StreamingEnabled radii. Collapse static drawn parts that never move into fewer parts. Make sure
  LookStream's budgets (1,500 full / 500 low) and the near-detail patches are actually unloading behind the player.
- **Shadows.** CastShadow off on small or near-invisible parts (ROBLOX-121 did this for walkable boxes). Check the v48 cover, litter and
  grass.
- **Per-frame work.** Use one Heartbeat or RenderStepped loop per system, not one per creature. Throttle off-screen or distant creatures (dog,
  ants, fleas, robin, insects) to a lower update rate or freeze them. Pool and reuse CFrame and table allocations (the rig work in
  ROBLOX-113). Use `workspace:BulkMoveTo` for many-part bodies. Avoid property writes that do not change values (ROBLOX-128 did this for the
  robin's transparency).
- **Wind and grass sway.** Make sure sway is driven cheaply: by distance, few parts, or batched with BulkMoveTo. Skip it beyond a radius and in
  low detail.
- **Weather and particles.** Check rain particle rates at low detail, how often wetness is recomputed, and the cost of rain discovering
  roofs.
- **Meshes and collision.** Use RenderFidelity Automatic on MeshParts. CanQuery and CanTouch should be off on everything that does not need
  them. Use CollisionFidelity Box on decor if any MeshParts exist.
- **Lighting.** Check the cost of Future lighting versus ShadowMap at low detail, and of moving sunlight (how often the sun updates).
- **Phone.** If any device is available, a low-detail run on a phone, or Studio's device emulator as a stand-in, labelled as such.

Report before/after frame times per scene. Do not change the look or the lighting Nathan likes without saying so.

## 5. Debug and clipping pass

Walk and jump the whole preserve at the game camera, in both detail tiers, and record anything that clips or floats:

- the spider's legs, body or camera clipping into walls, the hut's ceiling and corners, doorways, cans, stones, leaves and grass
- creatures and props passing through each other or the ground: dog paws, ants and grubs underground, fleas inside the floor, the frog,
  the robin, prey held by the spider, the rival during its display or grapple, the mate scene
- the v45 milkweed mesh leaf against its walkable box, and any mesh poking through boxes
- drawn decor floating above the ground, or a gap between drawn looks and walkable boxes when streaming loads them
- the camera in tight spaces (the Crack, under the bench, inside cans, on the line)
- z-fighting or flicker between coplanar parts (soil over ground, path over lawn, water)

Fix what you find, or list what you leave, with screenshots in `docs/verification/v49/`. Add self-test checks for the fixes that can be pinned:
nothing below the ground's top, held prey within the chelicerae, the camera boom not inside geometry.

## 6. Also in scope

- **Settings.** Add settings toggles for the new prompts if they fit the existing Settings panel ("Show control hints" may already cover
  them; extend it).
- **Feeding feedback.** Add a soft sound per bite and a quiet sound at the meal's end, if any existing audio fits.
- **Your v48 limits.** Check the v48 performance and art limits you listed, and whether they are still true after this round.

## Deliver

One release as v49, by the usual route:

- CLI all green and the native Studio self-test passing
- published to the existing place
- `chet/review-5.md` in the Project with what changed, the numbers, the screenshots and what Nathan should test
- a short Claude handoff naming the branch and commit, and any decision Claude should know
