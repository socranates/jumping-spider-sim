# Hut path ground repair

2026-10-24. Work on codex/verified-integration; no place publication.

## Reproduction before repair

The six passing northern/meadow/pond routes in README.md did not cover the
hut's outer paths. A separate four-route native exercise found that the
apparently grassy south, east (both sides), and north shoulders had neither
a walkable region nor physical ground. The spider wrapped under the thin
gravel slab and continued upside down instead of crossing onto grass.

perimeter-before/ retains original bounded native output and parsed records.
Run1792830419552 attempted all four walks; all four failed to reach their
target after65 seconds. All ended attached with up=(0,-1,0), atY=-87.31,
with no loading, reset-home event or focus loss. No tap hop was attempted
after a failed walk. The failed completion remains failed. There were zero
CreatorError records and nine CreatorWarning records. Before/after276-source
guards passed; the temporary editor was stopped and closed without saving,
and the immutable model hash still matched its manifest.

Model SHA256:25a3beffb3c58d5fd5978a902dcfc53476863ab8e53a87b507af31924b1c8215.
Local stage:C:/Users/natha/claude-xfer/Windowsill-hut-perimeter-full-before1.
The retained native.json's generic limits sentence says "Six authored
arrivals" because the collector text had not yet been generalized; the four
actual route records and failed completion are authoritative. The later
collector derives that label from the selected group.

The added compact-layout checks independently reproduced all eight missing
near/far shoulder points:COMPACT passed=295 failed=8 regions=233. That is the
observed pre-repair CLI result, not a newly rerun baseline qualification.

## Repair and guardrails

Verge.luau adds three bounded strips: the south apron toZ407, the east wall
toX650, and the north approach toZ-256. They meet the existing garden and
path surfaces at the existing ground height. The added shoulders use the
existing seeded litter, clover, grass and prey authoring. The old rectangles
are authored first and unchanged; new ground stops at the building's outer
faces and existing landmark footprints retain priority.

This adds33 ground regions,233 to266. It does not move old landmarks,
change a save schema/revision, alter controls, camera or lighting, fill the
pond, or make every backdrop surface walkable. Existing render budgets
(1500 full/500 low) are unchanged. Added regions still have data/collision
cost; no FPS improvement is claimed for a ground repair.

compare-ground.py runs the current authoring twice under the ordinary CLI
shim, substituting only the pre-repair Verge loader from8ce079f0 in the
baseline. ground-equivalence.json records identical generated map,
physics-piece and decoration data for all233 existing region IDs. The33
added verge regions contain304 collision pieces. Raw generated output was
hashed; per-existing-region fingerprints and both program hashes are retained.
This proves additive generated data, not native/save-store behavior. The
helper initially exposed an observer formatting mistake (Lua assert returned
both JSON and nil to print); assigning its first result before printing fixed
the observer. It did not change game data or relax the equality check.

The focused geometry check now reportsCOMPACT passed=442 failed=0 regions=266,
including old-save restoration and checks that no infill soil enters the hut
footprint. The native observer and collector now also require upright
attachment at these flat-ground endpoints; merely clinging beneath a slab
cannot qualify as success. Route inputs/targets are unchanged.

## Full-run findings and current verification

The first ordinary79-suite Windows run completed with exit1. Its original
full-cli.txt and failed-full-receipt.json remain in ground-checks/:24 failed
top-level assertions across SELFTEST_PRESERVE and LIVING_WORLD. It is not a
passing qualification. The other77 suites completed without top-level failure.

The failures exposed three separate issues. An assertion still expected233
regions; a coarse "everything is north of the hut" guard rejected legitimate
south/east shoulders; and the longer regional tour exceeded the old600-second
global self-test ceiling (the previous233-region run already took571.9 s).
The count now explicitly expects266, the exclusion check tests actual soil
overlap with the building/pond, and the bounded total allows2 s per additional
region. Each regional visit explicitly holds for1.2 s plus readiness. All
individual readiness/save/return deadlines remain unchanged.

There was also a real render-policy regression: after touring the new ground,
hysteresis retained optional room detail that crowded out the full hut view
at the sill. inspect-plan.py reproduced full->low there after the tour;
fresh plans still matched. LookPlan now reserves the hut at home before
optional scenery, within the existing budget. The compact regression was
red445/1 and now passes446/0 at both tiers; existing LOOK passes1442/0.
No budget was raised and no scenery record/lighting setting was changed.

Current normal/test exports are evidence e7b268a11f55febe with273 sources.
All273 compile, strict exits0, runner infrastructure5/5, compact446/0,
living_world4150/0 and rest_storage14/0 have completed. The all-regions
storage exercise captures3,195,572 canonical characters and names266 regions.
The current Preserve self-test is still running. final-checks/ retains current
steps as they finish; look-check.txt is the final tool-output chunk from the
completed LOOK run, not a claim to its entire console stream.

The original full attempt used verify-ground.py with the ordinary current
Windows runner. verify-final.py runs the affected current Windows suites and
static/export checks separately; it does not turn the prior failure into a
green full run. Full current Linux CI and guarded native full/low routes
remain separate required cohorts. The older integrated-release/run-cli.py adapter
refused this tree at its eager-loader assumption before executing a suite;
it predates the current runner's lazy loading and is not used here.

The initial after1 models were compiled before the render-policy fix and
were never played. The full editor's preguard ran and it was closed without
saving. They are superseded preparation artifacts, not native pass evidence.
Guarded native full/low after-repair routes are still required. Older
northern-route and30-minute results retain their original source cohorts.
They do not establish native execution of this new ground or whole-map
clipping coverage. The production build and online saves remain unchanged.
