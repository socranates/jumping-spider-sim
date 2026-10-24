# Feeding, moults and adult progression

2026-10-24. Game/test fix commit `fa7367fb893a53a66fae71970e5d3116ec8e9d6b`,
branch `codex/verified-integration`. Ordinary export evidence `5e9ac432e9933ed9`,
273 sources. This follows the separately qualified predator ending fix in
`docs/predator-endings/`. Neither fix is published: private version 14 still
contains `032b5985ac17eeb2`; production is unchanged.

## Finding: a final Eat press also started Rest

The Feed callback queued both a feeding tap and an unconditional rest press.
Feeding runs before LifeLoop in the fixed tick. A final bite empties the jaws,
so LifeLoop then saw an empty-jaws rest request made by that same press. Inside
the Crack the spider would rest; on the seventh full fly it immediately began
the first moult without another player action. This affects ordinary play.

The callback now retains the input context: it queues Rest only if neither
prey nor a captured rival was held when the button was pressed. Eating still
finishes, swallowed food still earns growth, and a new empty-jaws press still
rests. No food tuning, save schema, camera, movement, lighting or AI changed.

`final-bite-red-corrected-fixture.txt` records the specific failing real-client
input assertion on the old callback: MEALS 91 passed / 1 failed. The earlier
red attempts encountered an unrelated partial-save/shim warning after the
test started a save fixture; they are retained and are not the regression
proof. The focused input test isolates that save callback; separate suites
and the native route exercise real local rest preparation.

`final-bite-green.txt` records MEALS 92, LOCAL_REST 33, LOCAL_REST_CLIENT 17,
GROWTH 571: **713 passed / 0 failed**. The regression checks the final bite,
readiness without resting, and a subsequent press that begins the moult.

## Native fixture and retained failures

`playback.luau` is an unpublished, unbound Studio-only fixture with the ordinary
273 game sources plus three diagnostic sources and a yielding memory backend.
It never opens DataStoreService. The guarded model is built by
`docs/performance-matrix/build.py`, with normal gameplay and SelfTest disabled.

Captures and safe Crack arrival are fixture setup. Each unique full-profile
housefly has .35 nutrition; ordinary input-state taps drive struggle and eating,
partial bites, swallowed food and the discarded husk. No food, energy or stage
counter is assigned. Growth receives the ordinary .3 credit even at full energy.
Moult time runs at 8x and hardening time at 120x; action ticks stay unchanged.
Fresh lives and mode changes use normal menu/save admission. Easy is earned
through Normal adulthood rather than seeding the unlock flag.

The route requires 7 + 10 + 5 meals for Normal adulthood and 7 + 10 + 3 each
for Easy and Free play: 62 complete meals, nine moults, nine hardenings, three
adult lives. After every threshold, a distinct empty-jaws press starts Rest.
Both movement unlocks are unavailable while moulting; Run follows instar 1,
lock-on instar 2. The drawn GrowthStage, discarded skins, softness and retained
local rest are checked. The server must finish with no active/queued scope,
and all created scope options destroyed. Two exact source guards are required.

Three native models retain the investigation without replacing failed evidence:

- `failed-native1/`: run 1792849498480, before the callback fix. Seven actual
  full meals reached an already-running moult, so the pre-Rest assertion failed.
  Both source guards passed; no CreatorError. The server finish was not reached.
- `failed-native2/`: run 1792850020648, after the callback fix with the identical
  driver. The seventh meal was ready without resting; a new press began the
  moult, instar 1 unlocked Run, and hardening finished. Checkpoint waiting then
  expired: the test attached diagnostic functions directly to the life clock
  instance, and ObjectRecord correctly refused unnamed saved functions.
  Both source guards passed; no CreatorError. This is a fixture defect, not a
  save-source regression or a complete-route pass.
- The corrected driver moves only those diagnostic wrappers onto the LifeClock
  class, outside the saved object graph, and restores them on exit. It retains
  the real checkpoint/save validation and all route assertions. It does not
  suppress a refusal or stub the save callback.

`prepare1.txt` through `prepare3.txt` retain builds and strict results. The model
files remain in their separate `C:/Users/natha/claude-xfer/Windowsill-life-route-nativeN/`
directories, never edited in Studio or published. `collect.py` refuses partial
routes, game warnings, missing source guards or missing cleanup. `qualify.py`
binds current and committed sources, immutable model/log hashes, red/green
regressions, the unchanged-driver comparison, exports and exact GitHub CI run
40099833793. It requires actual successful CI when invoked with `--require-ci`.

## Evidence boundary

The corrected native run **1792850357913 passed**. `native-final/native.json`
and its bounded output record all 62 meals, nine moults and hardenings, and all
three adult lives in order. Both 276-source guards pass; zero CreatorErrors and
zero Windowsill checkpoint/game warnings. Six other warnings remain visible:
four Studio style UDim casts and two asset-type mismatches for asset 203785492.
Those are retained rather than calling the whole session warning-free.
Server finish reports zero active/started/queued scopes and all 12 options
destroyed. Its owner is still present and `lockReleased=false`: this is operation
cleanup in an unbound memory fixture, not a lease-release/rejoin assertion.
Studio PID 27420 was confirmed exited before collection; model hash unchanged:
`f05899bfb21f365ffac5e8cff9f2bfc4799cf6f6c657c9b2a31ee9c2f6f89b87`.

Full Linux CI [40099833793](https://github.com/socranates/jumping-spider-sim/actions/runs/40099833793)
**succeeded** on the exact source/test commit: all 80 default suites, compilation,
strict types, normal/self-test exports, and runner failure/cleanup regressions.
`github-ci.json` retains actual job/step outcomes. `qualification.json` binds
these to source, model, closed native log and current export hashes;
`qualify.py --require-ci` passes. No new source changes were needed after the
final-bite callback fix. Private publication remains version 14.

This route does not prove natural hunting, unforced mating, egg laying, another
generation, online saves/rejoin, physical controller/touch comfort, phone
performance or overall FPS improvement. Those remain separate audit work.
Scripted capture success must never be presented as a natural hunt or fairness
test. In-memory rest preparation is not an online persistence qualification.
