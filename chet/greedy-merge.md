# Greedy merging: feasibility result

**Stop at the feasibility gate.** Even an intentionally generous upper bound falls below Nathan's required 10% reduction. No runtime merge pass was added and nothing was published.

Branch: `codex/greedy-merge`. Baseline branch: `codex/v51-rare-sightings`, commit `a8ef989504c712889f21e74a798679aef213df8a`; runtime `14e60991c785c4293c3560e6d8b7ecded7e7ac75`; evidence `d9ddc5e0ed43d301`. The last previously verified publication is v51 / place 140. A fresh Studio edit copy reports version 141 and matches all **215/215 production source fingerprints** to that same runtime; an edit version alone does not establish publication. The foundation audit was parked on `codex/life-retirement` at `a6146c9`, with its unresolved issues recorded there.

## Counts and maximum possible reduction

The read-only exporter evaluated both detail tiers for **1,383 regions, backdrop zones and near-detail patches**. These are all seeded record lists across the preserve, **not parts held simultaneously by a client**. LookStream budgets and streaming still limit what is live. Persistent sill decor and every walkable/collision part are outside this count and outside the proposal.

| Scope | Tier | Records before | Optimistic maximum removed | Optimistic reduction |
|---|---|---:|---:|---:|
| All streamed record lists | Full | 109,151 | 320 | 0.29% |
| All streamed record lists | Low | 9,073 | 158 | 1.74% |
| Excluding near-detail patches | Full | 10,005 | 320 | 3.20% |
| Excluding near-detail patches | Low | 2,265 | 158 | 6.98% |

The second pair ensures that the many mostly unmergeable grass/litter patches do not hide a larger opportunity in the main regions. Both scopes remain below 10%.

## Why this is a generous bound

The estimator compares color components and every requested material/visibility key. It admits only records with no shape, rotation or dew. Within each region and key, it joins all touching or overlapping bounding boxes into connected components using a 0.001-stud tolerance. It then pretends each entire component could become one box.

That is more permissive than a legal merge: it includes corner-only contact, partial-face contact and nonrectangular unions. It also ignores the extra restrictions for names, animation and material grain. A correct implementation cannot join different components without adding empty volume. Thus the reported savings overestimate what the requested exact-solid mesher could safely achieve. They are not actual merged counts.

Only 1,511 full-tier and 451 low-tier records pass even the basic eligibility filter. Most of the natural drawn world uses shaped or rotated pieces. The few remaining axis-aligned matching blocks are usually separate objects.

Source checks identified the sash names read by HutLife, Motes/Shafts and Dew used by DayLight, FullOnly filtering in WorldDetail, and the physical-region name lookups used by WorldShadows. An implementation would require further exclusions; none were relaxed to inflate the result.

## Evidence and verification boundary

`docs/verification/greedy-merge/estimate.json` contains every region's counts. `records.txt.gz` preserves the exact exported records, with hashes in `baseline.json`. The exporter completed with exit 0; the estimator also completed successfully and reproduced its counts from the compressed evidence. The unchanged production/test inputs still compute the exact baseline evidence id. No golden data, source module, test pin, save format, lighting, camera, movement or walkable box was edited.

No runtime mesher means no changed-picture comparison or performance improvement is claimed. Full/low native profiling, device emulation, screenshots and the full game regression suite were not rerun for this analysis-only stop. The earlier source-verified native smoke is diagnostic evidence, not a paired FPS benchmark. The broader audit's full comparative matrix remains incomplete.

Reproduce from the repository root with the existing Python/Luau runner:

```text
python roblox_port/tests/run.py PATH_TO_LUAU docs/verification/greedy-merge/export-records.luau
python docs/verification/greedy-merge/estimate.py
```

For the first command, pass the exporter as an absolute path and redirect stdout to `docs/verification/greedy-merge/records.txt`; the runner resolves named files relative to its tests directory. Without that raw file, the estimator reads the committed gzip capture.

## Next direction

Keep the existing organic shapes and dense habitat. Do not spend a runtime merge/cache cost for this small upper bound. A later static-mesh batching experiment would need its own measured case and visual comparison; this study provides no evidence to begin the optional mesh replacement step. Terrain remains a separate distant-backdrop question. Continue controlled profiling and the unresolved foundation fixes before expanding systems.
