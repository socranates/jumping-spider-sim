# Wasp + sound integration — Chet, 2026-10-16

Imported Nathan's `claude-playtest/claude-next.bundle`, verified a483d65 on main b5e78c9. Combined with sound branch 4510dcf (already includes LIFE 6af95a9). Preserved both client paths and test sets; rebuilt generated places. Evidence **52123df9177323c8**. See ROBLOX-28 for audio design.

## Completed

- Wasp director, drawing, capture/recovery, checkpoint state and PlayStation prompt names imported.
- Existing original room/birds/fly audio preserved. New wasp asset authorized for universe 10771103250; initial warning cannot be lost to camera-distance attenuation, then becomes positional on the sill. Pauses under menu/catch screen; stops while walking or away. Captions unchanged.
- New CLI coverage checks transport during arrival, menu, mute, slow motion, walking, departure and the actual client's capture path.
- Native client playback now forces a safe wasp visit, checks asset loading, measures frame p50/p95 without screenshots and verifies the hum stops. Report collector retains PORT_WASP_COST as wasp-cost.json.
- Strict src type check clean. All 118 Luau files under src/tests compile. Full CLI output in docs/verification/roblox-wasp-windows/cli.txt.
- Added missing UID sidecars to the ignored Roblox reference-export Godot scripts. Ordinary Godot import skips roblox_port/.gdignore; generated IDs with Godot ResourceUID. No frozen gameplay source changed.

## Windows acceptance — completed

Nathan ran **Downloads/Windowsill-Wasp-Test-52123df9.rbxlx** in Studio. Extracted structured reports from the 20261016T152709Z Studio log: **80/80 engine, 14/14 client**, zero failures, matching evidence **52123df9177323c8**. Full Windows CLI: **44,610/44,610**. The native WaspSpec passed, and the live client verified the hum loaded, safety in the crack and silence after departure. Wasp sample (467 frames, no screenshots): median **16.96 ms**, p95 **20.91 ms**. Three-/six-fly p95 were **25.10/26.01 ms** in their separate samples. These short samples are not a blanket 60-fps/F01 pass. Reports are under docs/verification/roblox-wasp-windows.

## Remaining manual acceptance / publishing

PlayStation button labels/feel, perceived warning loudness, visual catch-screen acceptance, and wasp clipping/readability still need direct playtest. No physical device claims. Claude's previews are useful shape references, not native rendering evidence. Do not publish TheWindowsillTests.rbxlx. Only the playable TheWindowsill.rbxlx belongs at existing place **120119801868085**. Publication status of the prior sound release remains unverified.

Approved to finish into main after the passing checks above. Update Nathan's laptop clone (use escalation outside sandbox; sandbox git status there misleadingly reports no worktree). Keep claude-playtest as an untracked backup. Preserve the unrelated modified tests place in controls_recovery. Publish the playable build only; native Studio controls are unavailable in this session, so user publication is still required. The current publish-ready copy is Downloads/Windowsill-PUBLISH-Wasp-52123df9.rbxlx.

Next Claude: death/continuing and mode selection; preserve audio/captions. Gemini's peacock-spider art and courtship design is independent exploratory work, not yet implemented.
