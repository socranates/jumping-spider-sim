# Chet handoff — full-preserve save storage

Candidate branch: `codex/save-compaction`; runtime source `133261b5b175d44211d7ddd607b272e9694e72f3`; evidence `13ceab93a7239418`. Built on the prior foundation audit. **Not published**; live v51/place 140 remains the baseline.

## Result

Full preserve checkpoints no longer have to fit the old 262,144-character raw cap. The new server codec stores the complete current checkpoint and its backup as independent Zstandard/Base64 frames. Existing checksums, graph identity, references, actor values and RNG state are preserved. Older raw values read normally; old servers see the new schema-2 wrapper as newer and preserve it. Compression failures refuse the update. Corrupt current frames can expose an independently valid backup for read-only recovery without overwriting the damaged record.

Storage is capped at 1.5M characters including backup and headers. Expansion is bounded to 6M bytes per core / 12M combined and checked against actual frame metadata before decompression. Expanded checkpoint validation is 5M characters / 600K values / depth 24. Progress values are unchanged.

No movement, camera, creature, feeding, menu, settings or lighting rules changed in this branch. Do not fold the diagnostic fixture scripts into a release.

## Evidence

- Windows and Linux each: **62 suites, 443,158 checks passed**. Windows terminal exit 0 recorded. Linux run 39722478961 succeeded on exact runtime source.
- Final local compile **216/216 at -O0**; strict analysis clean; five Python runner regressions pass.
- Boundary suite 44; real SaveSession/backend round-trip suite 11. These CLI tests inject a reversible codec and do not benchmark native Zstandard.
- Native final codec, full scene active: a current rest plus independent backup expands to 4,554,368 canonical characters and stores as **450,376 native JSON characters**. Exact values, canonical checksums, both checkpoints, 1,009 numeric precision cases and expansion-bomb refusal passed.
- A separate actual-engine/raycast capture initializes synthetic ecology in all 233 regions: valid checkpoint **2,276,508 canonical characters**, current-only storage **226,962 characters**. This is not a long played player save.
- Foreground native preserve self-test: **274 passed / 0 failed / 0 skipped**, exact 216/216 source fingerprints. Completed 2026-10-22T05:07:03Z. No CreatorError or script timeout in this native session.
- Real API persistence: first uncached read of a unique `R_chet_compaction_*` key in **WindowsillTest_v1** was refused because Studio API access is disabled. No writes occurred, no production records were accessed, temporary test modules were removed. The user has been asked to enable the setting manually if desired; agents must not automate security settings.

Read `docs/save-compaction/README.md`, `receipt.json`, and the raw logs for precise boundaries. Earlier whole-envelope experiments and interrupted tests are explicitly historical. `verify.py` checks source fingerprints and evidence and refuses to label incomplete gates as passed.

## Next

1. Offline/native verification is complete; receipts and source guard are preserved.
2. Once manually enabled, run the guarded test-store fixture with fresh uncached reads; then verify actual client/server rest and rejoin, future actor traces and larger played saves. Primitive API verification does not replace the client protocol test.
3. Keep publication pending until those gates and a clean release artifact are reviewed. The local review copy has SelfTest enabled; never publish it.
4. Address the next audit findings separately: explicit legacy-world migration, acknowledged New Life identity, safe foreign-lease Continue UX, deterministic route activation, caption projection, and the matched scene/memory benchmark matrix.
5. Resume the remaining rare sightings after the foundation is dependable.

Nathan also supplied an animated-plant shader video. Its title was retrieved, but no transcript was available and it was not watched. `PLANT-REFERENCE.md` records what is known and Roblox-specific follow-up. Preserve dense close vegetation, stable walking surfaces, Reduced Motion, and the liked lighting.
