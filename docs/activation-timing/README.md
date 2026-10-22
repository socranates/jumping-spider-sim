# A07: cold navigation activation trace

Source snapshot fc1fc6d8f9a15d9ae64cc5b21074e61a42d7e2b4 (production bytes identical to8e02b5e). This is an isolated diagnostic and experimental activation gate, **not a production fix**. The broader audit stays active.

## Confirmed rival dependency

Six fresh-process Luau CLI traces use the actual RivalDrive, RivalRoute and SpiderMotor against preserve collision, seed914, static safe player and a patrol record. Fixed simulation is60Hz; rendering/preparation is30/60/120Hz. Each production Drive.advance retains its2048-unit/2ms work budgets. Every run lasts90 simulated seconds (5400 fixed ticks); these are accelerated CLI runs, not90-second real-time playtests.

| Render rate | Cold graph ready tick | Cold first movement tick | Experimental pre-play graph ready tick | Experimental first movement tick |
|---|---:|---:|---:|---:|
|30Hz|403|418|1|16|
|60Hz|198|213|1|16|
|120Hz|98|113|1|16|

Cold availability varied by over five simulated seconds. The experiment finishes all requested resident routes before simulation tick zero using repeated bounded production advances. Nine position/leg/pending samples, every600 fixed ticks, match exactly across the three gated traces to six decimal places. This is sampled component agreement, not proof of bit-identical complete trajectories or a full creature/controller replay. The observer does not move; RivalSpider's combat/decision step and wasp are absent. No graph goldens, actor rules, source modules or shipped controls changed.

Warm-up consumed1.79-1.88 seconds of CLI elapsed time,979-1013 work slices. Those counts vary with the wall-clock budget and host load. They are not native load-time or FPS measurements; yielding once per slice in Studio could make elapsed loading much longer. The prototype busy-drains only an offline component fixture and must not be copied into the render callback.

## Wasp preparation boundary

StationAir.prepare independently yields every8 grid cells,625 yields over its5000 node/link loop iterations. The controller currently spawns this from its first fixed tick with task.wait as callback. While preparation is active, an obstructed Air.route returns only its starting point. A separate controlled model resumes the preparation coroutine once per render frame and queries an obstructed doorway route at fixed ticks. Its six traces and receipt live in air/: blocked-route readiness is tick1251/626/313 at30/60/120Hz, versus tick1 for all three pre-play-prepared runs; all completed routes have five points and pass swept collision checks. This is a scheduling model, not measured native task.wait/Heartbeat behavior or a complete WaspDirector replay. Unobstructed direct routes can work before graph readiness; do not generalize the blocked route result to every wasp movement.

## Integration design and required verification

Prepare **both** station surface routes and air navigation behind the loading screen, before the first simulation tick/initial checkpoint/TitleReady. A readiness gate must cover every resident destination to avoid deferring the same nondeterminism until the first region crossing. Build work stays bounded per slice and yields to rendering; do not synchronously build the whole preserve on the first render frame. Loading may take different real durations while gameplay starts from the same prepared state. No later readiness-driven RNG draw or lost simulation time is acceptable.

Use one owner for preparation, explicit ready/failed state and a protected failure path into A12's recovery message. Air preparation errors must not leave a permanent preparing flag/partially accepted graph. Preserve graph data, collision, attack/evasion rules and the seed. Keep old flat test-garden behavior independent. Already-completed caches can be reused; a fresh life/rest must not silently restart a graph build or advance ecology during warm-up.

Before wiring this into SpiderClient: measure the combined cold warm-up on this laptop and set a bounded per-frame loading budget; prove splash still renders. Then add real-controller fast-start/menu/initial-capture tests with short and delayed preparation, early Begin requests, cancellation/failure, and Normal/Easy/Free/rest paths. Update test hosts to advance genuine readiness rather than bypass the production gate. Repeat30/60/120Hz moving-input traces including RivalSpider and WaspDirector state/RNG, all resident crossings and a restored life. Native cold/warm boots must verify no actor runs before readiness and normal/large loading/recovery text remains usable. Only after those gates should the change be integrated and full Windows/Linux checks rerun.

## Reproduction and evidence

From the repository root: python docs/activation-timing/run.py; python docs/activation-timing/run.py --air; python docs/activation-timing/verify.py. The runner snapshots all216 production modules and the test harness into a temporary directory before bundling; worktree/default suites are untouched. process.json records every source hash and each bundle hash. verify.py compares production inputs with the named Git snapshot and worktree, reconstructs every executed bundle to bind embedded harness inputs, validates all trial exits/counts and compares gated samples. Logs/receipts bind output hashes. prototype/ retains the initial three rival-only exploratory runs; its earlier fixture hash is historical and not a current gate. No native, online save, phone, performance improvement or publication claim follows.
