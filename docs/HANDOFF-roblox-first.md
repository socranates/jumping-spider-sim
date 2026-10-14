# Handoff — Roblox foundation and first spider, 2026-10-14

Nathan chose Roblox-only and asked for a cuter first spider. Both parts of Perplexity's c87ce00 branch are included in main. Keep `roblox_port/`; Godot is frozen, runnable and used for golden behavior. SPEC is unchanged. README, ROADMAP and PLATFORM-01 now make the active direction explicit.

## This chunk

- Exact daughter's reference committed in docs/art; appearance data separated into Appearances.luau.
- Rounded black body/head, five principal white abdomen spots plus front band/speckles, pale cheeks, banded palps/legs and stouter front legs. Stage attribute does not recolor the selected design.
- Basic keyboard/gamepad/touch actions share InputState; focus loss cancels held actions. Full remapping/help/settings and device acceptance remain.
- Separate Studio test place/runner and build stamping; normal place contains no test runner. Fixed inherited runtime Lighting.Technology error by authoring it in the place.
- Full inventory, reference files/tests, port order and server/filter/save policy: **docs/ROBLOX_PORT.md**. Solo publication (max players 1) is the decision; no experience/settings were published here.

## Verification

Windows Luau **43/43**, native Studio **6/6**, evidence **5b14ae68fed28794**. Engine count includes suite completion; 17 Luau files syntax-compiled. Actual screenshot and JSON in docs/verification/roblox-first/. Keyboard hop and close visual inspection performed. Physical controller/tablet, low-end frame time, full traversal and Roblox-aware strict type analysis remain unverified. Godot 644/644 Linux is inherited, not a new Windows run.

## Claude next

**Safety silk**, following ROBLOX_PORT.md: pure tether states with frozen Godot goldens, then engine catch/hang/reel/lower/hold-release and edge-first let-down, including capped catch framing. Current strand is drawn only. Keep the jump solver unchanged unless a demonstrated bug needs fixing. Finish controls/camera acceptance with Nathan on actual devices as a parallel part of the same port milestone, not an assumed pass.

Build from `roblox_port/` with `python tools/build.py path/to/rojo`; pure checks with `python tests/run.py path/to/luau`. Open TheWindowsillTests.rbxlx for engine reports; TheWindowsill.rbxlx for playing. After updating the laptop, reopen the place. `play.bat` opens the frozen Godot reference.
