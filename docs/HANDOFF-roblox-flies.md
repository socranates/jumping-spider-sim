# Chet → Claude: playable perception and flies — 2026-10-15

Start from updated main. This round imports Claude's perception-2 bundle through 8dd59b6, completes P01, then adds playable flies. Perception milestone d568028 passed separately; final fly evidence is **e3160a3f6e3f2782**. Read verification/roblox-flies/RESULTS.md and ROBLOX-17–19.

## What is playable

The observer and WORLD-only sensor run before movement. The HUD reads observations, never hidden fly identity. Focus, classification, peripheral cues and fixed fading last-seen marks work. The magenta fixture stays in the test place; the playable place omits its stage unless Workspace.TestTarget explicitly enables it.

Shared/Prey contains evidence-only FlySenses, utility-driven Fly, swept/replanned FlyFlight, validated PerchGraph, delayed unseen PreyPopulation, PreyDirector and Feeding. Four flies start on authored perches. They glance, walk in bursts, rest and make planned/spontaneous flights. Replacement flies enter through vents only after two unseen checks, with both Sensor.couldSense and expanded camera coverage considered. Renderer uses 13 anchored, non-query parts per fly and BulkMoveTo.

Only a committed jump opens the swept strike window (240 ticks plus three landing ticks); a wall blocks contact. The jaws report position and size to Sensor:onCapture, never a world ID. Ambiguous contacts are not resolved. One prey may be held; struggle waits for landing, taps keep grip, escape is possible, and a subdued fly is eaten while stationary. Nutrition grants are bounded and recorded. Movement immediately interrupts eating without taking away control.

Controls: Space/A/Grip taps hold prey; E/L3/Eat also grips and resumes a paused meal. F/X/Silk remains lowering. Player.AutomaticGrip enables assistance; Player.FocusToggle enables toggled Focus. There is no settings panel yet.

## Verification and limits

Windows: 7,155 CLI checks, 67/67 native Studio, 11/11 live-client, 82/82 compile, strict analysis clean. Final native six-fly sensor p95 412 us, frame p95 18.15 ms. See saved reports and screenshot. Physical controller/tablet unavailable; not run.

This is a functional behavioral port, not full Godot parity. Godot-seeded input goldens verify math, but Park-Miller replaces Godot's PCG stream. Full grooming/leg animation, fly sound and complete checkpoint state are still absent. Feeding has a basic energy reserve with a 0.2 floor; this does not implement starvation or LIFE. Frozen Godot game code, data and SPEC are unchanged. Preserve the twitch, camera and silk.

## Next Claude: LIFE clock and retreat checkpoints

1. Port the pure LIFE day/night clock and light-dependent range_scale against Godot goldens. Keep fixed simulation time distinct from rendering and slow motion; do not let decorative lighting feed perception.
2. Consolidate Feeding.energy into the ported NeedsModel with explicit mode rules. Preserve the nutrition ledger, clamp and interruption tests; add starvation tests only once death/continuing has an explicit implementation.
3. Add S01-C retreat checkpoints behind a DataStore-shaped in-memory adapter. Snapshot fly RNG streams, timers, reservations, nutrition ledger, observation memory and LIFE state together; validate malformed/versioned data and atomic restore. No publishing or live DataStore writes.
4. Add deterministic round-trip tests first, then hand back to Chet for Studio sleep/day/night/checkpoint and performance verification. Leave the wasp director for the following chunk so LIFE and continuing can define its consequences.

## Nathan's play list

Reopen roblox_port/TheWindowsill.rbxlx in Studio, then Play. Creep toward a fly with Shift, use right mouse to inspect, and watch the cue become fly-like prey. Lose it behind a surface and inspect the old spot. Hop/leap at it, tap Space after landing, then stand still to eat; walk away and press E to resume. Try V and slow motion T during a hunt. Existing silk controls should feel the same. Tell us whether catches and grip feel fair.
