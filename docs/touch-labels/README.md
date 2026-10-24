# Touch label font fix verified locally

2026-10-23. This follows the private version 13 Player captures in
../private-player. Those captures show Creep and Cancel wrapping inside words,
and Re-centre clipping. The actual touch-button factory does not set Font, so
Roblox supplies its default Legacy font. The candidate assigns GothamMedium,
already used by this game's settings and menu buttons.

Exactly one added line in Client/SpiderInput.luau. Binding tables, action
handlers, input-source tracking, text, button sizes, positions, visibility and
settings are unchanged. No font scaling or minimum-text-size setting added.

The original qualified/published candidate is unchanged. This candidate is
unpublished and unactivated. Its local native label layout is now verified.

- Derivation: prepare.py, derivation.json and spider-input.luau.
- Clean model: C:/Users/natha/claude-xfer/Windowsill-touch-font-attempt1/TheWindowsill-candidate.rbxlx.
- Model SHA256: 64a3ff7e865ce53d401569e8e12605ddff419028ccfd887d518e03e2514b0a6b.
- Compiled 273/273; full strict analysis exit 0. The native-check fixture also
  compiled and passed strict analysis against this exact model's sourcemap.
- Existing settings 1163, client smoke 27, movement/input 196, HUD 103:
  **1489 passed / 0 failed** in touch-font1-receipt.json under
  ../integrated-release. This targeted run is not the full 78-suite repeat.

The private13 candidate's second complete CLI run finished before Studio opened.
Both complete runs have78 suites/468967 top-level passes/0, verified in
../audit/current-cli-qualification.json. They belong to that earlier source
snapshot; the font variant's relevant cohort is the1489 above.

Local Studio run1792818447500 checked all16 actual runtime buttons' fonts, then
rendered80 cloned cases:40 Legacy and40 candidate, normal/short button sizes,
default and contextual labels. **Candidate40/40; Legacy13 failures.** Real
TextBounds/TextFits and same-string unrestricted-width glyph measurements
detect extra rows without confusing deliberate newlines or arrow fallback.
Legacy failures span Cancel, Choose, Creep, Display, Focus, Lock and Recenter.
See native-comparison.png and the complete native-font.json/native-output.txt.

The comparison GUI is a temporary local fixture, not game code. It never
changes actual action bindings, widgets or saved settings. The initial large
single-message log was truncated near1KB; it is not the qualification input.
The fixture was corrected to emit bounded per-row records and rerun on the
same model. All80 rows,16 live-button records, BEGIN/END and before/after273
source guards are retained from the original log. No reconstructed missing
data or tally-only qualification. The initial display-only reframe is retained
separately in show-result.luau.

The overlay was removed; an ordinary New Life click reached the spider and0/7
meal counter (ordinary-entry.png). Actual touch controls were not enabled on
this Studio desktop; they were not forced visible. The clone comparison is a
native component layout check, not a physical-phone/controller comfort test.
Play stopped with Shift+F5. Postguard passed at00:12:14; Game/Place remained0
and all273 source bytes unchanged. Studio4880 closed without saving temporary
editor state; the original model hash remains unchanged. No Rojo or upload.

This unbound editor cannot use DataStore. The log retains40 CreatorWarnings:
1 initial store-unavailable,32 local config-load,1 session-only,2 inherited
asset203785492 type and4 StyleRule warnings;0 CreatorErrors. The repeated
no-API warnings are not a successful storage test. Studio private memory was
about3.6GB; accessibility temporarily returned no data during gameplay.
Cause was not established. No FPS, memory-leak or startup-stall fix is inferred.
No new unit test was added for this small presentation change.

Recheck: `python docs/touch-labels/collect.py --check` binds exact model/source
diff, all targeted outputs, bounded native rows and screenshots. The original
full log remains local and is bound by hash; unrelated log data is not copied.

The private published version remains 13 and production remains 140. Earlier
standalone startup gaps and broader audit limits remain in HEALTH-CURRENT.md.
