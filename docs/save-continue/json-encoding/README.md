# Canonical encoding with one owned output buffer

Adopted in the working branch after a private CLI/native comparison. Full integration gates are pending; nothing is published. Only runtime file changed: roblox_port/src/Shared/Persistence/Json.luau. Saved JSON bytes, sorted-key order, full-precision number formatting, checksum input, rejection text/path, metatable/alias/cycle rejection and the cooperative pulse boundary are preserved. No validation, readback, backup, intent/authority or atomic-commit check is removed. There is no save-format version change.

The old encoder allocates an output table and joined string per container, then joins those strings again up the tree. The new encoder appends into one private fragment array and joins once after validation succeeds. Source graph and all intermediate output stay private; cancellation discards them. Coherent game capture remains synchronous. Final concatenation and other native calls remain non-preemptible, so the frame budget is still soft.

## Why this candidate was adopted

attempt-1 retains the unmodified baseline/prototype and exact inputs.20,716 differential checks pass: seeded nested data, control/Unicode/raw byte strings, numeric boundaries, deep nesting, malformed/sparse/mixed keys, metatables, aliases/cycles, exact rejection paths, interleaved workers and cancellation. The new permanent json_encoding suite compares production against a frozen ab8ca95 reference, independently of future encoder edits.

Four alternating CLI pairs encode the same2.282M-character actual preserve record: original mean492.658ms, candidate336.109ms,31.8percent less CPU. Per-pair reduction ranges approximately24-36percent; an earlier informal29-34percent range was inaccurate. Heap and longest-step observations vary; no heap improvement or FPS claim follows.

Native1792705255081 uses original sourceab8ca95 plus two private modules.224 exact fingerprints passed before Play; PlaceId0/production Persistence disabled.20,738 assertions pass, including20,716 differential checks. Four alternating pairs encode one identical1,503,074-character record:

| Round | Original CPU ms | Candidate CPU ms | Original max step ms | Candidate max step ms |
|---|---:|---:|---:|---:|
|1|409.674|243.314|19.160|8.780|
|2|453.420|276.581|35.194|13.302|
|3|451.733|258.331|31.060|12.857|
|4|443.519|271.989|31.678|12.117|

Mean original439.587ms, candidate262.554ms:40.27percent lower cooperative encoder CPU in this isolated comparison. The candidate's longest step is lower in every pair. This is not whole-game FPS, typical-device performance, a hard2ms frame bound, heap regression/gain proof, or measured end-to-end save improvement after adoption. Peak-heap deltas are retained and variable. Initial Heartbeat gaps include wider engine timing; they are not encoder-only cost.

No heavy CLI ran concurrently. A prior stopped rig window remained; no new Low System Resources warning was observed.233 initialization attempts were streaming dependent; resident ecology was not measured. The diagnostic was stopped/saved/closed, its window63963396 exited, original XML/hash restored, and the prior window94504044 left alone. v2 archive: C:/Users/natha/claude-xfer/Windowsill-json-encoding-ab8ca95-v2/Windowsill-json-encoding-review.rbxlx, SHA256af341679e86a41d743207850665e3b2658b02be66d242cc2740ba7981abbeb48. Never publish a diagnostic.

The first builder attempt failed its stale uniqueness-count assertion before the XML disable pass; no native run occurred. That failed directory is marked FAILED-BUILD and must not be used. v2 corrects both counts to224, verifies unique paths and disables production persistence before a successful manifest/guard is produced. All native results belong to v2.

## Current checks and next gates

The adopted function is byte-identical to the tested prototype except its introductory comment; the native copy changes only the SaveWork require location to share the same work context. verify-prototype.py binds baseline Git inputs, exact adopted code, frozen reference, eight CLI samples,224 native fingerprints, eight native samples and closure/restoration hashes. It passes and deliberately does not claim full integration completion.

Adoption checks from exec56254: JSON_ENCODING20716/0, CHECKPOINT570/0, SAVE_WORK39/0, SAVE_RESTORE24/0, REST_STORAGE14/0 and REST_COMPRESSION57/0; six suites/21420 total. All222 modules compile, strict analysis clean, runner5 pass in final-check. This ad hoc output is tool evidence; the full gates provide primary archived integration logs.

Full Windows/Linux now need to run on the committed adoption source: expected76 suites/465380 checks, still an expectation until terminal receipts. Root docs/save-continue/verify.py now refuses to pass until both current full gates exist and succeed. Older save-cost verification is pinned to archivedab8ca95 inputs so historical proof stays reproducible. A subsequent native adopted-game save/restore run and broad28-item audit still remain open. Source release XML/BuildInfo remain old; goal active, no publication.

Committed adoption source068a87891770dbdf291ec3cab0e67480d14c0251. Windows exec28618 and Linux39860574006 are confirmed live; Linux compile222/strict are already successful. fetch-ci.py collects that exact run/source only. Do not restart live jobs or stage the Windows log before its terminal receipt.


## Current adopted-game probe prepared, not run

game-build.py packages source068a878 with the unchanged10-check actual save-cost probe and22-check cancellable local-return probe, sequentially driven by game-probe.luau.225 unique script fingerprints; production Persistence disabled; PlaceId0 guard. Prepared artifact C:/Users/natha/claude-xfer/Windowsill-encoder-game-068a878/Windowsill-encoder-game-review.rbxlx, SHA2569cbcd6d5da98c77131077f22b9113b1a39398be2976ed27d84884613c10c3d5e. Manifest/guard are bound here. Both original PASS markers with their exact counts and no FAIL/CreatorError are required; wrapper END only means sequence completion. Run only after local full Windows exec28618 is terminal. No actual adopted-game native result exists yet. Never publish the diagnostic. This source/probe preparation does not change any production code or the live full-run inputs.
