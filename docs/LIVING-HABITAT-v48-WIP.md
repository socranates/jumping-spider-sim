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
- Shorten the existing garden-to-meadow and especially meadow-to-pond journeys. This is implemented in source below; native travel and composition still need review.
- Preserve the spider's body scale, enjoyable jump range and controls. Move/recompose habitats instead of shrinking the animal or making sprint speed hide empty design.
- When relocating existing geometry, migrate saved positions deliberately and update map revision/checkpoint handling. Earlier preference for retaining coordinates is superseded where necessary by the user's explicit request to condense the environment.

## Current implementation, unpublished

Working branch: `codex/v48-living-habitat`, based on v47 receipt commit `9d442ff`. Live place remains version 61; no v48 publication has occurred.

- `Verge.luau` adds small persistent ground supports beside developed paths. It subtracts existing ground-region footprints to preserve the pond and drain hazards. This fixes actual scenery-without-collision gaps outside the stone path.
- Other region collision groups become atomic models so prey readiness does not depend on partially replicated folders.
- Ground cover and actual existing prey species are being placed along paths and in the infill. Their flight bands must stay at the outdoor ground level, not the sill's zero height. Validate each population starts with real creatures on valid surfaces.
- `Environment`, `LivingWorld` and `LivedInSites` are prototypes for deterministic weather/solar calculations, pooled close detail and animals, hollow cans and an anthill. These need actual Roblox rendering and performance review. The astronomical model is converted to Roblox native sky controls. A direct native comparison at 28 times across four seasons had a maximum direction error of 0.028 degrees. Window shafts follow the sun and only appear when it can shine into the window.

### Compact preserve revision 3

- Garden-to-meadow path: 400 cm to 100 cm, still 60 cm wide. The meadow and bench move 300 cm closer to the garden; their plants, furniture, creature scale and jump physics retain their dimensions.
- Pond approach: 2,911 cm to 286 cm. Two 100 cm eastward cells and one 86 cm northward cell connect the gravel to the boardwalk. Pond geometry moves 1,300 cm west and 1,625 cm south. All 16 boardwalk cells and the water-margin habitat remain.
- The resulting map has 232 regions: 181 authored habitats/routes plus 51 collision-backed infill cells, formerly 385 with the extended routes. The short connector, bench, pond, robin forage and backdrop share the new coordinates.
- All coarse grass/meadow floors exclude the relocated pond. The backdrop boardwalk stops at its real collision extent; its unsupported far continuation, posts and dipping platform were removed. Ground infill does not cover the water, drains or authored boardwalk banks.
- `CompactMigration` recognizes only preserve-2 saves with the current seed. It validates old objects before relocation, translates spatial points in moved regional ecology, retains shared feeding identity, and rebuilds retired route populations on demand. Exact supported player/refuge poses survive rigid habitat moves. Reshaped route saves use their mapped region's safe spawn. Other revision mismatches retain existing fallback behavior.
- Migration fixtures are actual saves generated by frozen pre-compaction source `7fa8067f3048d6fd`, including bench/pond/sill refuges, old route flies and an ant colony. Source records remain untouched; malformed objects in a retired route are refused before pruning, leaving the live world unchanged.

### Close ground habitat pass

- Added 98 small leaf/bark shelters in 49 of the existing infill regions, with 388 collision pieces. Roofs have real cover and walkable tops, clear passages beneath, nearby fallen stems where space permits, and seeded variations in size, curl and colour. They reuse the existing approved leaf/bark meshes. No new regions or movement constants are introduced; spawns remain clear.
- Clover islands now fit the actual soil fragments after subtraction, rather than spreading into excluded areas inside a region's larger rectangle. Structural shelter rendering remains available at low detail. Global look budgets stay 1,500/500.
- Final checks: litter 4,875/0, compact saves/layout 294/0, living world 1,799/0, preserve 1,148/0, clean strict analysis and 204/204 compile. Native full-detail input walks into the shelter and stays attached; approach mean 16.78 ms, under-roof mean 21.67 ms. A later profiled rival update spikes to 356.8 ms, so performance remains unready. See `docs/verification/v48/LITTER-REVIEW.md` and its archived graph benchmark for the next performance pass.
- The Studio driver and detail override were removed at 2026-10-21T16:46:38Z; Studio is stopped. Final low-tier mesh inspection, ordinary travel, broader wildlife/prop review and complete release validation remain required.

