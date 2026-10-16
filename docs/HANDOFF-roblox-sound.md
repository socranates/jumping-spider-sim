# Sound integration in progress — 2026-10-16

Branch `codex/roblox-sound` includes Claude LIFE `6af95a9` (imported from Nathan's Downloads/claude-life.bundle), based on main `b5e78c9`. Not merged or published yet. Current build evidence `e97786418fd0fdb3`.

Original procedural WAVs exported from frozen Godot sound_bank.gd and uploaded to socranates. `roblox_port/assets/audio/manifest.json` records exact hashes, asset IDs and permission status. Room, buzz, takeoff and birds have saved permission for universe **10771103250**, place **120119801868085**. The other four recordings are reserved, unused and have not been granted experience access. No Creator Store distribution enabled.

Client Soundscape adds quiet room ambience, intermittent daytime birds and spatial fly flight/struggle buzzing. Menu pauses, SoundMuted attribute silences, slow motion scales playback speed. No simulation or perception changes. Roblox master volume is the player-facing control. Bounded emitter pool (maximum eight flies); checkpoint restores read current fly objects. `tools/export_audio.py` reproduces WAVs with Godot without changing its source.

Verification:
- Imported LIFE baseline Windows CLI: 28,773 passed, zero failed (captured in session tool output).
- After sound changes: 806 affected CLI checks passed (CLIENT 16, PERCEPTION_CLIENT 1, EYES 231, HUD 69, LOOK 72, WORLD 230, FLIES 187). Includes two new audio checks. `docs/verification/roblox-sound/client-checks.txt`.
- All 109 Luau files compile. Strict src check clean using luau-lsp with correct roblox_port working directory.
- Both places rebuilt. Actual Studio audio loading, audible mix, LIFE engine suite, night readability and frame time are **pending**.
- Nathan initially reported silence; log showed the existing online place, not this local test build (no PORT markers). Do not record that as an audio failure on this build.
- Native Studio controls unavailable in this tool session. Nathan requested help opening local test; copied it to `C:/Users/natha/Downloads/Windowsill-Sound-Test-e9778641.rbxlx`. Await his Play run, then collect fresh Studio log with tools/collect_studio_report.py. Do not upload the test place as the playable game.

Finish: verify engine suite and sound loading/hearing, tune if needed, review night visuals, then merge/push main, update laptop and publish the playable TheWindowsill.rbxlx to the existing place. Prior published build remains b5e78c9; Nathan confirmed PlayStation works. Data Sharing off. Keep solo max-player setting on checklist (not verified). No persistent saves yet.

Claude next: death/continuing or wasp director, after this integration is accepted; preserve sound's presentation-only contract. Add wasp audio only with the actual wasp behavior and advance warning. Read HANDOFF-roblox-life.md for remaining LIFE acceptance checks.
