# Handoff — Roblox controls, camera and fuzz, 2026-10-14 (Perplexity Computer)

Nathan: "we are only doing roblox now, we need fuzzy spider and the controls are not as good on roblox, when jumping you can only hop, V doesnt change the view etc. They were perfect on the godot version." DECISIONS ROBLOX-04 and ROBLOX-05.

## Why held jumps only hopped

The aim is the screen-centre ray. Roblox's stock Custom camera centres on the spider's body, so that ray went through the body and met the floor just past the feet: every aimed leap was a tiny hop. Godot's rig puts the pivot 0.45 above the spider and lets aiming tilt the view itself. That rig is now ported.

## What changed (roblox_port/)

- **src/Client/SpiderCamera.luau** (new): camera_rig.gd as a Scriptable camera. Orbit by yaw/pitch, never rolls; pivot along the drawn up; sphere-cast boom, instant retract, rate-limited recovery; auto-pitch search when squeezed; aim free-look; recenter (R); body hidden on a short boom; spider-eye view (V/Y) with Godot's eye position, FOV, gaze clamp and roll limit; walking relative to the view or gaze; mouse locked to the centre while playing, freed by the Roblox menu; wheel zoom 2 to 12.
- **src/Shared/Movement/CameraMath.luau** (new): the pure parts (BoomMath, SurfaceInput, aim clamp, gaze clamp/look, recenter yaw), checked against **tests/camera_reference.json**, exported from the frozen Godot code by **tools/export_camera_reference.gd** (+ tools/reference_to_luau.py).
- **src/Client/SpiderClient.client.luau**: JumpController phases (tap hop under 0.15 s; hold aims and holds still; release commits only a reachable plan; Q/B cancels; refusals flash with Godot's titles and reasons) and JumpPlanner (ineligible surface, solve, room at the seat, sphere sweep per tick, first contact within 0.15). Hops are planned like aims. Focus (right mouse/LT) and the eye-view body turn. Slow motion (T/RT, 50 %). HUD: centre dot, focus ticks, aim text, status line, controls card (H).
- **src/Client/SpiderInput.luau, Shared/Movement/InputState.luau**: Godot bindings plus look axes. **R is now recenter, as in Godot; reset moved to Backspace / View.** Touch adds Cancel and Eye buttons and drag-to-look.
- **Fuzz**: src/Shared/Rig/Setae.luau (new, pure layout), Appearances.fuzz (all knobs), SpiderRig (hairs, fur shells, setEyeView, setBodyHidden, low detail). About 640 hair parts plus 4 shells at full detail. The 129-part body is unchanged.
- **tools/preview/**: draws the real rig code in Godot without Roblox (layout check only).

## Verification

See docs/verification/roblox-controls-fuzz/RESULTS.md. Linux pure 63/63, strict type check clean, evidence **db36b09b003a6b8d**. **Nothing here has run in Roblox Studio.**

## Next (Chet, Windows Studio)

1. Run TheWindowsillTests.rbxlx and save the PORT_TEST_REPORT (expect 9 engine checks with completion).
2. Play TheWindowsill.rbxlx: hold Space and look up and down (the patch should turn green on reachable spots and the spider leap on release); V in and out; R; Q during an aim; Focus; T; wheel; Backspace; walls and undersides with the new stick mapping.
3. Check the fuzz in Studio's lighting and the frame time with about 770 rig parts; turn values in Appearances.fuzz down if needed. Measure a tablet before raising its low detail.
4. Then the recommended Claude chunk is still safety silk (ROBLOX_PORT.md).
