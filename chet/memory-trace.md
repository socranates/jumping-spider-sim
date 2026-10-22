# Native memory trace handoff

Branch `codex/memory-trace`, based on `cdce01d`. Gameplay source is frozen at `3c8de801e5fab68598e1e5323e7f5e1c8151b0e6`. This branch adds diagnostic tools and receipts only. It does not change production game modules, publish a place, or access online saves.

The outdoor encounter reset has completed its Windows gate (63 suites, 443,469 checks, zero failures), Linux CI gate (`39761460756`, success), and source-guarded native gate (46 assertions). See `chet/outdoor-life-reset.md` and `docs/outdoor-life-reset/` for those separate receipts.

## Memory evidence

The 90-second native rehearsal completed 90.077 seconds and 29 full visits across all seven habitats. Its source guard checked all 217 scripts, persistence was disabled, and the collector verified record checksums, activity and focus. Ten collector boundary tests pass. Rehearsal evidence explicitly does **not** satisfy the long-memory gate.

At this handoff's creation, the real 1,800-second run `1792666028145` is **in progress**. This paragraph and `long-v1b-origin.json` are historical start metadata, not current liveness or completion proof. Inspect the native log and observer before taking action. Do not restart the run because a polling call times out.

* Native log: `C:\Users\natha\AppData\Local\Roblox\logs\0.744.0.7441077_20261022T104521Z_Studio_337E4_last.log`.
* Observer: exec session `52003`; output directory `C:\Users\natha\claude-xfer\Windowsill-memory-trace-v1b\long-observer`.
* Diagnostic place: `C:\Users\natha\claude-xfer\Windowsill-memory-trace-v1b\memory-long-full.rbxlx`, SHA-256 `a60ea467fb340ebea2a1165b2de0cb91f4911c85caff60cbee5e26bb8f1261c5`.
* Studio process `4428`, window `59246462`. These identifiers require fresh verification before later UI input.

Leave Studio in the foreground without screenshots or UI interactions until a native terminal record. The observer only reads the log. It does not control Studio. A timeout is not termination evidence.

After native DONE or FAIL, preserve bounded events from the observer. For a completed run, collect them using:

```text
python docs/memory-trace/collect.py docs/memory-trace/long-v1b-events.txt --manifest docs/memory-trace/manifest-v1b.json --run-id 1792666028145 --out docs/memory-trace/long-v1b.json
python docs/memory-trace/verify.py
```

The collector refuses to overwrite a result. It verifies completeness independently and binds the retained event and manifest bytes. Record failures honestly rather than editing native evidence. Then inspect matched habitat minima, category curves and population counts, and write a results note. A quiet triage screen is not proof that no leaks exist.

The workload is one continuous Free/gentle newborn life at full detail, with explicit placements and repeated 30-second habitat dwells. It is not a physical walking tour, mature combat test, phone test, standalone-client test, FPS comparison or online rejoin test. The diagnostic places must **never be published**. The earlier desktop performance matrix and animation-cache experiment remain separate evidence with mixed results.

See `docs/memory-trace/README.md` for the protocol, predeclared investigation thresholds, source construction and evidence boundaries. The broader audit remains active: legacy-world saves, foreign-lock Continue UX, deterministic route preparation, save-error presentation, pinned CI tools, startup, and native/device checks still need work.
