# Proposed next chunk: bounded, lossless rests and legacy migration

Baseline v51 / place 140 / source `14e60991c785c4293c3560e6d8b7ecded7e7ac75` / evidence `d9ddc5e0ed43d301`.
Audit candidate source `5ee048a791da5fa4f5b99aac53d9769bcd358845`, evidence `c7af2726574c44cc`. This is a proposal; no codec or migration below is implemented.

## Start with a lossless transport representation

Measure the current ObjectRecord by bytes attributable to keys, reference tags, actor values and repeated strings. Prefer a versioned compact encoding of the **same** graph first: string/key dictionaries, class/ref dictionaries, and flat tuples instead of repeated `{key,value}` objects. Keep full numeric precision and graph identity. Decode into the existing validated record and validate before committing live state. Do not omit unknown fields silently.

Do not assume every perch graph can be reconstructed from a seed. `PerchGraph.add` adjusts positions and validity through engine raycasts, and `PreyDirector.new` tests outgoing flights. Occupants and reservations are mutable too. A regenerated graph can differ from the saved one. Removing those fields requires a separate proof and an explicit format rule; a dictionary codec can preserve them without that risk.

Acceptance should include the entire 233-region stress world, active/escaped/held prey, reserved perches, actor RNGs, all modes, a long played life, old-world fixtures and a second save kept as backup. Check both canonical representation and native HttpService JSONEncode/storage representation; keep substantial room below the documented per-key limit. Do not merely raise MAX_REST_CHARS while leaving node bounds, backups and expansion cost unexamined.

Keep both decoders during migration. A newer transport/envelope must classify as newer on old builds, not appear as a corrupt current payload. Writes should migrate only after a successful validated read. Corrupt/newer records stay preserved. Bound dictionary sizes, tuples, references, expanded nodes, string lengths and total encoded bytes before expensive graph construction; fuzz malformed payloads and expansion attacks.

## Migrate historical worlds deliberately

The supplied-world probe produced a valid 53,882-character test-garden rest which preserve rejects at `garden.bed_a`. Validate legacy ecology against its recorded world/version first. Choose an explicit transfer policy and refuge placement; do not guess that all old actors can be mapped onto current geometry. Preserve the original envelope/backup as recoverable data. Native fixtures must show which state is carried across and which state has no equivalent.

## Then address identity and session UX

Add an acknowledged life-generation/tombstone message if starting New Life should retire a previous online rest immediately. Tie queued writes/rests to that identity so a late prior-life response cannot replace it. Offer read-only saved rests during a foreign lease if safe, without allowing writes until ownership is acquired. Quarantine bad slots independently rather than freezing otherwise valid progress, while retaining the original bad data.

## Required receipts

* Before/after sizes for every probe stage and worst-case payload plus backup, measured with the actual encoder.
* Byte-equivalent decoded actor graphs, equal RNG state and identical future traces after round-trip under the same engine/world inputs.
* Schema 1/2/3 checkpoints and both current/legacy map fixtures, unchanged originals, corrupt/future envelope refusal.
* Two sessions, delayed responses, rapid New Life/leave, throttled DataStore, shutdown during a pending write and quick rejoin.
* All CLI suites with meaningful failure exits, strict analysis, -O0 compilation, foreground native self-test and real online restore.

Keep this independent of creature additions, movement/camera changes and the proposed SpiderClient refactor. The rare-sightings roadmap resumes after persistence is dependable.
