# Native UpdateAsync callback failure reporting

Branch `codex/save-adapter-errors`; frozen runtime `dc1c4b8640014a5718b6dc17d31044aca070c6d7`; evidence `e50104232f063255`. Unpublished. Based on the preceding compression and New Life retirement candidate, not on a new live release.

## Problem and fix

The isolated native store probe established that a thrown UpdateAsync transform error can be logged while the outer pcall returns `true, nil`. The old adapter treated that as success. An encoder failure after SaveSession had selected a valid write could therefore clear a pending retirement and emit its acknowledgement even though nothing was committed.

The adapter now catches decode, user-transform and encode errors **inside** the native transform callback. It returns nil to cancel the write, retains the original reason for that operation, and reports failure outside the native API boundary. If a callback is replayed after a failed attempt, it remains cancelled; a later independent operation starts clean. Ordinary cancellation and successful retries keep their existing behavior. No save schema, gameplay or serialization representation changes.

The regression first failed against the previous adapter (`regression-before.txt`), then passed against the fix (`regression-after.txt`: 57 checks). State integration passed 572 checks, including failed retirement remaining queued, no acknowledgement/Saved state, untouched earlier checkpoint, and one acknowledgement after a successful retry. All 216 source modules compiled at -O0; strict analysis is clean apart from tool startup/watch-registration messages; five runner regressions passed.

## Native online result

The fixed adapter passed a real DataStoreService test in `WindowsillTest_v1`, key `R_chet_life_1792650334099_main`, at 2026-10-22T06:26:29Z. It used the earlier native-engine synthetic 233-region checkpoint, the real Zstandard codec and uncached reads. Checks covered exact checkpoint fields, retirement marker/backup, stale life refusal, a subsequent new-life rest, independent recovery after deliberate corruption, accurate refusal status and unchanged damaged storage. Native stored current-plus-backup JSON was 453,974 characters before deliberate corruption.

All 175 candidate modules used by this probe were checked against frozen source in an unparented clone. They never entered the cloud edit model. No API key was read and no production store was touched. A final read-only cloud guard matched all 215 production scripts to the previous v51 source at 06:28:01Z. The cloud edit copy reports version 141; that alone does not establish a published release.

This is not a real player disconnect/rejoin test. Keep that gate separate.

## Completed verification

Linux Actions run 39733574738 completed successfully for the frozen source: **62 suites / 443,235 checks passed**, with strict analysis, compilation and runner regressions green. The foreground local native preserve run matched 216/216 source fingerprints before Play and completed **274/0/0** at 2026-10-22T06:40:10Z. Its native codec/session probe passed with the full synthetic checkpoint, and no CreatorError or script timeout was recorded in the guarded run. Windows exec **24276** completed with exit **0** at 06:49:53Z: **62 suites / 443,235 checks passed**, with no failure lines. `cli-process.json` and `cli-final.txt` record the actual terminal result.

`runs.json` stores the handles. `verify.py` recomputes source/build evidence and leaves missing gates false. The local review file listed in `native-review.json` contains a diagnostic helper and synthetic fixture and **must never be published**. Production XML is generated separately. The active optimization goal remains open: legacy-world/per-slot safety, overlapping-session UX, route activation, captions and controlled performance/manual checks still need work.

The release preflight also parses the actual production XML, verifies all 216 script sources against the frozen manifest, and refuses diagnostic payloads/authored review attributes. Negative controls confirm it refuses both the Studio-test place and the local diagnostic review place (`build-preflight.json`). It does not publish or establish a destination.
