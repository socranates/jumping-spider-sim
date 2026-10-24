# Integrated playable candidate - 2026-10-23

Deployment is superseded by [the corrected menu candidate](../menu-overflow/README.md).
This document retains the earlier complete-cohort checkpoint. Subsequent local
Studio Play exposed and fixed title clipping; the newer handoff records that
evidence. Neither candidate has been uploaded or published to the private test
experience, and standalone-player testing remains pending authorization.

This assembles the qualified normal Preserve startup/save owner and scenery
cache into a complete playable model. It does not activate production sources,
merge main, publish Roblox production, or change the OneDrive/Godot originals.

## Models

Clean model:
`C:/Users/natha/claude-xfer/Windowsill-integrated-attempt3/TheWindowsill-candidate.rbxlx`

SHA256 `df8cc8365d8cde795c071b8c6abe133ea2fb24a9ef278e435bb0122de505e069`.
All 273 game sources compile and pass full strict checking. The model contains
the 56 qualified normal-startup targets plus the LookPlan scenery cache. Other
sources come from bd67582b5d53473f067244fc1e2e1f94adde173b. Persistence uses its
normal engine adapter; no diagnostic storage, seed, observer, playback or test
runner is included. Detail is automatic, so the low tier remains available to
touch-only devices. This clean file is unbound and has not been executed or
published.

Standalone-player test model:
`C:/Users/natha/claude-xfer/Windowsill-isolated-player-attempt3/TheWindowsill-isolated-player.rbxlx`

SHA256 `1fcddefab817f40c0e8585363b92d9469e53554bb4e335266db8ac360fdbf82c`.
All 273 gameplay sources are byte-identical to the clean model. The only added
source is a read-only, 90-second arrival/frame probe. All 274 sources pass full
strict checking. The deployment target is **Windowsill Save Tests**, universe
10771634917, place 109879630247781. It is never a production upload.

The empty PortTests folder is an identity marker, not a runner. Ordinary
Persistence therefore chooses `WindowsillTest_player57_20261023a1`, with fresh
`t<server os.time>_<UserId>` keys. No existing production record or retired
synthetic actor is selected. The guard requires exact game/place IDs, checks
every source's bytes, rejects unexpected editable sources, requires the marker
to be empty, and verifies the test store and automatic detail policy.

That guard passed in the actual local Studio editor at 22:02:16.465 Central:
`[ISOLATED_PLAYER_GUARD] 274 normal_gameplay_fresh_test_keys_only_never_production`.
The screenshot and editor-check.json retain that observation and bind the
saved local editor snapshot, model manifest and guard. The downloaded baseline
opened unbound; supported SetPlaceId/SetUniverseId calls associated only its
local editor copy with the named test place before Rojo could connect. No
security or access settings changed. Creator Dashboard also confirmed both
game access and audience reach are Private. This verifies editor source
identity; it is not a native gameplay or published-player result.

## Complete CLI run

The final complete run passed **468,967 checks across all 78 default suites,
with zero failures**. This is the suites' top-level reported total; nested
self-test assertions are not added again. The Preserve self-test separately
reported 274 internal passes with no failures or skips. Independent verify.py
binds these results to both final models and the successful native editor guard.

`run-cli.py` runs the entire default list from the existing test runner, against
the complete staged source tree. It uses lazy require resolution so newly
integrated modules do not need a fragile manually ordered module list. Shared
and Server RequestAdmissionFacade have separate aliases. No assertion or
reference input is removed.

The old CLI stand-in lacked the engine's `Workspace:GetServerTimeNow` method.
The first complete attempt stopped at navigation startup. An explanatory
focused rerun retained the actual error, and `prepare-test-support.py` added
that API to the **external staged shim only**, preserving its old os.clock
default. The focused navigation test then passed 15/0. Failed outputs and
compressed bundles remain beside the eventual complete result.

The complete run is `full2`; its receipt binds all 273 source files, all test
inputs, runner, aliases, suite list, bundle hashes, output hashes and exit codes.
Its staged game/test bytes are also verified against the final clean model.
The earlier attempt2 had a forced full-detail metadata attribute; attempt3
removes that attribute without changing any of those tested source bytes.

## Verification and reproduction

Run from `C:/Users/natha/windowsill-save-continue` with the bundled Python:

```text
python docs/integrated-release/build.py --out C:/Users/natha/claude-xfer/NEW-clean-attempt
python docs/integrated-release/prepare-test-support.py --stage C:/Users/natha/claude-xfer/NEW-clean-attempt
python docs/integrated-release/run-cli.py --stage C:/Users/natha/claude-xfer/NEW-clean-attempt --prefix NEW-full
python docs/integrated-release/build-player-test.py --candidate C:/Users/natha/claude-xfer/NEW-clean-attempt --out C:/Users/natha/claude-xfer/NEW-player-attempt
```

The existing final artifacts are checked with:

```text
python docs/integrated-release/verify.py --candidate C:/Users/natha/claude-xfer/Windowsill-integrated-attempt3 --player C:/Users/natha/claude-xfer/Windowsill-isolated-player-attempt3 --check
python docs/normal-startup/verify-online.py --check
python docs/frame-ordinary/verify.py --check
```

`collect-player.py` accepts one explicit local RobloxPlayer log and run ID. It
extracts only the probe's bounded JSON events; unrelated client/account/network
log content is not copied. A complete probe requires six intervals, a normal
ready title, no world-startup failure, and the exact test-store identity. It
does not infer subjective comfort, actual movement, source identity, publication
version, or broad FPS improvement from those timings.

## Evidence boundary and next step

The existing real-storage qualification and matched scenery/frame comparison
both reverify against their exact retained inputs. The cache reduces duplicate
decoration generation while preserving the authored density and low-tier
policy. The measurements do not establish a general steady FPS improvement.

The initial Studio pre-render stall remains unresolved. The private player
build is prepared to distinguish a Studio-local arrival stall from standalone
player behavior. At this checkpoint it has **not** been uploaded, published or
played. Creator Dashboard showed latest test-place draft 12, but published-only
history showed version 2; a draft must not be mistaken for a live test build.
No real-phone, complete controller-comfort, new audio-permission, or whole-map
manual clipping pass is claimed here.

Do not publish an older online/performance diagnostic model. For this player
test use only the guarded isolated-player project above, inspect the exact
private destination, and retain both Studio source-guard evidence and Creator
Dashboard's published version before interpreting a standalone run.

Production remains unchanged until the explicit release step. The three
unrelated save-cost output edits and roblox_port/sourcemap.json are preserved.
