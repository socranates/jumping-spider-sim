# Living habitat work in progress

User direction: dense, small areas like the original windowsill. Every area should feel enormous to a spider because of its connected surfaces, shelter, life and detail. It Takes Two is a reference for the variety and pacing of spaces. Do not interpret this as a request for more square metres or a particle carpet.

## Required layout change

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
- Frozen full CLI is running against snapshot `C:\Users\natha\claude-xfer\v48-validation-7fa8067f3048d6fd`; raw output `C:\Users\natha\claude-xfer\v48-full-cli-7fa8067f3048d6fd.txt`; process handle 59243. It has not finished. Later working-source changes normalize line endings in new modules and rename a shadowed local variable `centre` to `leafCentre`; do not silently label the frozen run as an exact test of later source.
- Studio is stopped; Rojo server handle 15435 is connected on port 34872. A temporary `Client/SilkPlayback` review module is still installed in Studio only. Its source is archived in this folder; it MUST be removed before publishing. No review driver is part of the source project. Saves are disabled in the Studio review; do not enable API access just for the fixture.
- Still required: finish regression/type/compile checks, implement and verify compact layout, inspect native travel and ground coverage, inspect close detail/animal grounding, benchmark both detail tiers, then build/publish/synchronize a verified release.
- Do not claim the habitat is rich or the falls fixed in the live game based on isolated fixtures or CLI checks. User report of no outdoor insects is a player-experience failure until normal travel visibly encounters them.

## Platform judgment

Roblox limits density, draw calls, memory and simulation cost, especially on phones. The current barren travel and missing ground are implementation/design problems. Compact, authored habitats with reused meshes, bounded active wildlife and selective detail remain a viable direction. No engine migration is needed to address these reported problems.

Primary performance reference: https://create.roblox.com/docs/performance-optimization/improve
