# Living habitat work in progress

User direction: dense, small areas like the original windowsill. Every area should feel enormous to a spider because of its connected surfaces, shelter, life and detail. It Takes Two is a reference for the variety and pacing of spaces. Do not interpret this as a request for more square metres or a particle carpet.

## Required layout change

- Discovery is deliberate: let readable creature behavior and environmental cues teach the player. Run is a surprise: no button or control reference before the first completed moult. At completion, explain the newly acquired ability with a brief device-specific control notice. Its availability is derived from growth stage; softness still slows movement. This supersedes the earlier no-announcement interpretation.
- New opening challenge: the male rival and wasp are resident station patrols from day one. Ground/furniture/ceiling surface routes connect all 51 station regions; the 368 collision parts stay persistent so residents can navigate away from the player's immediate neighbourhood. The wasp uses swept air routes through the doorway between rooms. Retreat protection and existing sight/attack tells remain. A defeated rival gets an out-of-sight replacement only after a minute; defeating it still buys time. Native end-to-end hunting/escape review remains required; this is not shipped.
- First moult requires seven whole-fly equivalents; second requires ten, in every game mode. Later requirements remain unchanged. Small prey retain proportional food credit. Saved instar determines the threshold; meals already eaten remain credited and a previously ready moult is not revoked merely by applying current game rules.
- Lock-on unlocks after the second completed moult. Until then L1/LB only creeps, keyboard Recentre still recentres, and neither the touch button nor help card previews lock-on. At completion, show the device-specific lock/strafe explanation. Existing line-of-sight and perception-memory restrictions still apply.
- Aim remains manual before acquiring lock-on. After the second moult, choosing a lock also directs jump aim toward that perceived contact. This supersedes the briefly proposed removal of assisted aiming while locked.
- Active preserve HUD: a stable, small 120-by-4-pixel hunger reserve with no label, numbers or words. No crosshair, landing trajectory, target markers, grip/courtship meter, day/stage text, automatic control card, prompts, captions or routine toasts. Only the explicitly requested earned Run/lock-on notices appear briefly. Deliberately opened menus/control references and usable touch controls remain available; desktop/controller gameplay has no menu/notebook buttons. The frozen test garden retains its reference presentation for regression comparisons.

- Build around compact, distinct habitat pockets: window and desk, floor beneath furniture, garden immediately below the window, litter and flower stems, bench and can, pond margin.
- Target an initial pocket approximately 80–150 cm across, adjusted for the real sizes of its plants and props. This is an authoring target, not a performance guarantee.
- Bring worthwhile surfaces and discoveries within a few ordinary jumps. Avoid long runs on flat ground. Provide overlapping overhead cover, climbable layers, quiet observation perches and short alternate routes.
- Shorten the existing garden-to-meadow and especially meadow-to-pond journeys. Adding ground to the current long corridors is a safety repair, not completion of the layout change.
- Preserve the spider's body scale, enjoyable jump range and controls. Move/recompose habitats instead of shrinking the animal or making sprint speed hide empty design.
- When relocating existing geometry, migrate saved positions deliberately and update map revision/checkpoint handling. Earlier preference for retaining coordinates is superseded where necessary by the user's explicit request to condense the environment.

## Current implementation, unpublished

Working branch: `codex/v48-living-habitat`, based on v47 receipt commit `9d442ff`. Live place remains version 61; no v48 publication has occurred.

- `Verge.luau` adds small persistent ground supports beside developed paths. It subtracts existing ground-region footprints to preserve the pond and drain hazards. This fixes actual scenery-without-collision gaps outside the stone path.
- Other region collision groups become atomic models so prey readiness does not depend on partially replicated folders.
- Ground cover and actual existing prey species are being placed along paths and in the infill. Their flight bands must stay at the outdoor ground level, not the sill's zero height. Validate each population starts with real creatures on valid surfaces.
- `Environment`, `LivingWorld` and `LivedInSites` are prototypes for deterministic weather/solar calculations, pooled close detail and animals, hollow cans and an anthill. These need actual Roblox rendering and performance review. The astronomical model is converted to Roblox native sky controls. A direct native comparison at 28 times across four seasons had a maximum direction error of 0.028 degrees. Window shafts follow the sun and only appear when it can shine into the window.

## Evidence and remaining gates

