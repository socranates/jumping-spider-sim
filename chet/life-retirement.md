# Chet handoff â€” acknowledged New Life retirement

Branch `codex/life-retirement`, runtime `5cf7b4c0f212082342574763aaf5b19e00c4e323`, evidence `b3b1a047e958d966`. Unpublished; live v51 / place 140 unchanged.

New Life now retires its selected online rest through a versioned marker, preserving the old checkpoint as backup, and acknowledges only a confirmed write. New rests wait for that acknowledgement and carry the acknowledged life identity. Stale messages, lost replies, rapid New Life choices and lock-reacquisition races are covered. Other slots remain unchanged. The confirmation wording changed to match this behavior.

Schema 1 migrates without changing its checkpoint. Schema 2 adds retirement markers and checksummed life metadata; older readers preserve it as newer. Compression remains independent current/backup Zstandard frames. `setRestForLife` is the explicit service API; the old three-argument `setRest` cannot cross retirement boundaries.

Read `docs/life-retirement/README.md` and current receipts. Full Windows/Linux/native runs are still in progress as of this handoff draft. Targeted tests passed 563 state / 154 client / 44 compression checks; strict clean, compile 216/216, five runner regressions pass. Do not reuse previous candidate 13ceab93a7239418's final counts for this source.

Online verification remains pending; Studio API access is disabled. The user has an Open Cloud key available, but it was not read or used. No production records were touched, and no security setting was changed.

The local native review copy contains diagnostic scripts/fixture data and must never be published. The release XML is independently generated. Continue full verification, then the remaining foundation findings and matched performance matrix; the overall optimization goal is active.
