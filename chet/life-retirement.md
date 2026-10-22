# Chet handoff — acknowledged New Life retirement

Branch `codex/life-retirement`, runtime `5cf7b4c0f212082342574763aaf5b19e00c4e323`, evidence `b3b1a047e958d966`. Unpublished; last verified live baseline is v51 / place 140.

New Life now retires its selected online rest through a versioned marker, preserving the old checkpoint as backup, and acknowledges only a confirmed write. New rests wait for that acknowledgement and carry the acknowledged life identity. Stale messages, lost replies, rapid New Life choices and lock-reacquisition races are covered. Other slots remain unchanged. The confirmation wording changed to match this behavior.

Schema 1 migrates without changing its checkpoint. Schema 2 adds retirement markers and checksummed life metadata; older readers preserve it as newer. Compression remains independent current/backup Zstandard frames. `setRestForLife` is the explicit service API; the old three-argument `setRest` cannot cross retirement boundaries.

Read `docs/life-retirement/README.md` and current receipts. All offline verification gates have passed. Final native source guard matched 216/216 before Play. The final native codec/local-memory retirement probe passed at 05:30:50Z; the complete preserve self-test passed 274/0/0 at 05:40:09Z. Linux also passed 62 suites / 443,213 checks. Windows completed with exit 0, also 62 suites / 443,213 checks. Targeted tests passed 563 state / 154 client / 44 compression checks; strict clean, compile 216/216, five runner regressions pass. Do not reuse previous candidate 13ceab93a7239418's final counts for this source.

Studio API access was enabled at Nathan's explicit direction. The real-store test reached save/retirement and independent backup recovery, then failed its final refusal-status assertion. A narrow native probe confirmed that `UpdateAsync` can log a transform error while its outer `pcall` reports success with nil. Stored JSON stayed unchanged. This is unresolved A12; online verification and real client rejoin remain incomplete. The user has an Open Cloud key available, but it was not read or used. No production records were touched, and the only setting changed was the explicitly requested Studio API access.

The local native review copy contains diagnostic scripts/fixture data and must never be published. The release XML is independently generated. Continue online verification, then the remaining foundation findings and matched performance matrix; the overall optimization goal is active.

The broad audit is parked for the new greedy-merge feasibility study. See `docs/audit/PARKED-FOR-GREEDY-MERGE.md`; keep this save candidate unpublished.
