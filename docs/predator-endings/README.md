# Predator endings and fast-clock hunger audit

2026-10-24. Branch `codex/verified-integration`; game/test fix commit642af969.
Ordinary export evidence **597db4c421e47c5e**,273 sources. This fix is **not
published**. Private published version14 retains the preceding032b5985ac17eeb2
source cohort; production is unchanged.

## Major finding: five lethal outcomes were silently refused

The actual client calls `endLife` for the cat's paw, crab spider, robin, frog
and drowning. It already has their text, death cards and continuation choices.
`Shared/Life/LifeSession.luau:endLife` accepted only wasp, starvation, rival and
night, so the five newer causes returned false before the client could show
their ending. The separate predator-simulation/self-test checks could pass
without ever exercising that shared session boundary.

Reproduction: start Normal, invoke the real client ending handler with any of
`cat`, `crab_spider`, `bird`, `frog`, `drowned`. Before the fix the session never
ends and no corresponding card appears. The same cause is passed by each
authored lethal NPC/water branch in SpiderClient. Severity: **major correctness**.

The small fix admits those existing authored outcomes in one frozen private
allowlist. Unknown causes still have no effect; already-ended lives still
refuse another ending; Easy and Free play still refuse lethal endings. No AI,
attack reach, collision, timing, camera, save schema, lighting or golden data
changed. `before-LifeSession.luau` preserves the old gate.

## Regression evidence

`red-corrected-fixture.txt` records15 failed session assertions and five failed
real-client ending scenarios on the old module. The earlier `red.txt` also
contains a test-fixture import mistake in the client scenarios; it is retained
and is not used as client regression proof. The session failures in that first
attempt were real. The corrected fixture uses ordinary static module imports.
Process exit codes were not separately retained for these red runs; their
failed summaries and raised suite errors are explicit in the saved output.

`green.txt` passes four related suites: CONTINUING145, NATURE_CLIENT11,
NATURE28890, MEALS88, total **29134 passed /0 failed**. Session checks cover all
nine known causes, duplicate handling, summaries/lineage, subsequent lives,
both gentle modes and unknown outcomes. Real-client checks cover the five
newly admitted causes, their exact card text, duplicate refusal, the actual
Another callback and resumed play. They are CLI/shim boundary checks, not
natural NPC approach/strike or native rendering evidence.

## Unpublished native fixture

`playback.luau` uses the existing guarded matrix builder with **current ordinary
sources**, normal client ticks, ordinary menu/save admission, and the existing
isolated yielding-memory backend. It is unbound (game/place0), Studio-only,
SelfTest=false and never an upload candidate. The driver and native results
must not be mistaken for a new published build or online-save qualification.

The first two preparations failed strict typing in the diagnostic driver:
inferred heterogeneous UI module types and then the captured clock override's
nil inference. They never ran. `prepare1.txt`, `prepare2.txt` and the retained
external stages preserve those failures. The third preparation compiles and
strict-checks all276 sources, with the tool's informational registration warning.
It builds `C:/Users/natha/claude-xfer/Windowsill-life-endings-native3/Windowsill-matrix.rbxlx`,
SHA256 `fbbc951b3e754e39d4ff8b3b268ab35f722d4a6befdfb2f9c8c7f78246b9abcc`.

The five end-handler calls are deliberate boundary invocations, followed by
the real card delay, real Another choice and lineage assertions. These do not
simulate natural sensing or an unforced attack. Hunger is different: from a
normal fresh reserve and zero starvation streak, the driver multiplies only
the life clock's advance by120 and allows real client ticks to deplete needs.
It never sets energy, streak, lifeOver or the death outcome. The spider is
placed in its real Crack so unrelated predators do not end that hunger trial.
Easy availability is explicitly seeded as a setup precondition, then Easy and
Free each run three game days without meals; this is not an adult-unlock test.
Clock override, listeners and save work are cleaned up at completion.

See `native-final/` for complete closed-process events, source guards, errors/warnings
and manifest; `native/` retains the earlier pre-exit observation. Normal starvation
reached day2 at08:12, from energy0.54598/streak0 to energy0/streak12.2613,
with no meals. Easy and Free each reached day4 above their0.1 floor, alive. All
five cards and Another callbacks passed; both276-source guards, cleanup, zero
CreatorErrors and six retained style/asset warnings complete. Studio16336 is
closed and the immutable model hash is unchanged. These are fast-clock/client
boundary results, not an unforced predator encounter or a full reproductive life. See `qualification.json` for current CLI/native/export/CI bindings.
Full80-suite Linux workflow40098023022 SUCCEEDS at642af969: compilation,
strict types, all80 default suites, both exports and runner checks all complete.
`qualify.py --require-ci` verifies the actual run/job steps and current source/
export/native hashes. No aggregate Linux assertion total is inferred.

## Coverage still open

This closes a real death-handler gap and strengthens continuous-hunger evidence.
The audit's complete fast-clock feedingÃ¢â€ â€™7/10 moultsÃ¢â€ â€™adultÃ¢â€ â€™matingÃ¢â€ â€™eggsÃ¢â€ â€™generation
route and every naturally triggered predator ending are still open. Current
online rest/save/rejoin, controller/touch comfort, whole-map close clipping,
audio balance and physical-device performance retain their separate evidence
limits. This result does not settle startup hitches or the wider optimization
goal. Any later publication needs the verified ordinary candidate and a release
decision; neither this diagnostic model nor the SelfTest export should ship.
