# A07 implementation: prepare resident navigation before play

Branch codex/navigation-startup; based on8e02b5e production and the source-bound activation experiments. Evidence845ef13d49a92f88. Unpublished. Source commit is bound by receipt.json after verification.

## Player-visible result and code

The preserve now prepares all resident surface routes and the station's air graph while the loading screen owns play. Until both are ready, no fixed simulation tick, initial playable checkpoint or TitleReady is allowed. Hunger, clock, motor and predators wait. The existing input blocker also covers this period. Save transport updates continue, so a slow warm-up does not delay the hello/reply handshake or discard a normal reply.

The new Shared/World/NavigationPreparation owner alternates existing bounded surface advances with air coroutine work. The loading callback targets8ms between checks, with a64-slice secondary cap; a single existing route advance can take its own2ms and an air resume does8 grid cells. This is cooperative scheduling, not a hard8ms CPU guarantee or a measured frame-time improvement. Readiness is independent from simulation time; different devices may spend different real time loading. A40-second elapsed preparation timeout or caught preparation error signals WorldStartupFailed and stops gameplay; A12's existing loading-recovery message requests rejoin. There is no automatic restart after a fatal load failure.

StationAir now builds nodes/links privately and publishes only a complete graph. Yield callback errors release its construction owner; a closed builder can be cancelled only with its exact owner thread. Another live or foreign owner cannot be cancelled. Aborted private tables are discarded; subsequent preparation can start. Normal synchronous legacy route calls and completed caches remain available. No global map switch, collision/spec mutation, navigation golden, RNG, attack/evasion, movement, camera, feeding, lighting or save schema change was made.

Functional production changes: Client/SpiderClient.client.luau, Shared/Predator/RivalDrive.luau (pending count accessor), Shared/World/StationAir.luau, and new Shared/World/NavigationPreparation.luau. The existing source-bound217-module production and Studio-test artifacts were rebuilt separately; never publish the test artifact.

## Focused verification

Same expanded navigation suite: predecessor production10 passed/5 failed; candidate15 passed/0 failed. Because the predecessor lacks the new pure helper, the paired baseline runner includes that exact helper only as test support; the old playable controller never imports it. Every pre-existing216 production blob remains exactly8e02b5e in that baseline snapshot. Two cases reproduce unavailable cancellation/error-release behavior, three reproduce missing controller gating; ten pure owner tests exercise the same new helper in both runs. This is not a claim that all fifteen are independent old-game regressions.

Coverage: work/time bounds, fairness, both readiness halves, cached completion, prepare/surface/air/subscription-free failure paths, sticky failure, timeout, closed-owner identity, repeated air failures, early Begin refusal, stopped clock/needs/motor/predators, all resident destinations, Normal/Free/Easy after readiness, no rebuild on later lives, and controller failure signaling. These are Luau/shim component/controller tests, not native engine or physical input proof.

Six focused suites total224 passed: navigation15, outdoor-life reset45, minimal HUD63, save notice53, client smoke27 and title21. Compilation217/217 at-O0, strict analysis and five runner checks pass. verify.py independently checks the paired snapshots, every current/Git production blob, compile hashes, focused counts, generated release script set and rejection of the test place. The broader full Windows/Linux gates are separate and pending until actual terminal receipts are retained.

Existing fixtures that started a preserve life after an arbitrary120 frames now allow up to5000 frames while awaiting real readiness. Preserve self-test's early look assertions also await TitleReady. Save-notice transport waits for its connection before delivering loaded; a server cannot answer a hello before that connection. No production readiness bypass was added to make tests pass.

## Development evidence and remaining gates

first-attempt/ retains initial compilation/type diagnostics and notes for an obsolete readiness fixture run that was deliberately stopped after known failures; it was not green. before-handshake-order/, before-air-ownership/ and before-baseline-isolation/ retain superseded focused gates. The first new-test fixture accessed a rival before its first tick and failed to restore its stall injection after that assertion; it was corrected before retained paired results. The final baseline cancellation case checks API availability before starting a builder, avoiding contamination of the separate error-release case. None of these preliminary results are final-source full gates.

Still required: actual native cold/warm loading (splash renders and user controls resume), missing/error recovery including elapsed timing, combined warm-up/frame-cost measurement on the laptop, full moving-input30/60/120Hz replay with creature state/RNG and rest transitions, all65 suites on Windows and Linux, and production/script-set verification. The earlier12 activation experiments establish the problem and an isolated pre-play gate, not complete determinism for this implementation. The40-second limit and8ms target still require native measurement; do not call startup/performance fully verified.

The broader foundation audit also retains old-world migration, read-only Continue, collision/network/device/audio/accessibility and live rejoin/release work. Nothing was published, no live save was touched, and the overall goal stays active.

## Reproduction

From the repository root: python docs/navigation-startup/baseline.py; python docs/navigation-startup/target.py; python docs/navigation-startup/check.py; python docs/navigation-startup/check.py --full-only; python docs/navigation-startup/verify.py. Paired/target runners snapshot source and tests into temporary directories. Preserve raw terminal logs before reruns; do not edit production/default tests while a live non-snapshot full runner bundles remaining suites. Full expected counts65/443884 are not actual results until the gates finish.

## Active full gates and prepared native places

Windows exec2814 and Linux CI39800818953 belong to exact source8f16a40. They remain pending until terminal receipts; do not restart a live handle or mutate source/default suites during full Windows bundling. Prepared native cases live at C:/Users/natha/claude-xfer/Windowsill-navigation-success-v2 and Windowsill-navigation-failure-v2, file Windowsill-navigation-startup-review.rbxlx. Each contains218 fingerprinted scripts (217 production plus diagnostic), production Persistence disabled, and the Studio-only playback hook. Their manifests/guards are retained here; native-probe.luau compiles but has not run. Initial success-v1 construction failed a stale217-versus218 unique-script assertion and was not opened; v2 corrects the diagnostic builder. No production or native success is inferred from that preparation. These are diagnostics and must never be published.
