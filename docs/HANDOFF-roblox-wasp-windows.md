# Wasp + sound integration — Chet, 2026-10-16

Imported Nathan's `claude-playtest/claude-next.bundle`, verified a483d65 on main b5e78c9. Combined with sound branch 4510dcf (already includes LIFE 6af95a9). Preserved both client paths and test sets; rebuilt generated places. Evidence **52123df9177323c8**. See ROBLOX-28 for audio design.

## Completed

- Wasp director, drawing, capture/recovery, checkpoint state and PlayStation prompt names imported.
- Existing original room/birds/fly audio preserved. New wasp asset authorized for universe 10771103250; initial warning cannot be lost to camera-distance attenuation, then becomes positional on the sill. Pauses under menu/catch screen; stops while walking or away. Captions unchanged.
- New CLI coverage checks transport during arrival, menu, mute, slow motion, walking, departure and the actual client's capture path.
- Native client playback now forces a safe wasp visit, checks asset loading, measures frame p50/p95 without screenshots and verifies the hum stops. Report collector retains PORT_WASP_COST as wasp-cost.json.
- Strict src type check clean. All 118 Luau files under src/tests compile. Full CLI output in docs/verification/roblox-wasp-windows/cli.txt.
- Added missing UID sidecars to the ignored Roblox reference-export Godot scripts. Ordinary Godot import skips roblox_port/.gdignore; generated IDs with Godot ResourceUID. No frozen gameplay source changed.

## Remaining acceptance

Native controls are unavailable to Chet in this session. Nathan has **Downloads/Windowsill-Wasp-Test-52123df9.rbxlx**. Open that file, Play, leave running about two minutes. It exercises the native WaspSpec and live sound load/profile. Inspect the new Studio log, collect reports with tools/collect_studio_report.py, resolve failures before merging main. The real sound-only run was 74/74 engine + 13/13 client; those counts do not validate this wasp build.

PlayStation button labels/feel, perceived warning loudness, visual catch-screen acceptance, and wasp clipping/readability still need direct playtest. No physical device claims. Claude's previews are useful shape references, not native rendering evidence. Do not publish TheWindowsillTests.rbxlx. Only the playable TheWindowsill.rbxlx belongs at existing place **120119801868085**. Publication status of the prior sound release remains unverified.

After acceptance: merge/push main, update Nathan's laptop clone (use escalation outside sandbox; sandbox git status there misleadingly reports no worktree), keep claude-playtest until integrated work is safe, and record exact final commit. The laptop's tracked files were clean on main b5e78c9; claude-playtest is untracked. Preserve the unrelated modified tests place in controls_recovery.

Next Claude: death/continuing and mode selection; preserve audio/captions. Gemini's peacock-spider art and courtship design is independent exploratory work, not yet implemented.