## Evidence and remaining gates

- Earlier local checks: living habitat 1,228/0 after ground clipping; client smoke 26/0; world client 30/0. These are bounded CLI checks, not published playtests.
- First expanded preserve regression: 1,134 passed, 10 failed. Failures included obsolete exact region/population counts, new prop budgets, invalid insect starting perches and overlapping can shell panels. Fixes are in progress; retain the raw failure log.
- Current targeted results: living habitat 1,307/0 and preserve 1,144/0. The preserve test still pins the original 34 populations separately from new route and pocket populations, and checks every new perch and every population starts successfully.
- Native path-shoulder check: spider attached to real support, region ready, five insects across two directors; 16.88 ms mean frame time over 238 frames. Initial pocket: attached, three hoverflies, 17.01 ms mean over 236 frames. Revised pocket: 20.62 ms over 196 frames with one 656 ms spike; this is not evidence of a steady performance target. All were Studio diagnostic placements, not an end-to-end player traversal or a published playtest.
- First compact pocket: `GardenPocket.luau`, approximately one square metre beneath the window, three juvenile climbable plants, low stems, leaf shelter, clover flowers and hoverflies. Structural leaf meshes survive low detail. Source density checks bound distance to a climbable feature. Wider layout compaction is implemented above; its native composition is unverified.
- Frozen full CLI completed against snapshot `C:\Users\natha\claude-xfer\v48-validation-7fa8067f3048d6fd`; raw output `C:\Users\natha\claude-xfer\v48-full-cli-7fa8067f3048d6fd.txt`; exit 1. The preserve self-test suite had 2 passes and 5 failures: its stale exact-207-region assertion and a ten-minute simulated-play cap aborted the longer 385-region tour, leaving later save/window/shadow checks unfinished. This is not a green release gate. Later source also changes growth, resident predators and HUD, so the frozen result does not validate those changes.
- Studio is stopped; Rojo is connected on port 34872. The temporary `Client/SilkPlayback` review module was removed and its absence asserted at 2026-10-21T16:28:08Z. Its source remains archived in the verification folder; no review driver is part of the production project. Recheck before publishing. Saves are disabled in Studio review; do not enable API access just for the fixture.
- Current compact checks: 294/0 layout/save migration, 545/0 checkpoint, 1,148/0 preserve, 30/0 world-client, 32/0 minimal HUD, and earlier 1,799/0 living-world checks against the compact geometry. The preserve test now counts density instead of rewarding the removed route cells, checks the supported backdrop extent and all grass/meadow floors over the pond, and tests distance-based ballooning odds for the nearby pond. See `docs/verification/v48/COMPACT-REVIEW.md` for exact scope and raw output. These are not published evidence.
- Current-source native shoulder diagnostic: attached to actual ground at `(100,-84.29,-550)`, three live prey within 30 cm, 298 frames over five seconds, 16.82 ms mean / 33.44 ms worst. The initial Studio run had old startup perches because Rojo had disconnected; the connection was explicitly restored before this check. This still does not prove ordinary traversal or visible encounters.
- Still required: finish current regression/compile checks, inspect native compact travel and ground coverage, inspect close detail/animal grounding, benchmark both detail tiers, then build/publish/synchronize a verified release. A refreshed strict analysis completed with no diagnostics after compaction.
- Do not claim the habitat is rich or the falls fixed in the live game based on isolated fixtures or CLI checks. User report of no outdoor insects is a player-experience failure until normal travel visibly encounters them.

