# Touch label candidate: native layout check pending

2026-10-23. This follows the private version 13 Player captures in
../private-player. Those captures show Creep and Cancel wrapping inside words,
and Re-centre clipping. The actual touch-button factory does not set Font, so
Roblox supplies its default Legacy font. The candidate assigns GothamMedium,
already used by this game's settings and menu buttons.

Exactly one added line in Client/SpiderInput.luau. Binding tables, action
handlers, input-source tracking, text, button sizes, positions, visibility and
settings are unchanged. No font scaling or minimum-text-size setting added.

The original qualified/published candidate is unchanged. This candidate is
unpublished, unactivated, and **not yet a verified visual fix**.

- Derivation: prepare.py, derivation.json and spider-input.luau.
- Clean model: C:/Users/natha/claude-xfer/Windowsill-touch-font-attempt1/TheWindowsill-candidate.rbxlx.
- Model SHA256: 64a3ff7e865ce53d401569e8e12605ddff419028ccfd887d518e03e2514b0a6b.
- Compiled 273/273; full strict analysis exit 0. The native-check fixture also
  compiled and passed strict analysis against this exact model's sourcemap.
- Existing settings 1163, client smoke 27, movement/input 196, HUD 103:
  **1489 passed / 0 failed** in touch-font1-receipt.json under
  ../integrated-release. This targeted run is not the full 78-suite repeat.

Next: after the published candidate's separate menu-full2 CLI process finishes,
open this clean model locally in Studio. Execute its guard.luau while stopped:
273 exact sources, Game/Place 0, no diagnostics, normal SelfTest=false. Play;
execute native-check.luau in the **client** command bar. It requires the actual
runtime buttons to have the candidate font, then compares cloned buttons with
Legacy/candidate fonts at normal/short sizes and contextual label variants.
It records real TextBounds/TextFits and checks for unwanted extra rows rather
than accepting a wrapped word just because it technically fits the button.

The comparison GUI is a temporary local fixture, not game code. It never
changes actual action bindings, widgets or saved settings. Retain its original
TOUCH_FONT_NATIVE JSON and a screenshot; inspect any failure before calling the
fix verified. Stop Play, rerun the model guard, and close this unpublished
editor. Do not publish it, claim a physical-phone test, or measure performance
while another heavy job is running. No new unit test was added for this small
presentation change; native layout is the relevant remaining evidence.

The private published version remains 13 and production remains 140. Earlier
standalone startup gaps and broader audit limits remain in HEALTH-CURRENT.md.