- Earlier local checks: living habitat 1,228/0 after ground clipping; client smoke 26/0; world client 30/0. These are bounded CLI checks, not published playtests.
- First expanded preserve regression: 1,134 passed, 10 failed. Failures included obsolete exact region/population counts, new prop budgets, invalid insect starting perches and overlapping can shell panels. Fixes are in progress; retain the raw failure log.
- Current targeted results: living habitat 1,307/0 and preserve 1,144/0. The preserve test still pins the original 34 populations separately from new route and pocket populations, and checks every new perch and every population starts successfully.
- Native path-shoulder check: spider attached to real support, region ready, five insects across two directors; 16.88 ms mean frame time over 238 frames. Initial pocket: attached, three hoverflies, 17.01 ms mean over 236 frames. Revised pocket: 20.62 ms over 196 frames with one 656 ms spike; this is not evidence of a steady performance target. All were Studio diagnostic placements, not an end-to-end player traversal or a published playtest.
- First compact pocket: `GardenPocket.luau`, approximately one square metre beneath the window, three juvenile climbable plants, low stems, leaf shelter, clover flowers and hoverflies. Structural leaf meshes survive low detail. Source density checks bound distance to a climbable feature; the wider landscape still needs recomposition.
- Frozen full CLI completed against snapshot `C:\Users\natha\claude-xfer\v48-validation-7fa8067f3048d6fd`; raw output `C:\Users\natha\claude-xfer\v48-full-cli-7fa8067f3048d6fd.txt`; exit 1. The preserve self-test suite had 2 passes and 5 failures: its stale exact-207-region assertion and a ten-minute simulated-play cap aborted the longer 385-region tour, leaving later save/window/shadow checks unfinished. This is not a green release gate. Later source also changes growth, resident predators and HUD, so the frozen result does not validate those changes.
- Studio is stopped; Rojo server handle 15435 is connected on port 34872. A temporary `Client/SilkPlayback` review module is still installed in Studio only. Its source is archived in this folder; it MUST be removed before publishing. No review driver is part of the source project. Saves are disabled in the Studio review; do not enable API access just for the fixture.
- Still required: finish regression/type/compile checks, implement and verify compact layout, inspect native travel and ground coverage, inspect close detail/animal grounding, benchmark both detail tiers, then build/publish/synchronize a verified release.
- Do not claim the habitat is rich or the falls fixed in the live game based on isolated fixtures or CLI checks. User report of no outdoor insects is a player-experience failure until normal travel visibly encounters them.

### Resident/HUD work, later than the frozen run

- Native Studio review: stage 0, goal 7 meals, zero visible gameplay TextLabels; the rival patrolled the station floor and the wasp searched the desk. The review uses a protected resting spider and a Studio-only driver, so it does not prove ordinary hunt/escape feel or published behavior.
- The first native sample exposed a 1,449 ms stall when air navigation built synchronously. Navigation now warms in batches of eight work units, never exposing a partial route. A later five-second sample had 150 frames, 33.50 ms mean and 95.87 ms worst. The large build stall is absent in that sample, but this is not a passing final performance benchmark.
- CLI station checks: all 51 regions reachable in the surface graph; all 16 air patrol stops fit and have clear connecting routes; a three-minute resident wasp run visits 14 stops without crossing walls or leaving while the player shelters. Hunger-only renderer checks cover the absence of labels, reticle, other meters and routine notices, plus the two earned ability notices and explicitly opened controls.
- Legacy wasp 16,884/0, rival 2,843/0 and outdoor navigation 581/0 passed. An initial world-client regression hit a missing `task.wait` in the CLI's synchronous task stub; that stub was corrected and a current world-client rerun is pending in `C:\Users\natha\claude-xfer\v48-world-client-current.txt` (handle 13350). Current strict type analysis is clean. Compile and final broader regression receipts still need refreshing after source stabilizes.
- The preserve self-test's old outdoor-rival expectation and its acquired-lock fixture also need updating for the new station residency and second-moult lock. Do not weaken physics, retreat, save or streaming checks to make the release green.

## Platform judgment

Roblox limits density, draw calls, memory and simulation cost, especially on phones. The current barren travel and missing ground are implementation/design problems. Compact, authored habitats with reused meshes, bounded active wildlife and selective detail remain a viable direction. No engine migration is needed to address these reported problems.

Primary performance reference: https://create.roblox.com/docs/performance-optimization/improve