### Dog motion and outdoor presence follow-up

- The dog now uses planted paws and articulated legs, settles its feet on stops, turns during sniff pauses, lowers its nose toward the ground and wags from the tail base. Its body updates each rendered frame; other close detail retains the bounded 20 Hz update. No new dog parts or player colliders are added.
- Rain brings it to a reached sniff stop near the hut along its existing circuit, then it resumes when rain eases. The former straight-line shortcut through scenery is gone. The compact northern-lawn route clears both actual raised beds and the far garden's decorative planters. Authored terrain supplies visual support when native ground is not streamed; unknown ground remains unsupported.
- Dog gait 29,959/0; living world 3,438/0; clean strict analysis; 206/206 source compile. Final V4 native sample: 1,735 frames, mean 17.30 ms, worst 49.33 ms; dog rendered throughout, no measured stance-paw slide or foot gap. Normal spider view and diagnostic close-ups were inspected. See `docs/verification/v48/DOG-REVIEW.md`; this is not a published build or complete performance gate.

### Incremental station navigation follow-up

- Surface route preparation now runs privately across frames, with atomic publication of completed graphs and explicit readiness for the rival's drive. The 51 station graph fingerprints match the archived pre-change baseline. Cold crossings retain their seeded patrol choice while waiting; station territory and movement rules remain intact.
- Targeted regression results: route preparation 11,067/0, rival 2,843/0, rival navigation 581/0, station threats 32,883/0, world client 30/0; strict analysis clean, 204/204 source files compile.
- Uncontended native station repeat: all 51 jobs complete by the 20-second report, no errors, rival travels 52.52 cm. Rival profile mean/worst 0.17/1.3 ms; frames after ten seconds average 19.55 ms, worst 61.57 ms. Startup-inclusive worst remains 1,005 ms. The cooperative 2 ms route budget can overrun (4 ms measured), and this is not a universal performance claim. See `docs/verification/v48/ROUTE-REVIEW.md` for evidence and remaining gates.

### Resident/HUD work, later than the frozen run

- Native Studio review: stage 0, goal 7 meals, zero visible gameplay TextLabels; the rival patrolled the station floor and the wasp searched the desk. The review uses a protected resting spider and a Studio-only driver, so it does not prove ordinary hunt/escape feel or published behavior.
- The first native sample exposed a 1,449 ms stall when air navigation built synchronously. Navigation now warms in batches of eight work units, never exposing a partial route. A later five-second sample had 150 frames, 33.50 ms mean and 95.87 ms worst. The large build stall is absent in that sample, but this is not a passing final performance benchmark.
- CLI station checks: all 51 regions reachable in the surface graph; all 16 air patrol stops fit and have clear connecting routes; a three-minute resident wasp run visits 14 stops without crossing walls or leaving while the player shelters. Hunger-only renderer checks cover the absence of labels, reticle, other meters and routine notices, plus the two earned ability notices and explicitly opened controls.
- Legacy wasp 16,884/0, rival 2,843/0 and outdoor navigation 581/0 passed. A world-client regression queried `map.world()` on a stub without that function; the client now uses its stable `world` identifier and the rerun passes 30/0. The task stub also supports `wait` for batched air-grid warmup. Current compile is 204/204 and strict analysis has no diagnostics. A final frozen full CLI run remains required.
- The preserve self-test now expects a station resident rival and garden mate, explicitly sets up and restores an acquired-lock stage outside the ranger's morning, and walks the relocated meadow/pond connections. After repairing its two old fixture assumptions, the replacement completed in 545 simulated seconds with **270 pass / 0 fail / 0 skip**; all seven outer checks pass, including save/window/shadow checks. Raw output is `docs/verification/v48/compact-selftest.txt`. These are shim results, not native Studio performance or a published playtest.

### Ground cover and nearby prey follow-up

