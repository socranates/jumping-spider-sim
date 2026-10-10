# Jumping Spider Sim
## Design specification and implementation handoff for Claude

**Version:** 0.1 · **Prepared:** October 4, 2026 · **Status:** proposed design, ready for prototype implementation  
**Workflow:** Chet → Claude implementation → Chet review → iteration  
**Deliverable now:** this specification. No game code or playtest results are implied by it.

> Simulate a jumping spider's relationship with the world, rather than simulate a videogame and shrink the player.

> You are not becoming the master of the world. You are becoming exceptionally good at being one small living thing inside it.

## 0. Start here, Claude

Build a small, third-person, single-player 3D prototype about inhabiting a jumping spider. Start with traversal and a single hunt on a windowsill. Prove that stopping, looking, choosing a route, committing to a jump, and recovering on silk are pleasurable before building an ecosystem or a lineage simulator.

This document distinguishes four levels of commitment:

| Label | Meaning |
|---|---|
| **P0 / slice** | Required to demonstrate the core loop. Implement only after its dependencies work. |
| **P1 / next** | Needed for a credible life simulation after the slice succeeds. |
| **P2 / later** | Promising expansion; not authorization to delay the slice. |
| **Research** | Biological or technical assumption requiring validation before a realism claim. |

All numerical tuning values below are **prototype hypotheses**, not measurements of real spiders. Engineering budgets are targets, not achieved benchmarks. Biological claims have separate sources and limitations in sections 5 and 28.

### Working defaults

- **Engine:** Godot 4.x stable, typed GDScript, desktop Windows first. Pin the exact installed stable version and physics backend in the repository before implementation.
- **View:** third-person macro perspective, horizon-stable camera by default.
- **Animal:** a fictional individual modeled on the bold jumping spider, *Phidippus audax*. Do not combine every remarkable salticid ability into one species.
- **Location:** an indoor windowsill, planter, wood trim, and a sheltered crack. The outdoors is visible but inaccessible in the slice.
- **Session:** a 10–15 minute authored introduction that remains replayable as a small systemic sandbox.
- **First engineering milestone:** a graybox spider can walk, turn, jump to a ledge, miss, hang on a line, and climb back. No prey is required for this milestone.
- **First review handback:** the movement milestone, its tests, a short capture, and known problems. Continue through the slice only if practical; do not silently expand scope.

Proceed with these defaults unless an existing project already makes a different choice. Inspect existing code and preserve useful work. If starting in the ChatGPT project mirror, keep `sources/` untouched and put implementation in a new `prototype/` directory. Do not replace synced reference files.

### Non-negotiable guardrails

1. Movement and camera comfort outrank world size, visual fidelity, and simulation breadth.
2. No RPG damage ladder, crafting inventory, quest errands, loot treadmill, or permanent stat inflation.
3. No web shooting, distant grapple attachment, free flight, midair double jumps, or orb-web building for this species.
4. No omniscient prey AI, threats spawning behind the player, or unexplained random death.
5. No forced permadeath, mandatory reproduction, or tedious hunger maintenance.
6. No claim to reproduce subjective spider consciousness or literal spider vision.
7. No eight-leg rigid-body controller, general fluid simulation, full-house simulation, networking, or custom engine in P0.
8. A smaller finished loop is preferable to disconnected demonstrations of every system in this document.

## 1. Core philosophy: make the ideas playable

The game is about attention, vulnerability, place, and continuity. Philosophy should be experienced through decisions and consequences, without narrated conclusions about what life means.

| Theme | Mechanic that carries it | Failure to avoid |
|---|---|---|
| Attention | Looking carefully distinguishes prey, danger, and harmless movement. | A scan button that reveals every answer. |
| Limited knowledge | Perception produces estimates and memories that can become stale. | Arbitrarily hiding essential control feedback. |
| Scale | A crack is shelter; a spoon becomes a bridge; moving a pot changes a route. | Enlarged human furniture with ordinary platform-game scale. |
| Mortality | Each life has a beginning, changes, and an ending; places persist. | Calling a short life a failed run. |
| Meaning without conquest | A safe return or an unexpected sight can be its own reward. | Turning every observation into currency. |
| Continuity | Retreat remnants and habitat changes survive individuals. | Giving offspring the parent's autobiographical memory. |
| Humility | Humans and weather operate on rhythms beyond the spider's influence. | Untelegraphed catastrophe that invalidates skill. |

Stillness must be supported mechanically. The player should be able to stop on a leaf and watch for a minute without a survival meter becoming an emergency. Warmth, changing light, and nearby life should reward attention even when nothing is collected.

The game must also be fun without its philosophical interpretation. A child should enjoy a satisfying jump and a funny fly escape. An adult may remember the same event as a story about patience. Neither interpretation should be prescribed by the UI.

## 2. Player fantasy and emotional rhythm

**Player fantasy:** “I am alert, capable, curious, and very small. I know this little place better each time I cross it.”

The spider is an animal, not a miniature person with a job. Its body is expressive through orientation, pauses, foreleg positioning, and motion. Avoid eyebrows, dialogue, human smiles, or exaggerated pet obedience. Players may name an individual, but the game does not imply the animal understands its name.

Aim for a repeating rhythm of curiosity → observation → anticipation → brief action → recovery → quiet. Do not alternate hunger alarms and predator alarms forever. Early tuning should permit at least as much quiet observation and free traversal as high-pressure activity.

Humor comes from consequences of scale: a fly escapes while the spider is carefully lining up a leap; a harmless pencil rolls into a familiar route; a confident landing is interrupted by a leaf bending. Do not secretly alter physics to force a joke.

**Aspirational five-minute story:** You leave a silk crack, notice movement on the planter rim, climb underneath to approach unseen, wait through a gust from an opening window, jump, miss, catch your line, recover, and discover the fly has landed closer to home. Nothing needed a quest marker.

## 3. Gameplay pillars and priority conflicts

1. **Embodied movement:** surfaces, orientation, launch commitment, and contact matter.
2. **Observation before certainty:** orienting toward a signal improves information.
3. **Legible systemic life:** animals pursue needs and react to evidence.
4. **A meaningful home:** retreat is a place in the world, not a menu teleport.
5. **Finite lives in a persistent place:** progression is largely learning and continuity.
6. **Generous accessibility:** assistance preserves meaningful choices while reducing execution barriers.

When pillars conflict, use this order: control comfort → readable causality → core animal identity → interesting decisions → biological detail → visual spectacle. Document deliberate compromises. A beautiful but nauseating wall camera loses; a scientifically inspired but incomprehensible sensory effect loses.

## 4. Loops and progression

### Seconds: orient and commit

Detect a cue → turn/focus → select a foothold or target → approach → prepare → leap → land or recover. Preparation is calm and readable; the leap is brief and committed. The player must be able to cancel preparation without penalty beyond elapsed time.

### Minutes: leave and return

Exit retreat → choose a local opportunity → hunt or investigate → respond to environmental change → feed, drink, or rest → return or find another refuge. Exploration is a valid choice when sufficiently fed.

### A life: P1

Grow through stage-appropriate molts → learn routes and changing conditions → encounter other spiders → optionally court and reproduce → age or die. Skip uneventful resting intervals. Reproduction adds a possible continuation; it is not the only satisfactory ending.

### Many lives: P2

The habitat retains selected changes; a new individual encounters an altered version of a familiar place. Player knowledge persists. Individual memories reset. A field notebook and lineage archive belong explicitly to the player.

### Progression without a power treadmill

- **Skill:** more reliable jumps, better stalking, earlier recognition of danger.
- **Place knowledge:** useful routes, shelter quality, recurring prey opportunities.
- **Growth:** stage-specific body proportions and needs, with tradeoffs rather than universal upgrades.
- **Relationships with habitat:** established retreats, disturbed areas, seasonal accessibility.
- **Discovery:** an optional naturalist notebook with sourced facts, separated from in-world perception.

Do not award experience for killing prey or exploring every corner. Optional goals can suggest experiences (“try watching from above”) without becoming a completion checklist. There is no total-life score.

## 5. Biological grounding and limits

Use a species profile rather than scattered “spider facts.” Start with *P. audax* as an anchor because its ecology and visual behavior offer useful references. This does not make every parameter in this design biologically validated.

