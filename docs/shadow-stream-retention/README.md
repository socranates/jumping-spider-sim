# Shadow bindings after stream-out

Reproduction on predecessor `fab75695ba918eeebe793e6768a08cabe99a70f3`; candidate fix **`a5dba50faa8efc2018acba90ad03356eb25ad20c`**, evidence `e7ee7af50d1b89b3`, branch `codex/shadow-stream-cleanup`. Unpublished. The same behavioral probe now passes on the candidate. Full and native gates remain separately tracked below.

`WorldShadows.bind` records every arrived part in a holder's `bound` table and `count`, including invisible/non-shadow-casting parts. Only visible eligible parts enter `self.entries`. The slow parent check scans that latter list, so it never releases the hidden bindings. Once the holder's count reaches its expected number, `bind` stops checking the folder, even after it and those parts stream out.

The small fixture uses the real outer-sill region's three expected pieces and the real WorldShadows implementation. It binds hidden parts, destroys the folder, then creates new instances under the same region id and advances beyond the binding interval. It reports:

```text
SHADOW_STREAM_RETAIN old_parts=3 retained=3 fresh_shadow_off=0 expected_off=3
```

The assertion fails with native CLI exit 1 because the manager retains all three old instance keys. The replacement visible parts also remain outside distance-based shadow management. Changing visibility in the fixture exposes that functional consequence; releasing obsolete bindings is required even when the replacements have the same hidden flags. This is scripted stream-out/rearrival, not a native streaming, memory or FPS measurement.

Candidate output from that identical probe is `retained=0 fresh_shadow_off=3 expected_off=3`, exit zero. Source hashes for every bundled module and the common test hash are retained in the paired process receipts.

This state can retain an initial set of obsolete bindings per region; it does not by itself prove unbounded growth on every renderer cycle. These are world collision-box bindings, not the drawn look folders that the long trace repeatedly creates and destroys. Do not attribute the measured BaseParts/Signals slopes to this bug without a matched native check.

## Candidate change and checks

Only the production module `Client/WorldShadows.luau` changes. Initially hidden/non-casting parts get a separate list whose periodic parent checks are capped at 100, independently of the existing 100 visible checks every two seconds. Their properties are never written. Both part-to-folder and folder-to-root membership are checked, because an unparented folder can still parent its children. Each tracked entry holds its actual owner; releasing a moved part no longer risks deleting its new holder's binding. The distance rule, home exclusion, visible check cadence, collision/geometry, movement/camera, feeding, saves, settings and menu code are unchanged. This adds bounded tracking metadata/periodic checks; it is not an FPS claim.

The shadow suite grows from 25 to **319 passing checks**: hidden, non-casting and visible child/folder replacement; destroy versus unparent; 30 generations of mixed arrivals; independent cleanup budgets; correct ownership for four movement/eligibility combinations; and home exclusion. Existing world-client integration passes 30 more: **349 targeted checks**, exit zero. All 216 source modules compile at `-O0`, strict analysis is clean and five runner regressions pass. The intermediate `*-owner-only*` files belong to an earlier uncommitted version and do not cover the final ancestry checks. Final-source receipts are verified by `verify.py`.

Linux CI **39777487503** completed successfully at 2026-10-22T12:28:58Z for the exact candidate: **64 suites / 443,816 passed / zero failed**, all four tool-download checksums, 216 compilations, strict analysis and five runner regressions. Actual source-bound job metadata and logs are retained in `ci-final.json` and `ci-*.txt`.

Full Windows exec session **78583** has now terminated with exit zero: **64 suites / 443,816 passed / zero failed**. The complete closed log is retained in `windows-full.txt`; `windows-full-process.json` records the actual process result. The closed log was normalized to LF only after termination. `verify.py` independently checks the suite count, totals and zero failures; both full CLI gates now cover this candidate. Native execution remains a separate pending gate.

## Native status

The guarded review place is prepared at `C:\Users\natha\claude-xfer\Windowsill-shadow-cleanup-native-v1\Windowsill-shadow-cleanup-review.rbxlx`, SHA-256 `7e73edee0887b68c34035520a0c5a60340d4b1b6b8a592aae27cd5d9eb322604`. All 217 prepared script fingerprints match the candidate plus the diagnostic; persistence is disabled. It must never be published. The probe mirrors the new lifecycle cases using real Instances and preserve-region metadata without switching the active world; it is not an automatic network-streaming or FPS test.

**Native execution is not verified.** Two fresh Studio startups showed Low System Resources before this place was opened. The warnings were dismissed without proceeding and the unused app sessions closed. Closing completed task sessions and resetting the UI tool recovered memory, but the fresh retry still warned. Additional headroom was requested asynchronously; do not treat elapsed time as the user's reply or keep relaunching unchanged conditions. No native FAIL/DONE record exists for this candidate yet. `verify.py --require-full` requires actual native execution as well as both full CLI gates.

`run.py` constructs a temporary bundle with current source and current shim, without editing the project's running full-suite inputs. `baseline-process.json` records the actual CLI failure and hashes every bundled source module; the helper itself exits normally after recording that expected observation. The new regression must fail the default test runner if its expectations fail after integration.
