# Isolated allocation control: category growth reproduced

Native run `1792669956410` completed **120.845 seconds** on Studio `0.744.0.7441077`, viewport 1105 × 433. The exact one-script guard passed. All 29 checksummed records decode, all phase/activity/balance checks pass, and there was no focus loss or CreatorError. It created **61,000 Parts**, destroyed **61,000**, and ended with **zero fixture Parts**. No Windowsill game source or persistence was included in this control place.

The same broad category pattern seen in the game trace occurs here:

| Category | Stationary-phase change, MB | Churn change from stationary endpoint, MB | Residual after 30 seconds with zero fixture Parts, MB |
| --- | ---: | ---: | ---: |
| BaseParts | +1.303 | **+68.546** | **+69.692** |
| Instances | -0.004 | +4.495 | +4.645 |
| Signals | +0.004 | +2.428 | +2.497 |
| Internal | +2.272 | +27.452 | +21.073 |
| GraphicsParts | +0.620 | +0.007 | -0.612 |
| LuaHeap | +0.872 | -0.539 | -0.335 |

The engine instance count remained 51,780 at both ends of the stationary and churn phases, then dropped to 50,779 after removing the 1,000 Parts and their batch folder. The client's `gcinfo()` heap ended the phases at approximately 2.47, 2.14 and 1.76 MiB. These are different measurements from the much larger engine LuaHeap category. Standing engine/category totals must not be attributed entirely to the game's own Lua data.

The BaseParts change exceeds the predeclared 8 MB investigation screen and more than 80% remains after the quiet phase. **This category growth does not require Windowsill's game scripts.** It is not evidence, on its own, that LookStream keeps all destroyed Parts or that replacing the renderer would fix a game leak. The experiment does not identify whether accounting, allocation pools, other Studio machinery or another engine path explains the figures. It does not establish an engine bug or production-client behavior.

## Separate post-run reference inspection

After the timed control ended, a read-only `SceneAnalysisService:GetUnparentedInstancesAsync()` query succeeded in the client context. The bounded tree contains 22 nodes: root count 42, ten host-script groups, all from stock chat/camera/control functionality. No group owned by the PartChurn probe is listed. Parent/child counts and totals reconcile in the retained summary. This is one **post-run** snapshot, not a before/after game-heap comparison. It does not inspect C++ allocation blocks or prove that the original game has no leaks. The [Scene Analysis documentation](https://create.roblox.com/docs/performance-optimization/scene-analysis) describes this as a view of instances referenced by scripts; the [heap documentation](https://create.roblox.com/docs/studio/optimization/memory-usage) explains its scripting-reference scope.

The first local extraction helper expected 23 tree nodes; inspecting the actual data showed 22. The retained summary validates the complete hierarchy by child membership and summed counts instead of guessing a tree size. This was an extraction assertion, not a native experiment failure, and did not change any native record.

## Conditions and next action

The full Windows CLI job had exited successfully before Play. No heavy CLI jobs, snapshots, app inputs or screenshot captures ran during the timed phases. The observer only read the external log. The laptop still had low free physical memory (438,088 KiB before Play); other desktop processes remained. Therefore this is not a controlled FPS comparison, a hardware budget or a proof of the cause of OS-reported total-memory fluctuations.

Studio automatically migrated this blank place's default Compatibility lighting to Voxel before Play. The notice was dismissed before the guard; lighting stayed the same across control phases. This is a plain-Part allocation control, not a rendering match to the game's Future lighting or a mesh/streaming/asset workload. No game lighting was edited.

Do not remove the original game trace's `investigate_growth` flag. Add this attribution limit to it. A longer quiet period, heap-reference comparison in the actual game and standalone-client/device evidence remain useful; this single control does not close the entire memory/performance audit. Independently, `docs/shadow-stream-retention/` reproduces obsolete shadow bindings after hidden parts stream out. That concrete bug should be fixed and checked on its own merits, without claiming it caused these category slopes.

Observer 76550 exited zero after native DONE. Play was stopped and Studio closed. Its saved serialization was archived locally, then the original diagnostic bytes restored and SHA-256 `e2391f3d640306229068c85093d6310e86bd63ef06681eb3f4e6992c2e3976b4` verified. Nothing was published. `native-v1-events.txt`, `native-v1.json`, `origin-v1.json`, and the separate post-run heap files retain the evidence.