| Topic | Evidence and boundary | Gameplay translation |
|---|---|---|
| Multiple visual systems | Salticid principal eyes support detailed inspection; secondary eyes have important motion functions. Species differ. [B1](https://pubmed.ncbi.nlm.nih.gov/33885956/) | Broad movement cues, narrower inspected classification. |
| Looming response | Experiments in *P. audax* implicate anterior lateral eyes in responses to looming stimuli. [B2](https://pmc.ncbi.nlm.nih.gov/articles/PMC3497142/) | A readable directional cue for an approaching large object. |
| Dragline function | Work on *Hasarius adansoni* supports stabilization and braking roles during jumping; this is cross-species evidence, not a complete *P. audax* model. [B3](https://pmc.ncbi.nlm.nih.gov/articles/PMC3758018/) | Automatic takeoff anchor and forgiving recovery; solver details are a design abstraction. |
| Life history | A university species account describes seasonal maturation and reproduction in *P. audax*. Geography and conditions matter. [B4](https://www.biokids.umich.edu/critters/Phidippus_audax/) | Species/region data drives stages and calendar, not a universal spider schedule. |

**Before P1, research:** body-size ranges by stage/sex; substrate adhesion; hydration and feeding intervals; molt timing and vulnerability; courtship cues; overwintering stage; hearing and substrate vibration; plausible prey; injury recovery. Keep a fact ledger with claim, species, source, confidence, mechanic, and compromise.

Do not give *P. audax* specialized *Portia* hunting strategies as a default. Do not copy peacock-spider display choreography onto it. Do not assume all salticids see the same colors or UV detail. UV-inspired palettes are visual interpretation unless specifically validated.

The slice models safety lines and retreat silk, not an orb capture web. Proposed walking on smooth or inverted surfaces needs species/material validation; controllable adhesion is initially an explicit abstraction. Predatory feeding can be represented through restrained contact and an interruptible feeding state without graphic anatomy.

Avoid inferring scientific cognition from player actions. The player may plan a route; this does not demonstrate that a real spider reasons in the same way. Likewise, music and amplified footstep sounds are translations for a human audience.

## 6. Movement and camera: the first engineering risk

### 6.1 Coordinate and unit contract

Use a normalized 3D world where **1 world unit (WU) = 1 cm of represented habitat**. A reference body length is 1 WU; actual individual body length is a data value. This prevents a millimeter-sized physics body from inheriting unsuitable meter-scale tolerances.

Use seconds for action simulation, WU for positions/velocities, degrees Celsius for temperature data, and normalized [0,1] values for uncalibrated needs. If modeling physical Earth gravity at this scale, its magnitude would be about 981 WU/s². The prototype deliberately starts with **tuned gravity of 35 WU/s²** to make jumps readable. Do not present that value as biological realism. Keep action timing separate from the life calendar.

Define `WORLD_UP = (0,1,0)`, a contact normal, and a tangent basis per supported body. Earth-down gravity remains world-down while airborne; it does not rotate toward the last wall. Attached locomotion uses a support constraint. Surface attachment and gravity are different concepts.

### 6.2 Motor states

`ATTACHED → PREPARING → AIRBORNE → LANDING → ATTACHED`

Additional states: `FALLING`, `HANGING`, `REELING`, `FEEDING`, `RESTING`, and later `MOLTING`, `DEAD`. Feeding/resting lock locomotion only while their action is active; canceling returns control promptly. Death cannot be entered twice.

Supported walking projects desired movement onto the contact tangent plane. Use a simple body collider and a few support probes; leg animation is cosmetic. Contact acquisition uses distance, outward normal, surface eligibility, and approach velocity. Hysteresis prevents alternating between adjacent triangle normals.

For convex edges, sample ahead and underneath; transfer support only when a valid neighboring surface and collision-free transition exist. For concave corners, stop or follow a valid tangent. No snapping through thin geometry. Disallow transitions across unsupported gaps. P0 requires floors, vertical walls, and a broad underside route; arbitrary narrow twigs and deformable foliage come later.

### 6.3 Jump contract

Tap jump for a short hop in the facing direction. Hold jump for preparation and release to commit; support toggle-prepare/tap-confirm as an accessibility alternative. Aim selects a surface point, never an invisible target magnet. Rotating the camera alone does not instantly rotate the spider's perception.

Initial tuning: walk 2.5 WU/s, stalk 0.8 WU/s, preparation 0.15–0.4 s, selected flight duration 0.35–0.6 s, normal jump distances about 2–5 reference body lengths. Values must be tuned together; do not separately clamp distance while displaying an impossible trajectory.

For a candidate landing point, solve:

```text
launch_velocity = (target - launch_position - 0.5 * gravity * T²) / T
```

Select a duration `T` within the tuning range that satisfies launch-speed and reach constraints. Reject unreachable candidates clearly. Prediction uses the same integration, collision shape, gravity, and silk configuration as the runtime motor. An unobstructed point ray is not enough: the whole body must fit along the path and at landing.

Default assistance shows a small landing patch and uncertainty band; optional detailed arc is available. Patch styling communicates reachable, obstructed, and uncertain using shape plus color. Wind or moving targets widen uncertainty; the UI must not promise a guaranteed catch. In P0, use static launch/landing surfaces and calm air before adding gusts.

Commit freezes the planned impulse. No post-launch retargeting. Air steering is off initially; if tests need it, introduce only small, bounded assistance and document it. Separate visual body stabilization from trajectory manipulation.

On collision, classify valid support, glancing impact, prey capture, or obstruction. A missed intended platform can still land on another eligible surface. Do not punish every fall by height alone: surface, impact, and recovery matter. P0 uses recoverable misses and a clearly labeled reset for out-of-bounds failures.

### 6.4 Camera contract

Third-person camera, slightly elevated behind the spider, with adjustable distance and field of view. Start at 4–7 body lengths and 65° vertical FOV, then playtest. Preserve the world horizon by default while the body follows surface normals. Offer optional surface-relative orientation later.

- Sphere-cast the camera boom, retract smoothly, and recover without passing through surfaces.
- Never force a sudden roll when the spider rounds a corner or walks upside down.
- Use damped follow, adjustable look sensitivity, invert axes, and a reliable recenter action.
- Preserve a view of the landing region during preparation; do not swing behind the body at release.
- Focus can gently tighten framing, but must not force a dramatic zoom or motion blur.
- Camera-visible actors outside the spider's sensed information receive no identification overlay. Do not hide ordinary third-person visibility behind unreadable blur; this is an acknowledged viewpoint compromise.

Macro depth of field belongs in optional beauty/photo settings. Default gameplay should keep important landing geometry and threats readable.

## 7. Perception and vision

P0 needs a functional information model, not a complicated shader. Separate **world truth**, **sensed evidence**, **individual memory**, and **player presentation**.

Two channels are sufficient initially:

1. **Peripheral motion:** broad angular coverage, coarse directional evidence, no exact species label. Moving leaves can create low-salience cues, but throttle repeats.
2. **Forward inspection:** a narrower body-facing cone, unobstructed sight, enough exposure time, and sufficient apparent size produce a category estimate.

Prototype settings: a 30° inspection cone, 0.4 s continuous observation to classify easy prey, 0.8 s cue cooldown, and memory confidence decay over several seconds after losing sight. These are gameplay parameters, not anatomical measurements.

Store evidence such as position estimate, category probabilities, confidence, last-seen tick, and source modality. An object behind opaque cover cannot be updated from its true position. If it leaves the inspected region, use its last observation; do not keep a lock-on marker following it through the pot.

Focus commands deliberate orientation and inspection. It is not an X-ray scanner or mandatory time slow. Optional slow-time assist slows the whole action simulation consistently, including prey and hazards. UI remains responsive.

Later, add substrate vibration only across connected materials/silk with attenuation. Do not implement vibration as an unrestricted radius that travels through air gaps. Surface sounds and audiovisual cues must describe the same sensed event.

**Player learning:** repeated encounters help the human recognize movement. No automatic “+5 identification” upgrade is needed. The optional notebook may reveal a factual species name outside the spider's immediate experience.

## 8. Hunting, prey, and threats

### 8.1 The hunt

Detect → inspect → approach or wait → choose a launch → commit → capture or miss → decide whether feeding is safe. A chase is not always worthwhile. Prey should sometimes leave, allowing the player to choose another opportunity.

P0 uses one fly-like prey archetype with perched and flying states. “Fly-like” denotes prototype behavior; choose a real species and retune before making educational claims. Start with 3–6 individuals and authored perch points. They rest, move toward a food attraction, notice nearby threats, and flee to reachable alternatives.

Capture is a swept spatial interaction: the spider intersects a valid capture volume with suitable relative position/speed during a committed strike. Resolve it once, with a stable event ID. Do not use an unexplained probability roll after apparent contact. Broadening the capture volume is an explicit assist setting.

Feeding is a brief, cancelable action that restores reserves gradually. Prey state changes to captured before any energy is granted. Partial consumption cannot be duplicated by reloading. Keep camera framing gentle; no mandatory close-up of predation.

### 8.2 AI structure

Use a small **utility selector for goals** plus **finite state machines for execution**. Avoid behavior-tree frameworks until complexity warrants them.

```text
Fly execution states:
PERCHED → ALERT → TAKEOFF → FLEE → SEEK_PERCH → PERCHED
PERCHED → REPOSITION → PERCHED
any living state → CAPTURED → CONSUMED
```

Goal utility can combine food attraction, fatigue, perceived threat, perch shelter, and travel cost. Normalize inputs to [0,1], use explicit weights, and log the winning reason. Add hysteresis and minimum commitment time to prevent rapid state switching; immediate credible danger may interrupt.

Detection depends on visible angular motion, distance, occlusion, and sensed disturbance. The fly does not read the player's jump input. Reaction delay and acceleration are tunable, visible in debugging, and reproducible from a seeded stream when variation is used. A perched fly can miss a slow approach; a poorly timed close jump should often startle it.

P0 movement uses a small perch graph and collision sweeps, not general-purpose flying navigation. A perch is validated for clearance and reachability before commitment. If blocked, choose another; never teleport to complete the behavior.

### 8.3 Predators and rivals

P1 adds one predator archetype with search, inspect, approach, strike, disengage, and rest. It has limited evidence and costs for pursuit. Threat displays and withdrawal should precede many rival fights. No boss health bars.

For the slice, a looming shadow and surface disturbance can test warning and shelter responses without a fully implemented predator. It must be identified as a controlled environmental encounter, not proof of predator AI.

Future prey roster should differentiate decisions: alert winged prey, tiny intermittent movers, armored prey best ignored, and risky opponents. Add one at a time only when it creates a distinct hunt. Not every visible animal must be edible or interactive.

## 9. Silk and retreat

### 9.1 P0 safety line

At takeoff, automatically attach a line to the current eligible contact surface. An anchor stores persistent surface ID and local attachment point. No remote aiming or attachment through walls. Show a small anchor cue; lack of a usable attachment must be clear before committing.

During a normal leap, pay out line so it does not truncate the predicted trajectory. Freeze the paid-out length on a miss/fall up to a configured maximum. Model one unilateral tether: it limits extension but never pushes. Preserve tangential motion; remove or damp outward radial velocity when taut. A small visual pendulum is acceptable; intentional superhero swinging is not a core mechanic.

Reeling shortens rest length at a capped rate and cost. Recovery movement still collides with the world. If a straight path to the anchor is blocked, stop and allow lowering/releasing; never pull the body through the ledge. A single obstacle bend point may be added if required by the recovery test. General rope wrapping is out of scope.

Collision-safe tether projection is essential: sweep before any corrective displacement, recompute feasible extension, and resolve conflicts without injecting velocity. If the constraint is infeasible, stop reel-in or detach with a clear cue. Retain a separate recoverable debug fallback; do not hide a solver failure as biological silk breakage.

Render a cheap segmented curve; physics does not require a chain of rigid bodies. Completed ordinary lines can fade and be removed; retained home silk is explicit world state. Avoid unlimited persistent strands.

### 9.2 P1 silk economy and home

Silk reserve recovers with feeding/rest through an abstract resource model, not harvested crafting items. P0 should provide enough silk that early experiments are not punished. Cost balance is deferred until traversal succeeds.

Retreat construction chooses a sheltered crevice from environmental affordances. A short weaving interaction establishes an anchored silk shelter with location, cover, disturbance, and occupant data. Do not turn it into furniture placement. The player can maintain or abandon it.

Retreat supports rest, later molting and egg protection, and a recognizable return destination. It reduces exposure but does not produce invulnerability. Damage or displacement has physical causes. Multiple retreats are P2; one authored retreat is sufficient for P0.

## 10. Environmental simulation and ecology

Simulate the variables that affect decisions, not everything that exists.

**P0 habitat:** approximately 60 × 25 × 35 WU; a planter rim, broad leaf platforms, wood trim, opaque cover, an underside path, and a crack retreat. Static authored topology. Provide a low-risk floor route and a faster exposed route to a useful perch.

Represent material and affordance data separately: wood/glass/leaf identity does not automatically dictate every interaction. Each surface profile supplies attachability, anchor eligibility, slipperiness, disturbance transmission, and wetness response. Decorative microdetail must not create invisible collision hazards.

**P1 microclimate:** coarse zones track temperature, humidity, wetness, light, airflow, and shelter. Time of day, weather, and nearby objects modify these fields. Do not start with a grid per millimeter or a fluid solver. Smooth transitions to avoid behavior flickering across zone boundaries.

**P1 food web:** prey resource patches attract insects; resource availability and shelter affect occupancy. Maintain coarse population pools outside the active area. A finite source/sink model prevents either unlimited fly farming or a permanently empty habitat after a few hunts.

New prey enters through authored habitat boundaries, outside current observation, with an ecological reason. Never appear in front of the player. For P0 only, a clearly documented sandbox replenishment rule may replace ecology; do not claim autonomous population dynamics.

World changes should have readable consequences: watered soil changes humidity and prey visitation; moving a pot alters cover and routes; a torn leaf removes a platform. Preserve route redundancy. A persistent world cannot casually delete the only route out of a living spider's refuge.

## 11. Life cycle, needs, injury, and death

### Needs

Track energy reserve, hydration, acute stress, condition, and life stage. Avoid five constantly draining bars. Energy creates a reason to hunt, hydration a reason to attend to habitat, and stress a short-lived response rather than a personality score. Injury/condition must not be a disguised universal combat hit-point economy.

P0 uses energy plus rest only. Hydration, thermal effects, injury, and molt reserve remain data/design placeholders until P1. The first hunt should not be timed against starvation. Reduce need pressure while learning or using photo mode.

### Stages: P1

Egg → juvenile instars → subadult → adult → death. The playable start may be a mobile juvenile; early development can be summarized. Life-stage timing belongs in species data and must be verified. Sex affects appropriate reproductive behavior and morphology without making one option the “complete” game.

Molting requires a suitable retreat and preparation; communicate the coming transition well ahead of time. Compress the inactive interval through safe time advancement. Let the changed body and renewed vulnerability matter afterward. Research stage-dependent limb recovery before implementing it; do not make adults casually regenerate injuries.

Injury should change decisions without making controls frustrating. Prototype mild fatigue and cautious behavior before lost-leg simulation. If limb loss is eventually included, provide toned-down visuals and retain reliable input. The presentation rig, not the core contact solver, handles absent legs.

### Death and continuation

Offer three configurable presets with the same world rules where possible:

- **Gentle:** nonlethal severe-threat recovery, forgiving needs, optional reload.
- **Natural:** individual death, checkpoint reload or continuation as another spider.
- **Lineage challenge:** optional irreversible individual deaths; never the default.

Explain fatal events with information the player could have learned. A life summary emphasizes places, escapes, rests, and changes, not kills or rank. Let the player skip it.

If there are no viable descendants, permit a nearby unrelated spider or a fresh individual in the persistent habitat. Label the broken lineage honestly. Do not generate biological offspring retrospectively to avoid an ending. A world reset is always an explicit player choice.

## 12. Generations and evolution: P2, behind a design gate

Separate three concepts:

1. **Individual development:** growth and condition within one life.
2. **Inheritance:** variation passed through reproduction.
3. **Evolution:** population-level changes in trait distributions over generations.

One player's successive characters do not automatically constitute a scientifically credible evolutionary model. Begin with bounded inheritance and call it that. Full evolutionary claims require population sampling, selection, mutation, drift, and validation.

Potential traits: body size, pattern variation, reserve efficiency, and mild NPC behavioral tendencies. Player temperament must not involuntarily override controls. Every functional trait needs a cost or context: larger size may help with some prey but increase demand and reduce access to small cracks. Never evolve laser vision or indefinitely increasing jump distance.

Use a small bounded trait vector, parent IDs, seeded recombination, and low-amplitude mutation. A prototype formula may blend parental values plus bounded noise; label it a simplified inheritance model, not Mendelian genetics. No breeding-screen optimizer is required.

Courtship is a risky exchange of species-appropriate movement and receptivity signals, with a clear retreat option. Avoid rhythm-game scoring and mate collection. Egg sacs become localized, vulnerable world entities; parent care and timing require species validation.

Choose a successor from biologically viable individuals after the relevant time has elapsed. Update world time and habitat state together. Human notebook entries persist, but the new spider begins without the old individual's observed targets or route memory. Discovering an old retreat is a world encounter, not inherited recollection.

## 13. Seasons, weather, and simulation time

Maintain separate clocks: fixed action ticks, habitat time of day, and life-calendar age. Do not shorten a jump when accelerating the calendar. P0 uses a gentle light transition and one scripted gust; no aging during a short demo.

P1 allows rest to advance habitat/life time through bounded simulation steps. Stop time advance on important events or unsafe conditions. Never simulate a year's growth using a single huge physics delta. Pausing stops action, needs, AI, and hazards; menus cannot secretly starve the spider.

P2 seasonal profiles change daylight, prey availability, weather probabilities, vegetation, and shelter opportunities. The chosen species and region determine whether/how overwintering works. Winter is not a universal sleep button or an unavoidable starvation season.

Rain matters through shelter, wet surfaces, droplets, and runoff paths. Render many drops but simulate only a bounded set of nearby meaningful interactions. Small scale does not mean multiplying human fall damage or rain damage. Water adhesion, entrainment, and drowning deserve separate research; P0 has no water physics.

Weather should announce itself through several channels: changing light, leaf motion, distant patter, localized vibration, and UI alternatives. On first encounters, provide reachable shelter and time to recognize it. Forecasting skill comes from patterns, not a perfect weather minimap.

## 14. Humans and the larger world

Humans operate first as environmental schedules and object interactions. A hand, shadow, moving cup, and transmitted footstep can convey scale without a fully simulated household.

P0 has one harmless scheduled disturbance: a distant shadow, a mild airflow change, or a gently moved background object. No swatting, vacuum chase, or lethal random cleaning event. P1 adds a telegraphed local habitat change, such as moving a pot after a warning.

Later, different household routines influence habitat without presenting humans as quest-giving NPCs. Relocation in a cup can change territory; cleaning may remove a retreat; watering can create new insect opportunities. Each event needs safe collision handling, preview cues, and persistent consequences.

Human stories unfold through objects and routines across generations: a changed plant, a new drawing, a long absence. Do not use intelligible dialogue to explain what the spider is “supposed” to think. Do not compress decades of family life into a few spider days without acknowledging the stylized calendar.

## 15. Art and animation direction

Aim for readable naturalism with selective stylization: appealing posture, tactile surfaces, generous silhouettes, and restrained color. A blade of grass should feel like flexible architecture. Use macro photography as material reference, not as a mandate for constant blur.

The spider requires a recognizable cephalothorax/abdomen silhouette, eight articulated legs, front-facing principal eyes, and subtle pedipalp motion. In P0, a primitive body and simple procedural leg posing are enough. Do not postpone controls while solving a perfect gait.

Use a cosmetic leg-placement rig driven by body velocity and a small probe budget. Blend toward prepared takeoff, airborne tuck, landing, and still inspection poses. Never allow leg IK to move the physics body or decide whether the player is grounded.

Landmarks should be recognizable from several orientations: a chipped pot edge, striped wood, a leaf vein junction. Differentiated materials help orientation. Use authored silhouettes and lighting before high-resolution textures. Avoid total darkness as the only way to communicate night.

An optional simplified spider appearance may soften hairy detail, but must preserve readable orientation and interaction. Do not promise that a spider-centered game will be comfortable for every arachnophobic player.

## 16. Audio direction

Create two layers: an atmospheric human-scale environment and a meaningful close-range sensory translation. A refrigerator hum and distant room activity establish place; carefully localized insect motion and surface disturbances guide attention.

Do not claim that amplified human-audible sound is literal spider hearing. Later vibration cues should use the simulation's sensed events. The same event can drive a low sound, a visual cue, and optional haptics.

Keep the pre-jump moment quiet enough to feel deliberate. Avoid a loud reward sting for every successful capture. Music is sparse and supports changes in attention, not constant peril. Danger signals must remain audible at lower dynamic-range settings without painful peaks.

Use separate ambience, cues, music, and UI levels. Caption important environmental cues with direction when useful. Silence should not remove information necessary for survival.

## 17. UI, onboarding, and accessibility

Default HUD: context-sensitive interaction hint, subtle need states, jump/anchor feedback while preparing, and a compact pause/settings entry. No minimap. A later optional schematic memory map can show visited landmarks without revealing unseen animals.

Explain uncertainty plainly: “movement,” “possible prey,” “lost sight,” rather than percentages everywhere. Developer overlays may expose numbers. Display health/needs more explicitly when the player requests it; minimalism must not withhold essential information.

### Default action map

| Action | Keyboard/mouse | Controller |
|---|---|---|
| Walk / orient | WASD | Left stick |
| Look | Mouse | Right stick |
| Prepare / jump | Space hold/release; tap hop | South face button |
| Focus / inspect | Right mouse, toggle optional | Left trigger |
| Stalk | Shift, toggle optional | Left shoulder |
| Context interaction / feed / retreat | E | West face button |
| Reel when hanging | W, context override | Left stick up |
| Lower when hanging | S | Left stick down |
| Cancel preparation / release tether | Q, context-labeled | East face button |
| Recenter | Middle mouse or R | Right stick click |
| Pause / settings | Escape | Menu button |

Inputs are remappable actions, not hard-coded keys. Cancel and release must be distinct prompts in their respective states; prevent an accidental second press from dropping the spider during recovery. Support hold-to-release confirmation as an option.

### P0 accessibility baseline

- Full pause, remapping, sensitivity/invert settings, readable scalable text, controller support.
- No required rapid tapping or precise hold duration; toggle preparation and confirm-to-jump.
- Horizon-stable camera; screen shake, blur, and depth of field off by default.
- Shape/text alternatives to color; visual alternatives to meaningful audio; optional haptics.
- Adjustable aim/capture assistance and global slow time, with clearly described effects.
- Independent survival pressure and execution difficulty settings; no shame labels.
- Restart/checkpoint recovery and a reduced-predation presentation option.

Teach by placing a visible foothold, an easy gap, a safe recovery opportunity, and a prey perch in sequence. Prompts respond to uncertainty and disappear after understanding. Repeated failure offers an assist instead of repeating the same instruction. Photo mode pauses all relevant simulation; leaving it restores camera and input reliably.

## 18. Systemic storytelling

The game generates events; it does not need a generative language model at runtime. Use a small, structured event journal with causal links: actor, place, observed time, action, consequence, and relevance.

Example chain: `gust_started → prey_relocated → jump_missed → tether_recovery → retreat_entered`. A life summary may turn verified events into restrained templates: “You returned to the crack after the wind changed.” Never invent fear, gratitude, courage, or a relationship the simulation did not represent.

Track significant events, not every footstep. A repeated ordinary hunt should not overwhelm the record of a changed home. Journal only events observed by the player or appropriate to an explicitly omniscient archive; do not expose hidden threats through storytelling.

Author opportunities rather than outcomes: prey attraction near a difficult gap, two routes with different exposure, a gust affecting both spider and fly. Do not secretly ensure a miss, rescue, or victory. Let the player do nothing.

Separate **pacing assistance** from ecological truth. A pacing manager may delay an optional event when the player is already overloaded; it cannot teleport predators or rewrite a committed jump. Expose event scheduling in debugging.

## 19. Engine choice and technical architecture

### 19.1 Recommended starting stack

**Choose Godot 4.x stable and typed GDScript for a greenfield prototype.** This is a project-fit recommendation: a small scene-based desktop game, rapid iteration, readable source, and a limited initial team. It is not a claim that Godot will automatically solve arbitrary-surface locomotion or outperform other engines.

Use `CharacterBody3D` as the collision/motion foundation for the spider with a custom contact controller. Its user-controlled motion facilities are documented in the [official class reference](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html). Do not expect floor snapping alone to support walls and ceilings; validate the chosen collision calls against the pinned engine version.

Start with the Compatibility renderer to keep a simple graybox broadly runnable; reassess appearance and hardware needs after profiling. Godot provides multiple renderers with different capabilities; consult the [official renderer overview](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html) before adopting renderer-specific effects. Web and mobile exports are not P0 requirements.

Pin exact engine version, renderer, physics backend, import settings, and export templates in `README.md` and a small toolchain record. Use documentation for that version. Do not repeatedly upgrade the engine during a milestone.

| Alternative | Reason to choose it | Decision here |
|---|---|---|
| Unity | Existing maintainable Unity prototype or strong team expertise and tools. | Keep it if already established; do not port merely to follow this document. |
| Unreal | A team and project centered on high-end environment production. | Not the default for this small initial slice. |
| Browser-first engine | Browser delivery becomes a primary requirement. | Reassess scope and performance before selecting it. |

Before switching engines, produce a short decision record with the demonstrated blocker, attempted remedy, and migration cost. Do not spend the first implementation session conducting an open-ended engine comparison.

### 19.2 Suggested repository layout

```text
prototype/
  project.godot
  README.md
  THIRD_PARTY_NOTICES.md
  docs/
    SPEC.md
    DECISIONS.md
    BIOLOGY_LEDGER.md
    TEST_REPORT.md
    HANDOFF.md
  scenes/
    main.tscn
    habitats/windowsill.tscn
    actors/spider.tscn
    actors/fly.tscn
    testbeds/traversal_lab.tscn
    testbeds/silk_lab.tscn
  scripts/
    core/                 # Clock, IDs, registry, event queue, seeded RNG
    movement/             # Motor, support probes, jump solver, camera
    perception/           # Sensor sampling and observation memory
    ai/                   # Goal selection and execution states
    silk/                 # Tether physics, anchors, visual curves
    habitat/              # Surfaces, zones, perches, disturbance events
    life/                 # Needs and feeding; stage simulation later
    persistence/          # Snapshot, validation, migrations, file writes
    presentation/         # Spider rig, HUD, audio adapters, settings
  data/
    species/
    surfaces/
    tuning/
  tests/
    unit/
    integration/
    fixtures/
  assets/
    placeholder/
```

Do not create empty abstractions for all future folders at once. The layout identifies ownership; implement only what the current milestone requires. Keep test scenes out of the shipping main flow. Use text scenes/resources and document asset licenses. Avoid paid assets or mandatory external services for P0.

### 19.3 Ownership and interfaces

| Module | Owns | Must not own |
|---|---|---|
| `WorldClock` | Fixed ticks, pause, calendar conversion, time scale | Moving scene objects |
| `SpiderMotor` | Authoritative position, velocity, contact and movement state | Needs, camera roll, plot events |
| `JumpPlanner` | Candidate trajectories and validity/uncertainty output | Secretly changing airborne targets |
| `SilkController` | Anchor, payout, tautness, recovery constraint | Teleporting through collision |
| `SensorSystem` | Evidence acquisition | AI decisions or omniscient HUD labels |
| `ActorBrain` | Goal choice, state transitions, intention | Direct unvalidated transform writes |
| `NeedsModel` | Reserves and approved consumption changes | Frame-dependent draining |
| `HabitatState` | Persistent surface/object/zone state | Camera or presentation effects |
| `SaveService` | Validated snapshot, migration, replacement and recovery | Serializing arbitrary live nodes |
| `Presentation` | Meshes, animation, audio, UI from state/events | Authoritative capture or death |

Useful initial contracts, expressed as conceptual signatures rather than drop-in engine code:

```text
sample_support(body_pose, prior_support) -> SupportResult
plan_jump(origin, target, tuning, world_query) -> JumpPlan
step_motor(intent, dt, collision_query, tether_state) -> MotorResult
sense(observer, nearby_candidates, dt) -> Observation[]
choose_goal(needs, observations, current_goal) -> GoalDecision
capture_attempt(spider_id, prey_id, contact, tick) -> CaptureResult
snapshot(world_state, content_revision) -> SaveEnvelope
restore(validated_envelope, registry) -> RestoreResult
```

Pass inputs explicitly. Pure numerical helpers must not reach into global scene state. Use local signals or a small typed event queue for cross-system consequences, not an unstructured global message bus. One system owns each authoritative variable. Presentation consumes committed state.

## 20. Simulation architecture and ordering

### Fixed-step schedule

Start at **60 action ticks per second**. Sample input intent continuously but consume discrete actions once at the next fixed tick. Run physics transforms in the fixed update. Use interpolation for rendering; Godot's [interpolation guidance](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/using_physics_interpolation.html) also calls for resetting interpolation after teleports. Treat camera smoothing as presentation, not an extra physics integration.

Within a tick:

1. Apply queued input and scheduled habitat changes; honor pause/time-scale state.
2. Update due sensors from the previous committed world state.
3. Update due AI decisions and generate movement intents.
4. Step movement and tether constraints, including swept collision checks.
5. Gather contacts; resolve capture and other interactions in stable ID order.
6. Apply needs, feeding, and state consequences once.
7. Commit events, increment tick, and allow a save snapshot at this boundary.
8. Present interpolated state; never let visual callbacks grant energy or kill prey.

All sensors in a given update phase should read a consistent snapshot, not see some actors after movement and some before. Stable ordering reduces avoidable nondeterminism but does not make engine physics bit-identical across devices.

Use separate seeded random streams for habitat scheduling, prey choices, and later inheritance. Cosmetic randomness must not consume gameplay RNG. Persist stream states when exact continuation matters. Do not claim cross-platform deterministic replay; target repeatable high-level outcomes within a pinned build and tolerate small floating-point divergence.

### Rates and spatial scope

| System | P0 starting rate | Notes |
|---|---|---|
| Player and nearby collision motion | 60 Hz | Sweeps/substeps where speed demands it. |
| Prey locomotion | 60 Hz | Decisions can be slower than motion. |
| Broad sensory queries | 10 Hz | Cache spatial candidates. |
| Close capture/looming checks | Every action tick | Avoid losing a short encounter between sensor updates. |
| Utility decisions | 5–10 Hz | Stagger actors; immediate interrupt on committed threat event. |
| Needs / zone updates | 1–2 Hz | Integrate actual elapsed action time. |
| Remote habitat population | P1, coarse time steps | No off-screen individual physics. |

P0 uses one active habitat. P1 adds a spatial index and three simulation levels: nearby individual actors; nearby-but-unseen coarse state; remote aggregate populations. Promotion to full simulation must avoid visible spawning, duplicate identities, or creating extra resources. Demotion must preserve prey captured by a persistent actor. Do not invent a general ECS solely for a dozen insects.

### Time safety

Cap catch-up work per rendered frame and record overruns. Never integrate an arbitrarily large physics step after a stall. If necessary, slow simulated progress visibly rather than tunneling through the world. Calendar fast-forward uses its own bounded updates. Slow-time assistance affects the action clock uniformly; real-time settings/UI do not slow.

## 21. Data schemas and invariants

Use Godot Resources for trusted authored tuning if convenient, and plain validated data for saves. The following JSON illustrates the canonical data contract; it is not a requirement to build a JSON-heavy runtime. Unknown required fields or invalid units should fail validation with a useful error.

### 21.1 Species profile

```json
{
  "schema_version": 1,
  "id": "phidippus_audax_prototype",
  "biological_status": "approximation_pending_species_review",
  "body_length_wu": 1.0,
  "locomotion": {
    "walk_speed_wu_s": 2.5,
    "stalk_speed_wu_s": 0.8,
    "gravity_wu_s2": 35.0,
    "max_launch_speed_wu_s": 14.0,
    "flight_time_min_s": 0.35,
    "flight_time_max_s": 0.6
  },
  "perception": {
    "inspect_cone_degrees": 30.0,
    "easy_target_inspection_s": 0.4
  },
  "silk": {
    "max_line_length_wu": 8.0,
    "reel_speed_wu_s": 1.5
  },
  "life_cycle_profile_id": null,
  "evidence_refs": ["B1", "B2", "B3", "B4"]
}
```

`evidence_refs` identify context, not support for every numeric field. Keep measured and designed values distinguishable in the biology ledger. Stage/sex variation becomes separate data once researched. Do not encode an unvalidated lifetime by copying a number from another species.

### 21.2 Surface profile

```json
{
  "schema_version": 1,
  "id": "painted_wood_dry",
  "attachable": true,
  "silk_anchor_allowed": true,
  "adhesion_multiplier": 1.0,
  "vibration_group": "window_frame",
  "wetness_response_profile": "wood_default"
}
```

Normalized multipliers are tuning abstractions. `vibration_group` must eventually correspond to connected geometry, not all wood in the world. Surface instances have separate persistent IDs and transforms. A moving surface keeps its ID; destroying it invalidates dependent anchors through an explicit event.

### 21.3 Runtime records

| Record | Required fields and constraints |
|---|---|
| `EntityState` | Unique stable ID, archetype ID, position `[x,y,z]`, normalized quaternion `[x,y,z,w]`, velocity, active state, zone ID. Reject NaN/infinity and unknown archetypes. |
| `SupportState` | Surface ID or null, local contact point, normal, validity tick. Revalidate on restore before attaching. |
| `Observation` | Observer ID, target ID if resolved, estimated position, modality, confidence [0,1], observed tick, category. Never refresh from hidden truth. |
| `PreyState` | Execution state, goal, state elapsed ticks, target perch ID, feeding/capture ownership, cooldowns. Captured prey has exactly one owner. |
| `TetherState` | Anchor surface ID/local point, paid length, maximum length, taut state, optional bend point, reel intent. Lengths nonnegative and bounded. |
| `RetreatState` | ID, attachment surface, entrance point, shelter rating, integrity, occupant IDs, creation tick. Missing support makes it unavailable. |
| `NeedState` | Energy/hydration/stress/condition [0,1], update accumulator, stage ID. Only enabled needs are simulated. |
| `WorldEvent` | Unique ID, type, tick, actor IDs, location, payload version, optional cause ID, observed flag. Consequences are idempotent. |
| `LineageRecord` | P2: individual ID, parent IDs, birth/death time, traits, descendants. Validate cycles and missing ancestors gracefully. |

Store times as integer action ticks where exact order matters, plus separately named calendar values. Never overload a field named `time` with several units. Use IDs, not node paths, memory addresses, or runtime object instance IDs, for persistent references.

### 21.4 Save envelope

```json
{
  "schema_version": 1,
  "game_build": "prototype-0.1.0",
  "content_revision": "windowsill-v1",
  "slot_id": "slot-01",
  "snapshot_tick": 4200,
  "seed": "174905",
  "rng_states": {"prey": "serialized-stream-state"},
  "clocks": {"action_seconds": 70.0, "habitat_hour": 10.0, "life_day": 0.0},
  "player_id": "spider-001",
  "entities": [],
  "retreats": [],
  "habitat_changes": [],
  "pending_events": [],
  "journal": []
}
```

This envelope is illustrative and not a valid playable save: an actual save must include the referenced player and all required state records. Encode large RNG integer states losslessly, for example as decimal strings, rather than risking JSON number precision. Define migrations before changing released schemas.

## 22. Save system and persistence

P0 includes explicit save/load and a retreat checkpoint. Save at a fixed-tick boundary after contacts and consumption resolve. Snapshot the player, prey, tether, active interaction, needs, clock, RNG, perches with mutable state, scheduled events, and meaningful habitat changes. Restore a consistent moment, not a collection of unrelated node snapshots.

Godot documents JSON-based persistence and its type limitations in [Saving games](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html). The following stronger transaction and validation requirements are project decisions:

1. Build an immutable snapshot in memory and validate IDs, references, types, finite values, and bounds.
2. Serialize to a temporary file in the save directory; flush/close and validate by reading it back.
3. Preserve the previous valid save as backup and replace the target using a platform-appropriate safe sequence.
4. Test interrupted writes on the supported platform; do not claim crash safety from a successful normal write.
5. On load, validate before instantiating anything. Create entity shells by stable ID, restore their data, then resolve references.
6. Restore clocks/RNG/events, clear stale presentation state, reset interpolation, and resume only after validation completes.

Keep user settings separate from world saves. Avoid loading arbitrary serialized objects or scripts from save data. A malformed save should produce a clear error and offer backup recovery, never silently overwrite the last good file.

Handle missing surfaces explicitly. If content changes remove a tether anchor, detach into a safe restored state or use a documented checkpoint fallback with notice. Do not attach to whichever node happens to occupy the old scene path. Back up the original before migration. Reject newer unsupported schemas without modifying them.

P0 must restore an airborne or hanging spider for reliable debugging. If this is temporarily deferred, label the limitation and snapshot a complete last-safe checkpoint consistently; never save current prey with an older player state and call that exact resume.

Outside the slice, persistent history should be bounded: meaningful retreats, habitat changes, lineage summaries, and a capped event journal. Do not store every silk strand or every insect that ever lived. Rest/checkpoint autosaves must not erase the player's only recoverable state immediately after a death.

## 23. Physics and technical risk register

| Risk | First mitigation | Evidence required |
|---|---|---|
| Wall/ceiling controller feels unstable | Broad authored surfaces; explicit support frame; hysteresis. | Traversal lab with corners, underside, seam, and thin ledge. |
| Tiny scale produces jitter | Normalized world scale; tuned collision margin and collider size. | Repeat traversal at 30/60/144 render FPS. |
| Jump preview lies | Shared solver/integration; shape sweeps; runtime obstruction handling. | Predicted versus actual landing error in calm static scenes. |
| Silk correction crosses geometry | Collision-safe constraint movement; bounded reel-in; blocked recovery state. | Overhang, blocked anchor, long fall, and deleted-anchor cases. |
| High-speed prey tunnels | Swept capture and collision checks; bounded local substeps. | Fast crossing fixture at maximum supported speed. |
| Moving foliage invalidates support | Defer physical motion; later store contact in surface-local space. | Carry velocity, detachment, and anchor movement tests before release. |
| Camera loses player or induces nausea | Stable horizon, collision boom, no mandatory effects. | Wall/ceiling transition playtest with motion-sensitive feedback. |
| AI appears unfair | Perception-limited decisions and debug reason tracing. | Occluded approach and delayed-response fixtures. |
| Life simulation becomes chores | Slow needs, skip inactive time, generous presets. | Players choose to observe without feeling punished. |
| Content overwhelms systems work | One room fragment and one prey archetype. | P0 gate met before adding another biome. |

Do not simulate eight contacting legs, silk elasticity, leaf deformation, and real-scale adhesion simultaneously. Solve the perceptual result with the simplest stable model. Upgrade fidelity only when a specific player-visible failure requires it.

## 24. Performance targets and instrumentation

**Provisional target platform:** Windows 10/11 desktop or laptop, 1080p, 16 GB system RAM, and integrated graphics roughly in the Intel Iris Xe class. This is a profiling target, not a promised minimum specification. Record the actual CPU/GPU, power mode, renderer, resolution, and build for every benchmark.

P0 target: 60 FPS on the nominated reference machine, with a 30 FPS low setting if required. Target p95 frame time ≤16.7 ms over a representative five-minute run, with no recurring long stalls. Measure CPU and GPU frame paths separately; parallel work means their budgets are not simply added.

Initial content/work limits:

| Budget | Starting limit |
|---|---|
| Active prey | 6 in slice; stress fixture at 20 |
| Active player tether | 1 |
| Detailed persistent retreats | 1 in slice |
| Nearby physics/query work | Aim for ≤4 ms p95 CPU; profile on reference hardware |
| AI plus perception | Aim for ≤2 ms p95 CPU |
| Whole-process memory | Aim below 1 GB in slice |
| Save snapshot/file | Aim below 5 MB; no visible hitch over 50 ms |
| Initial slice load | Aim below 5 s from local SSD after imports |

These are investigation thresholds, not reasons to fake inactive actors. Use coarse candidate filtering before line-of-sight checks, stagger AI updates, pool presentation effects where measured allocation costs matter, and use simple collision meshes. Avoid blanket pooling, multithreading, or a custom scheduler before profiling identifies need.

Debug overlay: frame timings, actor counts, physics query counts, motor/support state, surface normal, planned/actual trajectory, anchor and rest length, sensor cones, observation confidence, prey state/goal reason, seed, tick, clock multipliers, and save schema. Allow overlays independently; a single unreadable wall of metrics is not useful.

Log errors with seed, actor IDs, tick, current state, and recent meaningful events. No personal telemetry or network service is required. Capture reproducible bug fixtures from locally stored state.

## 25. MVP vertical slice and explicit exclusions

### Required experience

The player leaves a crack retreat, notices a fly on the planter, reaches it via at least two possible routes, attempts a hunt, can recover from a miss using silk, feeds after a successful capture, notices a mild environmental disturbance, and returns to rest. Save/load and accessibility settings work in this loop.

P0 contains:

- One authored windowsill habitat plus two small technical test scenes.
- One playable spider rig; walking, broad wall/underside traversal, preparing, jumping, landing, hanging, reeling.
- Comfortable camera and remappable keyboard/controller actions.
- Motion cues and forward inspection with occlusion.
- One fly archetype, 3–6 instances, perches, threat response, capture, and feeding.
- One retreat, simple energy/rest, one telegraphed harmless disturbance.
- Save/load, restart, fixed seed, debug overlays, basic audio/visual cues, and a short tutorial flow.

P0 deliberately excludes breeding, eggs, molts, limb loss, full weather, seasons, full humans, predators with complete AI, freeform silk construction, procedural levels, genetics, multiple habitats, multiplayer, achievements, mod APIs, localization production, and high-end rendering effects. Reserve simple extension points, not placeholder implementations for each feature.

### Proposed acceptance gates

These gates are targets to test, not claims about an existing build.

| ID | Acceptance criterion |
|---|---|
| M01 | Complete a route across floor, wall, convex edge, and broad underside 20 times without lost support, collision penetration, or forced camera roll. |
| M02 | For 100 legal static-surface jumps spanning reach/height combinations, planned and actual landing centers differ by ≤0.25 reference body lengths in calm conditions. Invalid candidates show invalid feedback. |
| M03 | Tether catches recoverable misses in ten fixtures; reeling reaches a valid surface or reports blockage without clipping, endless oscillation, or added energy. |
| M04 | Camera avoids opaque terrain and permits aiming at all required slice jumps at 30/60/144 render FPS. |
| P01 | Hidden prey does not update a classified observation; turning toward a visible cue improves classification after the configured inspection period. |
| A01 | A fly flees based on sensed evidence, not jump-button state; its debug trace explains each transition. Capture triggers once. |
| L01 | Feeding increases energy only while valid; canceling or saving/loading cannot duplicate prey or consumption. |
| S01 | Save/load from supported, airborne, hanging, feeding, and resting states preserves required world state and references; continuation stays within defined numerical tolerance. |
| S02 | A truncated/corrupt save leaves the previous valid save available; unsupported schema produces a useful error. |
| U01 | The loop can be completed using controller only, remapped keys, toggle preparation, and with audio muted. Settings survive restart. |
| W01 | Disturbance changes a visible local condition and gives a usable warning; pause stops it and all dependent simulation. |
| F01 | Five-minute representative run meets the nominated frame-time budget or reports measured misses and a concrete reduction plan. |
| E01 | In an initial five-person informal playtest, at least four reach a first intended landing and understand silk recovery within ten minutes with in-game guidance. |
| E02 | Players can describe why a hunt succeeded or failed; observe whether they voluntarily pause to look around. Record findings instead of manufacturing a pass rate. |

Engineering gates M01–M04 precede ecosystem work. An enjoyable hunt cannot compensate for unreliable aiming. If a gate is blocked, retain a working simpler version and explain the tradeoff in the handback.

## 26. Phased roadmap and first coding tasks

### Roadmap by evidence, not calendar promises

| Phase | Output | Exit condition | Defer/cut if struggling |
|---|---|---|---|
| 0: Foundation | Runnable project, pinned toolchain, input map, graybox labs. | Fresh checkout imports and starts with documented steps. | Fancy assets and optional plugins. |
| 1: Body and camera | Support motor, jump solver, camera, tether recovery. | M01–M04 pass or narrowly documented remaining issues. | Narrow branches and moving surfaces. |
| 2: First hunt | Perception, fly states, capture and feeding. | P01, A01, L01; hunt has readable cause/effect. | Additional prey, combat, elaborate sensory shaders. |
| 3: Complete slice | Habitat, retreat, disturbance, UI, save/load, accessibility. | P0 gates and a packaged desktop demo. | Dynamic weather and visual polish beyond legibility. |
| 4: One finite life | Needs, growth/molting, one predator, meaningful death/continuation. | A full life works without grind or mandatory breeding. | Injury detail and freeform building. |
| 5: Persistent habitat | Courtship, offspring, bounded inheritance, seasonal changes. | Continuation preserves place and distinguishes player knowledge from animal memory. | Population evolution until it produces worthwhile decisions. |
| 6: Broader world | Additional adjacent habitat, humans, ecological breadth, production art. | Each addition changes decisions and meets performance/quality gates. | Full property scale and procedural expansion. |

Phases 4–6 are a direction, not a production commitment. Re-estimate after each handback. No reliable schedule or staffing estimate can be inferred from a specification alone.

### First coding tasks, in execution order

**T00 — Inspect and establish the build.** Read existing project guidance, list relevant files, identify whether an engine project exists, and preserve current work. For a greenfield project, create `prototype/`, pin Godot/toolchain settings, create a main scene and traversal lab, and write exact launch instructions. Add a script-based test runner with nonzero exit on assertion failure; no third-party test framework is required initially. Definition of done: clean import and launch, no missing resources, documented version.

**T01 — Create the input and camera shell.** Add named actions from section 17, a placeholder spider, camera collision, stable horizon, sensitivity, recenter, pause, and settings persistence. Definition of done: keyboard and controller can traverse the test floor; camera never starts inside geometry. Do not solve all wall behavior in the camera code.

**T02 — Implement supported locomotion.** Add tangent-frame movement, support probing, explicit attachment state, edge transition rules, and material eligibility. Build floor, ramp, wall, convex corner, concave corner, underside, and gap fixtures. Definition of done: M01 route works with visualized support normals; unsupported gaps cause falling, not adhesion across empty space.

**T03 — Implement the shared jump solver.** Add prepare/cancel/commit, duration selection, launch constraints, shape-swept candidate validation, and landing classification. Draw optional predicted and actual trajectories. Definition of done: M02 fixture runner reports landing error; unreachable targets remain unreachable with honest feedback. No prey-specific auto-aim yet.

**T04 — Add one safety tether.** Add local-surface anchor, payout, taut constraint, hanging, reel/lower/release, collision-safe recovery, and anchor invalidation. Definition of done: M03 tests pass and a player can deliberately miss, recover, and retry. Use a simple line renderer.

**T05 — Package the first handback.** Produce a runnable movement build or documented editor launch, short traversal recording if capture tools are available, test report, and known issues. Include one paragraph on how movement feels and where it violates the intended fantasy. Do not report a recording or manual playtest that was not actually performed. This is the preferred first review boundary.

**T06 — Add evidence-driven perception.** Implement observation records, peripheral cue, inspected classification, visibility checks, expiry, and debug cones. Definition of done: P01 passes, camera orbit does not grant body-facing inspection, and hidden targets do not leak coordinates to the HUD.

**T07 — Add one prey brain and capture path.** Build perch graph, goal scores, fly execution states, delays, sweeps, capture ownership, interruptible feeding, and energy accounting. Definition of done: A01 and L01 pass; debug output explains detection and escape. Introduce no second prey type.

**T08 — Compose the windowsill loop.** Replace lab arrangement with the authored habitat, two routes, retreat interaction, onboarding prompts, ambient cues, and one nonlethal disturbance. Definition of done: the described 10–15 minute experience is possible and replayable; quiet observation does not trigger constant need alarms.

**T09 — Complete persistence and accessibility.** Build validated snapshot/restore, safe replacement and backup, remapping UI, toggle interactions, reduced-effects settings, cue alternatives, and assisted play presets. Definition of done: S01, S02, U01, W01 pass. Persistence data ownership should already have been respected in prior tasks; do not retrofit node-path IDs here.

**T10 — Profile, test, and hand back the slice.** Run the regression fixtures, benchmark the nominated scene, perform or request actual playtests, fix high-impact problems, package the build, and update documentation. Definition of done: every P0 gate is marked passed/failed/not run with evidence and a reproducible setup. Do not conceal missing human tests behind automated passes.

### If limited to one implementation session

Complete T00–T03 as far as verifiable, preserve a runnable project, and stop with a specific handback. If time permits, T04 creates the first distinctive spider experience. Do not spread effort across genetics, seasons, and decorative menus while the first jump remains unreliable.

## 27. Testing strategy and handback protocol

### Automated checks that matter

- **Numerical unit tests:** jump solution reaches a specified point under the same integrator; unreachable inputs are rejected; support basis remains orthonormal; tether never pushes when slack; values remain finite.
- **Behavior integration tests:** approach behind opaque cover does not trigger visual detection; perceived threat triggers delayed escape; a captured prey cannot be captured or consumed twice.
- **Persistence tests:** round-trip all supported states; corrupted/truncated files; missing IDs; migration fixture; unavailable surface; restoration of RNG/event order without duplicated scheduled consequences.
- **Temporal tests:** pause, slow time, a frame stall, repeated loading, and different render rates do not produce extra input actions or resource drain.
- **Stress tests:** actor budget, repeated jump/recovery cycles, save/load loops, and a 20-minute soak expose leaks and state deadlocks.

Use pure-function tests for math and engine-driven fixtures for actual collision behavior. A formula test cannot prove a wall controller is stable. Set reasonable tolerances and save failing seeds. Avoid tests that simply restate a constant without protecting behavior.

### Manual verification

Check wall/ceiling camera comfort, target readability on varied materials, input conflicts, controller-only menus, sound-off cues, scaled text, and reduced-motion settings. Record what was tested and what was unavailable. Human playtest feedback should separate “I could not execute this” from “I did not understand why this happened.”

Ask players afterward: What did you notice first? Why did the fly flee? What did the line do? Where felt safe? Did you want to investigate anything without a reward? Their answers test the pillars more directly than a generic fun rating.

### Required handback to Chet

Deliver code/project files, exact engine version, startup instructions, and a build if the environment supports export. Keep a completed `docs/HANDOFF.md` with:

```markdown
# Jumping Spider Sim — Implementation handback

## Build and scope
- Commit or source snapshot identifier:
- Engine / renderer / physics backend:
- Entry scene and exact launch/export steps:
- Implemented task IDs:
- Explicitly deferred features:

## What works
- Player-visible behaviors, not just files created:

## Verification
- Test command, fixture, result, and environment:
- P0 gate status: passed / failed / not run:
- Manual testing and captures actually performed:
- Measured performance, hardware, and scene:

## Known problems
- Severity, reproduction steps, seed/save, expected and actual behavior:

## Decisions and deviations
- What changed from the specification, why, and how reversible it is:
- Biological abstractions or unverified assumptions introduced:

## Next review
- Three highest-value questions for Chet:
- Three proposed next implementation tasks:
```

Chet's review should evaluate movement feel, observation, fairness, stillness, and attachment to place before expanding the feature list. A functioning implementation that feels like an ordinary platformer needs design iteration, not more content.

Claude may make ordinary implementation decisions within these guardrails and should record them. Escalate scope-changing choices—mandatory permadeath, engine migration after established work, online services, major biological departures, or a different core camera—through a concrete proposal. Do not block the first prototype on optional art or future life-cycle questions.

## 28. Open questions, provisional answers, and sources

### Decisions that remain open

| Question | Provisional answer | Revisit when |
|---|---|---|
| Is *P. audax* the final species? | Yes as an anchor; explicitly approximate in prototype. | Before P1 lifecycle and courtship. |
| How much physical realism should jumping retain? | Tuned ballistic readability with clearly documented abstraction. | After movement playtests, compared with biological reference footage. |
| Does broad wall/underside traversal create too much camera complexity? | Required on broad surfaces; restrict geometry if necessary. | Phase 1 gate. |
| How literal should perception look? | Ordinary readable image plus evidence-limited cues. | First hunt playtests; avoid unreadable visual gimmicks. |
| Should a whole life take an hour or several sessions? | No commitment yet; prioritize the short slice. | Once rest, molting, and repetition can be evaluated. |
| How important is intentional silk swinging? | Recovery only initially; not a traversal superpower. | Only if an interesting, plausible mechanic emerges. |
| Is reproduction central or optional? | Optional; non-descendant continuation always available. | First finite-life playtest. |
| How much inheritance affects movement? | Mild bounded variation with tradeoffs. | P2 and after baseline controls are stable. |
| Is winter playable or summarized? | Species-dependent, likely a mix of refuge and time skip. | Region/species research and seasonal prototype. |
| How harsh should humans be? | Nonlethal in P0; later readable hazards with generous settings. | After fair warning and escape routes are proven. |
| Is procedural world generation valuable? | No for initial habitat; author topology, vary events. | Only if replayability lacks variety after systemic tuning. |
| What is the production budget/team? | Unknown; do not infer a commercial-scale scope. | Before committing to phases 4–6. |

None of these blocks T00–T05. The first prototype should generate evidence that helps answer them.

### Source notes and research trail

Sources were consulted during preparation on October 4–5, 2026. Stable documentation URLs can change; pin version-specific equivalents during implementation. This is a selective grounding pass, not a comprehensive scientific review. The detailed mechanics, architecture, numeric tuning, and budgets are original design proposals.

- **B1 — Visual division of labor and species variation:** [Spatial acuity-sensitivity trade-off in the principal eyes of a jumping spider](https://pubmed.ncbi.nlm.nih.gov/33885956/). Primary research on *Cyrba algerina*; useful for distinguishing eye functions, not for assigning exact *P. audax* sensory parameters.
- **B2 — Looming behavior:** [Secondary eyes mediate the response to looming objects in jumping spiders (*Phidippus audax*)](https://pmc.ncbi.nlm.nih.gov/articles/PMC3497142/). Primary research informing the approaching-threat cue. Does not validate the proposed UI or its angular settings.
- **B3 — Dragline mechanics:** [More than a safety line: jump-stabilizing silk of salticids](https://pmc.ncbi.nlm.nih.gov/articles/PMC3758018/). Primary research on *Hasarius adansoni*. Supports the conceptual role of silk; the game's tether controller is intentionally simpler.
- **B4 — Species baseline:** [University of Michigan BioKIDS: *Phidippus audax*](https://www.biokids.umich.edu/critters/Phidippus_audax/). Institutional species synthesis for habitat and seasonal life-history context. Validate implementation-critical details against its underlying literature and regional data.
- **E1 — Motion body API:** [Godot CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html). Use for API behavior; arbitrary-surface attachment remains custom work.
- **E2 — Fixed-step presentation:** [Godot physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/using_physics_interpolation.html). Relevant to transform timing and teleport resets.
- **E3 — Serialization baseline:** [Godot Saving games](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html). Use as API context, not a complete transactional save design.
- **E4 — Renderer selection:** [Godot overview of renderers](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html). Check feature needs against the pinned engine and target hardware.

Maintain `BIOLOGY_LEDGER.md` as implementation proceeds. Each new realism claim should identify the species, supporting observation, uncertainty, and gameplay translation. Prefer a documented abstraction over an impressive but unsupported claim.

---

**The first success is modest and specific:** a player stops, sees a possibility, makes a jump, survives a mistake, and wants to look again. Everything larger should grow from that.
