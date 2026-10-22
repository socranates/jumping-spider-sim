# Isolated native Part allocation control

Prepared experiment; **no native result yet**. This investigation follows `docs/memory-trace/RESULTS-v1b.md`, where repeated habitat visits had stable live counts/client-GC low points but rising BaseParts/Instances/Signals category counters. That observation does not identify the cause.

This place contains exactly one authored LocalScript and no Windowsill game source, persistence, third-party assets or character. A source/attribute/count guard must pass before Play. A fresh Studio process and fixed viewport/focus are required; wait for the current full Windows CLI run to finish before measuring. Never publish this diagnostic.

Protocol fixed before native data:

1. Wait ten seconds for the Play viewport to settle; monitor focus loss and rendered-frame activity thereafter.
2. Create 1,000 anchored, non-colliding/non-touching/non-queryable ordinary Parts. Hold the same batch for 30 seconds, sampling every five seconds.
3. For 60 cycles, destroy the previous batch folder and build a new one; allow at least one second per cycle. Create at most 100 Parts per heartbeat. Hold at most one 1,000-part batch; retain no arrays of destroyed instances. Sample at cycles 0, 5, …, 60.
4. Destroy the final batch, set its reference to nil and wait 30 seconds with no fixture Parts. Keep normal GC; do not force collection. Sample every five seconds.
5. Require 61,000 created / 61,000 destroyed, zero live fixture Parts, correct phase durations, sufficient active render time and no focus loss.

Record total memory, client gcinfo, engine instance count, and the BaseParts/Instances/Signals/LuaHeap/Internal/GraphicsParts tags. Every bounded JSON record has a byte length, Adler checksum and sequence; retain the original engine lines. The output does not store prior samples in the client. The collector rejects missing/changed/reordered data, a different source/configuration, incomplete phases, inactive clocks or bad part balances. Completed output has 29 records.

Predeclared investigation screen: a BaseParts increase during churn over the stationary endpoint must exceed **max(8 MB, four times positive stationary-phase growth)** to count as an isolated growth observation. Report whether at least 80% remains after the 30-second empty quiet phase. These thresholds are triage, not a universal budget or a leak verdict. Retain every other category even if this screen is quiet; do not change thresholds after seeing data.

An isolated reproduction would show that this Studio counter behavior does not require Windowsill code. It would not prove an engine bug, absolve the game of all leaks, establish standalone-client behavior, identify a specific retaining reference or demonstrate an FPS improvement. No reproduction would also be inconclusive: this omits meshes, attributes, streaming, weather, sound, game scripts and the real traversal pace. Native allocation snapshots and a matched in-game stationary/churn comparison may still be needed.

Official references: [Stats](https://create.roblox.com/docs/reference/engine/classes/Stats), [memory categories and snapshots](https://create.roblox.com/docs/studio/optimization/memory-usage), [performance investigation](https://create.roblox.com/docs/performance-optimization/improve). These distinguish client Lua heap, instance counts and engine categories; none turns a category slope alone into proof of a retaining-code bug.

Prepared v1: `C:\Users\natha\claude-xfer\Windowsill-part-churn-v1\Windowsill-part-churn-control.rbxlx`, SHA-256 `e2391f3d640306229068c85093d6310e86bd63ef06681eb3f4e6992c2e3976b4`. Probe SHA-256 `80625effce0353781ce1f1ff17cc91f12a33fdcb10382da5effa98a0d756ca67`; unoptimized compilation passed. `build.py` freezes a copy of the probe, checks the exact authored script set and writes the native guard/manifest. The production game and its running full-suite input bytes remain unchanged.
