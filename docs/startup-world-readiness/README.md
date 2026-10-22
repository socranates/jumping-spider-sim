# A12: safe home-world startup and loading recovery

Source `8e02b5ee5f443ab332cf7e70f5951a304cb89eea`, evidence `58063ec00de84212`, branch `codex/startup-world-readiness`, based on fully CLI-verified source 6026d6c. Unpublished. Local checkout remains `C:/Users/natha/windowsill-observed-life`.

## Problem and result

Code locations at this commit: `Client/WorldClient.luau:73` (construction), `First/SplashScreen.luau:163` (recovery ownership) and `:189` (loading loop).

`WorldClient.new` waited indefinitely for World/home folders, guessed the default world after a missing/unknown streamed identity, and warned then returned a usable client when home collision never arrived. A subsequent motor could start over absent surfaces. The old default regression explicitly pinned that unsafe continuation. Separately, SplashScreen removed its veil on timeout or a caught error even when the main controller had never reached TitleReady, revealing an unready/empty scene.

Streamed world identity now needs a known value within the existing 10-second budget. Essential World/home folders and home collision parts share one 30-second deadline; a missing or non-BasePart home piece aborts construction before the motor/controller can start. WorldStartupFailed informs ReplicatedFirst's loading screen. Every server-layout world is checked even with instance streaming off. Explicit legacy flat non-streaming box fixtures retain their immediate compatibility path. Optional Decor retains its existing best-effort wait and cannot make missing collision acceptable.

Healthy TitleReady still fades normally. A failed/late controller or caught splash error retains a small, static recovery explanation rather than pretending play is ready: “The world hasn't finished loading. Please rejoin.” It is bootstrap-local emergency text because Shared/UI may be the missing dependency; no gameplay help or HUD text is added. Late successful TitleReady removes the stale explanation automatically. Readiness/destruction subscriptions disconnect on recovery or disposal, including deferred destruction and a failed subscription. The default Roblox loading screen is removed only after our own PlayerGui screen is built; if Players/PlayerGui is absent, that fallback is retained. The UI error loop terminates; no ongoing render/camera loop is added for the retained message.

There is no in-place controller restart or automatic WorldClient retry after essential-world failure: rejoining restarts the load. Extremely slow arrivals can now require rejoining rather than entering a partial world. Shared module imports before construction still contain waits; this is not a claim that every import/cyclic/yielding ModuleScript or platform failure is bounded. The generic timeout explanation depends on the splash host continuing to advance. This patch does not solve outside-region network streaming, every seam, old-save migration or foreign-lease Continue.

Only WorldClient and SplashScreen have functional changes; Splash.client's comment is corrected. Movement, camera/jump rules, predator/feeding/settings/menu code, world geometry, lighting, saves and golden reference data are unchanged.

## Verification and repro

The final same-test pairs on predecessor production6026d6c report **`WORLD_CLIENT` 29 passed/4 failed** and **`TITLE` 15 passed/6 failed**, both nonzero exits. Candidate: **`WORLD_CLIENT` 33/0** and **`TITLE` 21/0**. The four failing world cases cover absent streamed pieces, non-streaming server-layout pieces, World/home folders and missing/unknown streamed identity. The six failing splash cases cover obsolete timeout behavior, early world failure, missing Shared words/late readiness, disposal, deferred ordering and failed subscription cleanup.

Existing healthy title fade, camera handoff/intro, delayed box arrival, home/world queries and real-client traversal remain covered. Client smoke **27/0** and preserve **1,154/0** pass: **1,235 across four targeted suites**. Compilation 216/216 at -O0, strict types and five runner checks pass. Generated production XML SHA-256: `8f5a265c5907af24df31d805986b42ac4ada500ceca2b37b3f61be397949c2bf`. The verifier binds both pairs, every production blob/compile, exact committed test files and the rebuilt release; it rejects the test artifact.

The CLI shim's WaitForChild returns its parent on a miss and its generic Disconnect is a no-op. These regressions use explicit nil-on-timeout and tracked signal/destroy hosts rather than accepting those behaviors as engine proof. Deferred notifications are queued in the local test host; this is not a native SignalBehavior result. Early exploratory fixtures let a failing default-map lookup contaminate later cases, and an ad-hoc helper reused a log basename. These were corrected before the retained final comparisons. `prototype/` records are not final-source gates. The final driver snapshots source/test files and can load baseline production from Git without changing the worktree.

Commands, from the repository root on this Windows host (the paired driver also accepts `--luau PATH` for another machine):

```text
python docs/startup-world-readiness/run.py baseline
python docs/startup-world-readiness/run.py baseline --suite title.luau
python docs/startup-world-readiness/run.py candidate
python docs/startup-world-readiness/run.py candidate --suite title.luau
python docs/startup-world-readiness/integration.py
python docs/startup-world-readiness/verify.py
```

Full Windows **exec22326** and Linux **CI 39792121861** are pending for this source. Expected totals:64 suites/443869 checks, eight more case summaries than6026d6c. Do not treat expected counts as observed, restart live handles after a timeout, edit source/default tests while the full Windows runner bundles them, or relabel the predecessor's green full gates as current. Earlier-source native diagnostics do not cover this UI/startup change. Native cold-load success, delayed/missing geometry, recovery legibility at normal/large text and desktop/phone viewports, and actual destruction/readiness event timing remain to verify. Nothing was published or synchronized as a release.

## API contracts and scope

Roblox documents that child replication order is not guaranteed and a timed WaitForChild can return nil. Destroying may fire before destruction or at a later resumption point; the callback owner here is the surviving ReplicatedFirst module, not the destroyed screen. See [Instance/WaitForChild and Destroying](https://create.roblox.com/docs/reference/engine/classes/Instance) and [deferred events](https://create.roblox.com/docs/scripting/events/deferred). These contracts inform the guards; they do not substitute for native verification.

The broader audit remains active. Preserve the liked controls, camera, long jumps, density and lighting. Resume required native checks when Studio has memory headroom, and keep legacy compatibility, safe Continue, deterministic AI activation, physical controls/collision/streaming, profiling/network/startup/device measurements and final release/rejoin evidence explicit.
