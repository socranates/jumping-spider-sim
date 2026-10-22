# Historical-world compatibility follow-up

Read-only source analysis of the final slot-isolation candidate. No migration is implemented here.

`Checkpoint.check` recognizes a rest from another world and relaxes its player-position lookup. However, `checkWorld` still validates every `roots.garden` entry through the globally active `WorldMap.region`. A real test_garden `bed_a` population consequently fails under the preserve. `WorldMap` already caches separate maps in private `MAPS`, but its public `region` method uses the active map.

Changing only that lookup is insufficient. `Checkpoint.restore` commits the decoded garden directly into live roots and the next capture stamps the active world's id. Old garden ids would then be relabeled as preserve ecology. Shared feeding, needs and contact references also cross root boundaries, so removing just the garden entries is not a lossless migration.

The first safe design step is a pure map lookup/view selected by recorded world id, with no `WorldMap.use` calls inside validation or restore. Validation must not switch a global map while another player's server work can run. Add two-world interleaving tests proving the active map never changes.

A separate, explicit format decision must then describe how unavailable ecology is preserved without running it in the wrong habitat. An immutable dormant-world archive is one possibility to evaluate, not an accepted implementation. It needs checksum validation, bounded sizes, an explicit schema/migration path, preservation of source ecology and shared identities, and capture/restore tests showing that a second save does not lose or mislabel anything. Exceeding a size bound must refuse migration safely rather than discard populations.

Until that is complete, per-slot protection is intentional: leave the historical rest and backup unchanged; continue the notebook and healthy slots. Do not loosen SaveRest validation, silently drop ecology, reinterpret an unknown future schema, or claim old-world migration is solved by this candidate.
