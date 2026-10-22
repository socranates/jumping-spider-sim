# Full-world rest compression — candidate verification

Branch: `codex/save-compaction`, based on audit `f1dd675`. Runtime source: `133261b5b175d44211d7ddd607b272e9694e72f3`; build evidence: `13ceab93a7239418`. **Unpublished.** The existing live place remains version 140 (v51). This work does not complete the broader optimization/dependability audit.

## What changed

The old 262,144-character rest limit rejects an initialized 233-region preserve checkpoint. The candidate retains the complete checkpoint, references, actor state, perch graphs and RNG fields, and compresses the current record and its backup independently using Roblox EncodingService Zstandard level 3 and Base64. Independent frames allow backup recovery if the current frame is damaged.

`RestCompression` is server-only. `DataStoreBackend` decodes R_ rest values before callbacks and compresses accepted replacements inside UpdateAsync. Progress keys are unchanged. Legacy raw envelopes remain readable; schema-2 wrappers are opaque/newer to older readers. Unknown outer schemas or fields remain opaque. Failed decode/encode cannot replace stored data. Replayed update callbacks are tested. Service/codec initialization failures keep saving unavailable.

Limits remain explicit: 5M canonical checkpoint characters / 600K values / depth 24 for validation; 1.5M stored characters including both frames and headers; 6M expanded bytes per core and 12M combined. Declared expanded sizes must match actual Zstandard frame sizes before decompression. The checksum remains the original canonical checksum; native JSON serialization is used only inside the compressed storage layer.

## Current evidence

- Linux CI: **62 suites, 443,158 checks passed**, compile and strict analysis clean; five Python runner checks passed. Run [39722478961](https://github.com/socranates/jumping-spider-sim/actions/runs/39722478961), exact source commit above. Receipts: `ci-final.json`, `ci-all-suites.txt`.
- Windows full run: **62 suites, 443,158 checks passed**, process exit **0** observed. Receipts: `cli-final.txt`, `cli-final-process.json`.
- Final Windows source compilation: **216/216**, `-O0`, with per-file SHA256 in `compile.json`. Final strict analysis: `strict-independent.txt`.
- Boundary checks: **44**, including expansion bounds, future/unknown wrappers, replay and independent corruption recovery. Real SaveSession/backend integration: **11**, including leave/rejoin and read-only recovered backup. CLI uses an explicitly injected reversible adapter, not a claim about native compression ratio.
- Native Roblox full-scene format probe: **4,554,368 expanded canonical characters → 450,376 native JSON stored characters**, current plus independent backup. Exact equality, both Checkpoint validations, old-reader refusal, 1,009 finite-number precision cases and expansion-bomb rejection passed. `native-full-scene.txt`. Source guard matched **216/216** modules and the evidence ID above.
- Actual-engine physics capture: initialized synthetic ecology in all **233 native regions**; valid checkpoint **2,276,508 canonical characters**, current-only stored value **226,962 characters**. Complete 454-chunk capture assembled and parsed; SHA256 and scope in `native-engine-capture-receipt.json`. This is synthetic ecology using engine raycasts, not a long played user life.
- Foreground native preserve self-test: **274 passed / 0 failed / 0 skipped**, source fingerprints 216/216; no CreatorError or script timeout in the native session. This uses a separate local review copy and does not establish real API persistence.
- Real test-store API probe: **blocked before any write**. The first uncached GetAsync for a new synthetic key in `WindowsillTest_v1` was rejected with `StudioAccessToApisNotAllowed` at 2026-10-22T04:53:36Z. No production store was accessed. API access requires a user security-setting action. `online-store-attempt.json` records this boundary.

Native encode/decode stages took about 252/257 ms in the full-scene diagnostic. Canonical validation of full records takes roughly 1–2 seconds per stage. The initial aggregate diagnostic hit the script watchdog because it chained many assertions without yielding; the profiled diagnostic yields between assertions. These timings are local laptop diagnostics, not controlled FPS gains or proof of an uninterrupted live save protocol.

## Remaining gates

1. Windows full run completed on unchanged source; retain its exit receipt and source fingerprints.
2. Foreground native preserve self-test completed: **274 passed / 0 failed / 0 skipped**, 2026-10-22T05:07:03Z, exact 216/216 source guard. `native-final.txt` and `native-errors.json`. Diagnostic helper scripts/fixtures must never be published.
3. If the user enables Studio API access, repeat the uniquely named test-store probe with uncached reads, exact current/backup restoration and non-overwrite checks. Never probe production records.
4. Exercise actual client/server rest, rejoin, moving actors/perch reservations and equal future seeded traces; measure protocol latency on larger played lives.
5. Continue the audit: legacy-world migration, New Life identity, overlapping-session Continue UX, route activation timing, caption projection and matched performance/memory scenes remain open.

## Historical evidence

`native-experiments.txt`, `targeted.txt`, `strict.txt` and `cli-before-independent-backup.txt` predate the independent-backup revision and are not final acceptance results. The earlier whole-envelope implementation and dictionary experiment are superseded. `native-probe.luau` is the original cumulative diagnostic; `native-profile.luau` is its yielded successor. Local probe places in claude-xfer are diagnostic only. The production build contains none of their helper scripts or fixture values.

Official API references: [EncodingService](https://create.roblox.com/docs/reference/engine/classes/EncodingService), [HttpService](https://create.roblox.com/docs/reference/engine/classes/HttpService), [DataStore caching](https://create.roblox.com/docs/cloud-services/data-stores/versioning-listing-and-caching). Immediate verification reads use `DataStoreGetOptions.UseCache=false`.
