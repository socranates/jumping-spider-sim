# Ordinary workload measurements and shared scenery generation

Private work; no production activation or publication. This extends the exact
56-target ordinary-startup candidate with read-only timing probes and a yielding
memory backend. Normal Persistence and Composition run; ordinary title/menu,
full-detail lighting, cat and other creatures remain enabled. No SilkPlayback,
old test runner or actual DataStore access. Models are unbound and must never
be published. The preceding online storage proof has its own scope.

## Startup attribution

The probe starts before the actual client script's module loading and world
construction, not after rendering begins. It observes Heartbeat intervals,
script sections, engine counters and synchronous server-method boundaries.
Counter meanings follow Roblox's [Stats reference](https://create.roblox.com/docs/reference/engine/classes/Stats).
Engine values can describe a preceding frame, so gap records retain adjacent
samples; do not add overlapping engine/script counters or claim causal proof
from a single counter.

Baseline attempt3 server methods: modules 16.1ms, Decor 16.6ms, hidden-piece
planning 3.8ms, physical world 64.3ms, authored save templates 30.7ms. Those
finished before the measured client began. Client WorldClient.new spent3.99s
awaiting/constructing its initial world; all remaining client construction
after that took about185ms. Its largest pre-render Heartbeat interval was
1.677s, engine FrameTime reached2.638s, whereas sampled rendering CPU peaked
7.2ms, GPU0.64ms and physics0.90ms. There was no live simulation yet. This
bounds the pause to client arrival before ordinary rendering; it does not
establish which replication, engine, Studio, driver or OS job caused it.
**No startup-gap fix is claimed.** Memory was constrained on this7.6GB laptop;
no paging measurements or published-client comparison have established a cause.

## Scenery change

Measured garden arrival spent35.86ms in LookStream.replan and9.83ms in work;
pond arrival spent23.58ms in replan. LookPlan.records formerly called the same
seeded Region.decor generator independently for low/full/far views, retaining
duplicate record tables. `look-plan.luau` derives the same views from a shared
source. This changes no part, material, colour, collision, distance, LOD budget,
lighting, creature behavior, save rule or scenery density.

Full-tier equivalence:2167 checks across267 regions in both worlds, all record
fields and warm identities preserved;801 generator invocations become267.
Low-tier tests:1602 checks across267 regions preserve low/far records with one
generation and require an additional generation only when full detail is later
requested. Unused full-detail records are not retained in the low-tier cache.
This is code-level tier verification, not a phone performance test.

The first simple full-source cache was discarded before native execution
because it would retain unnecessary full-detail records on phones. Its source
and static-only model attempt4 are retained. The final candidate is tier-aware.
Final cache-check3 passes7338 checks:2167 full-tier equivalence,1602 low-tier,
2077 worldmap,43 actual streaming-client,1154 Preserve and295 compact layout.
The same part budgets and streaming disappearance/re-entry holds pass. The
candidate compiles/type-checks with all276 model sources. These are relevant
geometry/controller regressions, not a repeated full save-service suite.

## Matched native comparison

Baseline attempt3 run1792808267392 and optimized attempt5 run1792809011121 both
complete the same ordinary menu/New path, live30s station/garden/pond samples,
explicit habitat arrivals and save cleanup. All source hashes are identical
except `ReplicatedStorage.Shared.World.LookPlan`. The final model SHA is
`ec9c9362e734d05a80e32550c9f927f98ad7ca53834b10ba12f96550093b16cd`.

| Observation | Baseline | Shared cache |
| --- | ---: | ---: |
| Garden arrival replan |35.86ms|28.88ms|
| Garden arrival render callback |59.13ms|52.30ms|
| Pond arrival replan |23.58ms|21.00ms|
| Station render callback mean |5.18ms|5.72ms|
| Garden render callback mean |5.50ms|5.59ms|
| Pond render callback mean |5.32ms|5.31ms|
| Station frames over50ms /30s |1|0|
| Garden frames over50ms /30s |3|3|
| Pond frames over50ms /30s |1|1|

These are one pair of local observations, not a statistically established
general FPS gain. Steady means are mixed. The deterministic reduction in cold
generation and duplicate full-tier records is established; observed arrival
planning improved, while scenery density/lighting/behavior are preserved.
Whole-frame outliers outside the render callback remain. Initial pre-render
Heartbeat worst actually varied from1.677s to2.376s, so **the startup pause is
not fixed** and should be investigated on the playable client before a general
release conclusion. Game simulation is held during those initial waits.

`qualification.json` and `verify.py --check` bind complete raw event JSON,
matched immutable model/XML source hashes, the single game-source difference,
both scene/simulation/cleanup completions, the current candidate/derivation and
all five passing regression cohorts. The earlier online startup qualification
still verifies independently; there was no storage-logic change. Owned Studio
and CLI jobs are stopped. No production activation, main merge, publication,
OneDrive or Godot modification occurred.

## Retained attempts

- Attempt1: strict analyzer caught a nonexistent spawn.up field in the observer
  and a misplaced strict directive; never played.
- Attempt2: native partial measurement captured station/garden/pond, but its
  arrival samples ended before the world's next update. The pond's30s sample
  included0.18s of collision/loading hold and correctly failed the probe's
  live-simulation criterion. It is not a passing complete baseline.
- Attempt3: corrected actual destination and complete-look readiness, explicit
  arrival samples, extra server timing and look-method timings. All scenes and
  save cleanup passed. World code changed only through timing wrappers. Model
  SHA `dbcb430bad64192d20b4f3a4955c22fcc4348d4e867224b77134d1a41377bffd`.
- Cache-check1: fixture attempted to wrap the frozen Region export; refused
  before tests. It now uses an isolated shallow clone with the actual generator.
- Cache-check2: the initial full-source cache passed equivalence and existing
  worldmap2077/world-client43/Preserve1154/compact295 checks. This does not prove
  the corrected low-tier policy, which has its own subsequent cohort.

All models compile276 sources. Successful strict checks retain observer-only
indentation lint warnings. Complete JSON is collected per bounded output line;
the collector refuses truncation. Sample durations, render callback costs and
engine frame times are separate observations. Automated transport places the
spider at authored spawns for habitat samples; this is not a manual traversal,
controller/comfort, phone or published-server qualification.
