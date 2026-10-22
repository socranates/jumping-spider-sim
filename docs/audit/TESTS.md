# Verification ledger

> Current candidate status: [CURRENT.md](CURRENT.md). This report retains its original named-source evidence.


Baseline: v51, source `14e60991c785c4293c3560e6d8b7ecded7e7ac75`, place 140, evidence `d9ddc5e0ed43d301`.
Candidate: `5ee048a791da5fa4f5b99aac53d9769bcd358845`, evidence `c7af2726574c44cc`, branch `codex/foundation-audit`.

## Automated work

* Runner infrastructure: **5 Python tests passed** (`runner-tests.txt`). Missing default/named tests, missing modules, nonzero child exit, temporary-file cleanup.
* Readiness regression: **4 Luau checks passed**, with 2,000 absent-spec queries avoiding geometry scans. A populated region still waits for readiness and can initialize after it arrives.
* Save probe: current preserve populations exceed the existing online cap; exact sizes and counts in `save-probe.txt`. Legacy bed rest: valid in test_garden, invalid in preserve. Probe does not touch live APIs.
* All **215** source modules compiled locally at `-O0` (`compile-final.json`). Strict analysis completed with no source diagnostics; `strict.txt` contains tool information and a watched-file registration warning.
* Independent clean Linux CI: **60 suites, 443,102 checks passed**, no failed summary lines; job 39716569341 succeeded at source 5ee048a. The five Python runner regressions passed in that job too.
* Final Windows full run: **60 suites, 443,102 checks passed**, no failed summary lines, process exit **0** (`cli-final-1.txt`). Its shim preserve walkthrough reported **274 / 0 / 0** internally; this is distinct from a native Studio run.
* Early exploratory runs read some files while fixes were being developed. Their two/one failures were tests expecting Saved after deliberately submitting bad-slot records. Those tests now verify refusal and valid-replacement recovery. They are **not** final verification or a v51 baseline run.

New service regression sends a valid rest, stores it, submits an oversized rest through the real SaveService, checks the client receives `rest_refused`, checks earlier backend bytes do not change after heartbeat, and recovers with a valid replacement. This uses the in-memory backend, not Roblox DataStoreService.

## Native and manual evidence

The first two local Studio opens crashed with `FatalRuntimeError (RSL - panic: ...-Manager,49)` before gameplay verification while virtual memory was nearly exhausted. After closing completed audit Studio sessions, a clean session opened the candidate and matched all **215/215 source fingerprints**. Prior v51 native **274 pass / 0 fail / 0 skip**, and its rare fixture **14 checks per tier**, remain evidence for v51 only. They must not be relabelled as results for the candidate.

The final candidate then passed its foreground native full-preserve self-test: **274 pass / 0 fail / 0 skip**, completed `2026-10-22T04:00:46.145Z` (`native-final.txt`). Before Play, the isolated local place matched all **215/215** sources at commit 5ee048a and evidence c7af2726574c44cc. This run includes the automated region, movement/recovery, feeding and starvation checks; it does not replace an exhaustive manual playthrough. No release was published.

Its short post-traversal sill sample was **285 frames, 17.6 ms mean (57 FPS), 32.3 ms worst**. The changed readiness path cannot be credited with that result: viewport, memory pressure and background load differ from earlier v51 receipts. The eight paired scene benchmarks remain pending.

The candidate still needs a controlled low-tier comparison, manual save-status inspection, matching scene performance captures, then a published-client session after any release. A desktop emulator can check touch layout; it cannot establish physical-phone performance or actual controller ergonomics. The source package and generated release XML are separate from `Windowsill-foundation-native-review.rbxl`, a local review-only copy with SelfTest enabled; never publish that debug copy.

Manual checklist still to establish:

* Normal hatch to both 7/10 moults, adult/mating/eggs/next generation; six predator/hunger endings; repeat mode boundaries in Easy/Free.
* Keyboard, controller and touch for every action; device switching while held; prompt matches real binding. L1 creep/contextual lock, L2 run, R2 Focus remain standing decisions.
* Collision/camera sweep in both tiers through walls, cans, Crack, leaves, doors and region seams; creature feet/grapple/held prey; mesh alignment and z-fighting.
* Old schemas and world revisions, corrupt/newer/partial saves, throttling, abrupt disconnect and overlapping joins; verify no seeded result rerolls. Unsafe phases should refuse checkpoints according to the current contract, not resume arbitrary mid-jump states.
* Reduced Motion for every relevant animation, large captions, sound grants/playback, hunger contrast, touch target sizes and camera comfort.
* Thirty-minute error/warning and memory trace, physical-device performance, published DataStore persistence. Log asset IDs for real failures and do not infer audibility from a Sound instance existing.

Shim limitations: axis-aligned collision, no physics/gravity/streaming/DataStore, permissive Enum/WaitForChild behavior, estimated text sizing, no-op disconnect/wait paths. Existing suite passes must be interpreted within those limits. Native test specifications are not automatically run by the CLI bundler.

## Repeatable commands

From `roblox_port`:

```text
python tests/run.py path/to/luau
python -m unittest discover -s tests -p test_runner.py
python tests/run.py path/to/luau ../../docs/audit/probe.luau
python tools/build.py path/to/rojo
```

Check each process exit **and** failed summary lines. Any final source change invalidates earlier full-run evidence for that source snapshot. Keep receipt IDs distinct from published place versions.