- Soil now has small stemmed clover and curved grass clumps, with a bounded close layer that sways from rooted pivots. The regional background scatter spans each soil cell; low detail retains fewer instances of the same plants. Structural litter roofs no longer move away from their colliders in the decorative wind path.
- New verge populations start with six springtails and four houseflies at full detail, three of each at low detail, spread across all three rows. Perch identities/positions and saved director state remain stable. Escape, capture and feeding code are unchanged.
- Targeted checks: litter 11,258/0, living detail 3,630/0, compact layout/save 294/0. Native ordinary-camera 25 cm walks stayed attached and visibly approached a fly at both tiers. Walking frame mean/worst: full 17.95/49.84 ms; low 16.98/59.18 ms. An unattributed 265.76 ms low-detail arrival hitch keeps performance verification open. See `docs/verification/v48/GROUND-COVER-REVIEW.md`.
- Remaining review includes can geometry, indoor dust/fleas, ants and emerging grubs, weather continuity, broader ordinary traversal and low-detail density, then a frozen full regression/native gate and release. No v48 publication claim is made.

### Indoor prop and floor continuity follow-up

- Both discarded cans now expose aluminium lids, rolled edges and hollow pull tabs within the existing thirty-record allowance. Their climbable shells, apertures and support identities stay unchanged. Native frontal and oblique inspection confirms the drinking opening remains visible; the props retain their faceted shell.
- Dust now uses low overlapping clumps and bent horizontal fibres at the same seven/three part cost. The station doorway shares adjoining floor scatter, fixing dust disappearing during an approach across that region boundary.
- Living-world checks 3,748/0; strict analysis clean; 206/206 compile. Native evidence and explicit limits are in `docs/verification/v48/INTERIOR-REVIEW.md`. Fleas still need a convincing ordinary-play encounter; no v48 release or final performance claim is made.

### Colony and emergence follow-up

- Ambient workers now emerge, forage, carry fragments home and re-enter the nest. The mound is a connected low soil heap with small support steps, grains and an entrance. Nearby region crossings no longer hide its workers. The three support IDs remain; this unreleased prop's heights/inner footprints were refined. Physical/visible height difference is sampled below 0.26 cm.
- Living-world checks 3,842/0, clean strict analysis and 207/207 compile. Native full-detail inspection shows workers and mouth fragments; a normal-camera grub encounter is captured. See `docs/verification/v48/COLONY-REVIEW.md` for scope and limits.
- Frozen 55-suite run on `4a828e0` remains in progress at `C:\Users\natha\claude-xfer\v48-full-4a828e0-results`. It has already found mating-client failures and notebook assertions tied to the old moult threshold. This is not a green release gate; investigate before publishing. The frozen run does not include the later colony source.

### Regression repair follow-up

- Fixed a real courtship integration bug: the mate's reused rival drive was suppressing sight under the very courtship/scene flags meant to protect the pair from the rival. Its private snapshot now omits those two rival-only flags, preserving the caller's state and all retreat/rest/wasp/occlusion restrictions.
- Updated notebook fixtures for the first seven-fly moult. Optimized can and low-tier anthill dressing instead of raising the existing 150-record hut-decoration cap; all three low-tier workers, mouth fragments, can rims and tabs remain.
- Current-source reruns: mating 725/0, real-client mating 29/0, notebook 1,499/0, living world 3,840/0, preserve 1,148/0. Strict analysis clean; 207/207 compile. See `docs/verification/v48/REGRESSION-REVIEW.md`.
- The immutable 4a828e0 run remains active in its preserve self-test and predates the colony/repairs. Finish observing it, address any further failures, then freeze current source for a complete release regression. Native flea/continuity, weather, ordinary traversal and performance reviews still remain; no publication claim.

## Platform judgment

Roblox limits density, draw calls, memory and simulation cost, especially on phones. The current barren travel and missing ground are implementation/design problems. Compact, authored habitats with reused meshes, bounded active wildlife and selective detail remain a viable direction. No engine migration is needed to address these reported problems.

Primary performance reference: https://create.roblox.com/docs/performance-optimization/improve
