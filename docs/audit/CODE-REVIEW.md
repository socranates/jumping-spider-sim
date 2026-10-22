# Current-source overlay: 068a878, encoder full gates running

The current lexical map now binds222 production files/56,775 lines to source068a87891770dbdf291ec3cab0e67480d14c0251 on codex/save-continue. All indexed production bytes match. Thirteen files exceed800 lines; fifteen lack a direct top-level test import. These counts are not runtime coverage percentages or an exhaustive review; no cycles were found only in the literal-require graph.

The initial findings below are historical. In particular, the earlier claim that Fresh resets only the cat is superseded: current SpiderClient explicitly resets bird/frog/crabs, applies the new life's gentle rules, and tests/outdoor_life_reset.luau exercises stale reaction cleanup through the real client shim. Current full Windows output includes OUTDOOR_RESET45/0. This is code/shim proof, not completion of native lifecycle or every device case.

The current encoder change preserves format and validations while replacing per-container output buffers with one private fragment buffer. Focused compatibility/save checks21420/0, compile222/strict/runner5 and native paired algorithm20738 assertions pass; Linux39860574006 has completed76/465380/0 plus static/runner gates; Windows28618 remains live. The adopted-game225-script save/return probe is prepared and not run. See ../save-continue/json-encoding/README.md. Do not infer whole-game FPS, heap improvement, online durability or broad audit completion from the paired encoder CPU measurements.

The older review record follows, with its original scope and evidence limits.

# Source review and follow-up boundaries

> Current candidate status: [CURRENT.md](CURRENT.md). This report retains its original named-source evidence.


Baseline: v51, source `14e60991c785c4293c3560e6d8b7ecded7e7ac75`, place 140, evidence `d9ddc5e0ed43d301`.
Candidate: `5ee048a791da5fa4f5b99aac53d9769bcd358845`, evidence `c7af2726574c44cc`, branch `codex/foundation-audit`.

`MAP.md` and `inventory.json` index **every source module**, its header purpose, size, consumers, direct test imports and runtime call sites. This is a static inventory, not a claim of a line-by-line behavioral review of all 215 files. Lexical dependency analysis found no cycles. Shared modules do not appear to import client/server presentation. Twelve files exceed 800 lines; fifteen lack a direct import from a top-level CLI suite. Indirect client coverage can exist for those fifteen.

| Area / modules | Review outcome | Next action |
|---|---|---|
| `tests/run.py`; six suite endings; `tools/check.sh`; workflow | False-success paths and missing-input skips fixed; temp cleanup added; unoptimized compilation enforced. | Keep runner regressions in CI. Add explicit suite completion manifests if a test can stop early without raising. |
| `PreyWorld`, `WorldClient.regionReady`, `Garden` species dispatch | Readiness precedes absence checks unnecessarily; reordered with real preserve specs and streaming-gate regression. No perpetual readiness cache. | Profile repeated populated-region scans before caching, with stream-out invalidation tests. |
| `SaveRules`, `SaveRest`, `SaveSession`, `SaveService`, `SaveText`, `SaveClient` | Known-slot rejection now becomes a recoverable status instead of a silent drop. Caps, legacy-world validation and lease behavior remain larger risks. | A02/A04/A05/A06 in FINDINGS; prioritize serialization and migration before new content. |
| `Json`, `ObjectRecord` | Canonical sorted keys and deterministic table numbering; JSON rejects cycles/metatables, while ObjectRecord represents named graph cycles explicitly. Decode builds fresh objects, validates references/classes, then commits roots in place. Checksums are corruption detection. | Add adversarial native validation and Unicode/JSONEncode size comparisons. No checksum/schema rewrite in this patch. |
| `Checkpoint`, `CompactMigration` | Boundary refusals guard feeding, unstable strikes, mating scenes and brood hatching. Existing preserve revision migration relocates known old layout records. The legacy-world probe accepts its 53,882-character bed save under test_garden, then rejects it under preserve. | Define a legacy-world migration explicitly; do not confuse a moved layout with an entirely different world. Keep old fixture bytes unchanged. |
| `SpiderClient` | Large orchestration module includes simulation, saves, UI and creatures. It currently compiles at -O0; local-count risk is pressure, not a present compiler failure. Fresh resets cat but does not explicitly reset all outdoor predator state. | Extract `SaveSync`, `HudView`, then `CreatureStep` behind a shared context with real-client preserve tests. Change one responsibility per review. |
| `RivalRoute`, `RivalDrive`, `StationAir` | Seeded graph output can coexist with wall-clock-dependent readiness and actor start timing. | Deterministic activation barriers and frame-rate traces; preserve current attack and evasion rules. |
| `LookStream`, `LookPlan`, `LivingWorld`, `PondBodies`, HUD | Whole required-look builds, close-detail churn, repeated poses and discarded strings remain plausible costs. | Measure matched scenes. Do not claim costs saved from the absence-scan test alone. |
| `WorldBuild`, `Region`, `Scenery`, preserve generators | Collision topology and drawn detail are separate; Persistent station/verge geometry is deliberate fall protection. World generator caches retain authored specifications across regions. | Inspect retained-cache memory over a long traversal; optimize draw assets independently from collision. |
| Growth, feeding, needs, rare ledger | Current code expresses 7/10 first moults, earned run/lock, tap feeding, bounded starvation and monotonic rare claims. These are carried forward, not redesigned. | Retain existing pure and client regressions. Test each native input device and real online restore. |
| UI/settings/notebook/audio/rig modules | Strict/source/type/CLI coverage reviewed through inventory and existing tests. No claim of exhaustive native accessibility, biological sentence verification, audible balance, or comfort testing. | Explicit manual checklist in TESTS. Do not remove requested prompts or add rare encounter markers. |

No setting, creature rule, collision mesh, light, camera or player model is changed by the candidate. Goldens, frozen Godot data and original OneDrive checkout remain untouched.

Accessibility follow-up (A11): `SpiderHud.minimalView` omits `view.caption`, so the preserve projection drops sound captions even though Caption settings still exist. It also clears toast/note labels. The new rejected-rest text is reliably available through save status/the menu, not a promise of a visible in-play toast in the preserve. Reconcile opt-in captions and important save failures with the deliberately minimal HUD in a dedicated UI check; do not silently weaken Nathan's design rule.

## Release and repository hygiene

Use one integration line beginning at the published v51 commit, then this audit branch. `branches.txt` is an inventory only: no branch deletion, main reset or merge was performed. Keep the published build reproducible; generated playable/test files must be rebuilt after the final source change. CI currently downloads moving Luau/LSP/definition releases; pin a known working set after checking current tool versions, rather than guessing versions.

Archive historical handoffs through an index, not deletion. Keep current README, current release receipt and current handoff prominent. A handoff must include a clean source branch/commit, evidence ID, actual test logs, generated builds and known limitations. A local file link alone cannot serve a cloud Claude session; provide the pushed branch and portable package when the candidate is cleared.
