# The Windowsill — v48 living habitat handoff

## Published release

**v48 is published as Roblox place version 137**, existing place **120119801868085**, universe **10771103250**, at **2026-10-21T21:18:00Z**. Creator Dashboard confirms 137 with **Show published only** enabled. The private playtest's audience is unchanged. The complete release receipt is `docs/verification/v48/RELEASE-v48-place137.md`.

Production source is **1ba2eb3a2b296e72d3cb753e68740b6d62ea8e89** on GitHub branch [`codex/v48-living-habitat`](https://github.com/socranates/jumping-spider-sim/tree/codex/v48-living-habitat). Later commits contain documentation/evidence only. Main and Claude's branch were not changed. Active game: **roblox_port**; Godot is frozen.

Cloud Claude can clone that GitHub branch. Local C: links alone do not transfer the project. The portable published-build package is `C:\Users\natha\claude-xfer\Windowsill-v48-place137-06be0270d414ffc2.zip`; its external manifest records the archive hash. It includes rebuilt playable/test places, source/assets/tests/tools, this handoff and review evidence. Open the rebuilt `roblox_port/TheWindowsill.rbxlx` for local review, or build from source. A locally opened file has no authority to publish to the cloud place; always verify the existing cloud target separately.

**Tracked generated place files in the repository may still be older.** Use the rebuilt package or run `python tools/build.py /path/to/rojo` in a separate release copy. Do not confuse an older generated file with current source. The rebuilt evidence ID is **06be0270d414ffc2**; playable SHA256 **2f36ff0a4cb8c27bb429d07e68e67255a3a4b6683c36e1bda1e0e737dc6b4322**. All **207** XML script sources match the frozen archive byte-for-byte after CRLF normalization (`release-build-1ba2eb3.json`).

## What the player gets

- Compact connected garden/verge/meadow/pond routes with real ground outside the stone path. Nearby cover, litter, shelter and living prey replace the empty shoulders. Existing landmark and save identities remain stable; revision-2 checkpoint positions migrate to revision 3.
- Dust bunnies and joined fibres inside; articulated fleas hop continuously from their previous landings and retain nearby world sites across floor/doorway seams. Two discarded cans have real drinking apertures, rolled rims, open pull tabs and climbable hollow shells.
- Authored leaf/bark shelters, clover and curved grass close to the spider. Garden lawn uses the same existing surface classification as the garden itself, excluding paths, herb beds and hard props. Pools and part ceilings stay bounded; structural cover does not sway.
- A supported ant mound and foragers that leave, search, carry crumbs home and shelter during heavy rain/night. Cream grubs emerge only occasionally on damp ground. These ambient animals do not add meal credits.
- A dog roaming its existing outdoor circuit, with planted articulated paws, sniff/turn motion and a rain stop near the station. It is cosmetic, with no new attack or collision rule.
- Astronomical solar direction, gradual deterministic weather fronts, clouds/rain/wetness and world-direction wind. Grass bends about planted roots. Rain discovers newly streamed roofs while the spider stands still, then returns to the ground when shelter unloads.
- Station-wide resident rival/wasp routing, the mate-drive sight repair, requested progression and a steady small wordless hunger bar.

Implementation history is in `docs/LIVING-HABITAT-v48-WIP.md`; its dated old pending-job entries are historical. The current acceptance/receipt files supersede them.

## Preserve Nathan's decisions

- Keep the liked movement, camera and longer jumps. The camera was not redesigned for scenery.
- First moult: **seven whole-fly equivalents**. Second: **ten additional**. Partial feeding must not repeatedly award whole meals. Run unlocks after the first moult; lock-on after the second. Explain each earned control only when acquired, without advance spoilers.
- L1 held creeps; once lock-on is earned, its press can acquire/toggle a nearby visible prey contact. Locked movement faces and strafes around it. **L2 runs; R2 Focus.** Early aiming remains manual.
- Persistent gameplay HUD: only the steady **120×4 unlabelled hunger bar**. No hunger word, numbers, crosshair, target markers, routine messages or extra meters. Deliberately opened interfaces, usable touch controls and brief earned-unlock explanations are the agreed exceptions. Roblox system icons remain separate.
- Preserve discovery. Do not add environmental explanation overlays. Keep green chelicerae and existing creature presentation. A drawn rival backing-off pose does not authorize new avoidance rules.
- Announce before editing fly, feeding, settings or menu code, and check current Git history before parallel Claude/Chet work.

## Verification

- **Final frozen CLI: 55/55 suites pass**, terminal exit 0. Source **1ba2eb3**; 2,002.88 summed suite seconds. All 55 raw reports plus progress/summary are preserved. `FROZEN-1ba2eb3-RESULT.md` gives identities and limits. Wrapper session **70770 is terminal**; do not poll/restart it.
- Preserve CLI self-test: **270/0/0**, all **7 outer checks pass**, 545.2 simulated seconds / 32,682 frames. Living world **3,978/0**; minimal HUD **32/0**. No failed or deferred suite was silently counted green.
- **Final native Studio 0.744: 270 pass / zero fail / zero skip**, in the existing cloud place, 557 real seconds. Every region's streamed pieces, support, attachment and ownership pass, along with window/ceiling/doorway/bench/meadow/boardwalk traversal and life/sound-state checks. `NATIVE-FINAL-1ba2eb3.md` and raw output retain exact scope.
- Longer ordinary-input full/low station/can/doorway, garden/verge and off-path-shoulder walks: **8,049 sampled frames, zero detached**, all settled holds clear; normal-camera floor fleas and occasional grubs recorded. Initial placement and Free play are disclosed in `HABITAT-JOURNEY-REVIEW.md`. It is not an unassisted survival/hunting playthrough.
- Current-source strict analysis clean; **207/207** source compile. The final source was unchanged during CLI/native gates. Native frame timings overlapping CLI load are not uncontended performance evidence. Earlier no-overlap scene samples are bounded PC observations, not a phone benchmark or constant-60-fps guarantee.
- Dedicated reviews retain dog gait/circuit, colony traffic, streamed floor-flea continuity, solar agreement within 0.028 degrees, natural weather fronts, directional wind and stationary streamed-roof behavior. `HABITAT-ACCEPTANCE.md` maps each requested feature to evidence.

## Publication and current editor state

The existing cloud draft was identified before syncing: saved version 134, 207 script fingerprints matching older 0ca748a. Only Hut, LivingWorld and SelfTest differed from the candidate. Rojo applied those reviewed changes; all 207 post-sync fingerprints match. Those manifests use a bounded non-cryptographic change-detection hash; generated-artifact byte comparison is separate.

Both native jobs are stopped and clean. Cloud marker `[CHET_FINAL_1BA2EB3_NATIVE_CLEAN]` at 21:02:14Z and local `[CHET_HABITAT_JOURNEY_CLEAN]` at 21:09:49Z verify no SilkPlayback or SelfTest/Detail/TestTarget/Wasp overrides. `[CHET_V48_PUBLISH_READY]` at 21:17:44Z again asserts the stopped target, clean attributes, streaming, gravity 35 and 207 scripts. The cloud editor was disconnected from Rojo before **File → Publish**. No Publish As or new experience was used. `published-version-137.png` and `publish-place137.txt` prove publication. Dashboard Last Updated is the draft-save time, not the later publish time.

Current Studio windows: cloud **4131012**, local review **36441252**. Always refresh actual state/identity before actions. The local file has PlaceId/GameId **0** and remains distinct from the existing cloud place. Rojo still serves the writable clone on localhost **34872**; the local review editor remains connected, the cloud editor is disconnected.

## Working rules and artifacts

Writable clone: `C:\Users\natha\windowsill-publish`. Push only remote **github** (`https://github.com/socranates/jumping-spider-sim.git`). Remote **origin** is the read-only OneDrive clone; never push it. The OneDrive project and mirrored `sources/` remain untouched. Do not merge main or edit Claude's branch without a new request. No subagents requested.

Exact frozen source archive: `C:\Users\natha\claude-xfer\v48-full-1ba2eb3.zip`, SHA256 **18fc46895be6af5d58fb3ac14d1b6f360861ff78f673c17a7f23c772a56e7e77**. It is a source snapshot, including older generated files; the separate rebuilt release/package is the playable artifact. The earlier `*-candidate.zip` remains an immutable historical candidate with its original pending-acceptance README. Use the **place137** package for this release.

Regression results: `C:\Users\natha\claude-xfer\v48-results-1ba2eb3`; wrapper `v48_frozen_regression.py` in the same transfer folder. Python runtime: `C:\Users\natha\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe`; Luau/Rojo tools are in the ChatGPT project's `roblox_tools/` directory. Cloud/Linux can use equivalent Luau/Rojo installations and the repository's runner; no host-specific runtime is required by the game.

The requested environmental pass and its release gates are complete. Further device feel, player-discovered encounters and art refinements can be evaluated from this published baseline. Do not relabel Studio captures as published-client playtests or hide the documented performance/art limits.
