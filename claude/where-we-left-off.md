# Current handoff - Claude, 2026-10-12 (LIFE round 1: clocks and hunger)

**Read docs/HANDOFF-life-round1.md.** It was built while Chet's measuring round was paused, and merged on top of it (798e098).
- **Days and nights:** the life clock, a night's sleep in the crack from 18:00 with a morning checkpoint, day and night light, and the eyes reaching 30 % as far at night.
- **Hunger:** by game hours on the windowsill (life mode, no floor, starving hours counted; no death yet). The abdomen shows condition.
- **Saves and pages:** checkpoint schema 4; three notebook pages.
- **Decisions:** LIFE-04 to LIFE-09.

**Nathan's decisions this round:**
- **MODES-01:** the main life is Standard until one spider reaches adulthood. Then Easy unlocks for it. Free play is separate and open from the start. Only the world's dangers are locked; control helps (Most help and the rest) work everywhere.
- **FEEL-01:** "it needs to feel really like being the little spider".

**Next (LIFE_DESIGN, "Order of work"):**
- **Round 2, Chet:** play days and nights on the laptop. Check night light, the abdomen and frame time with the moving sun, and rebuild the friend ZIPs if Nathan wants them current.
- **Round 3, Claude:** moulting.

Evidence: see DECISIONS LIFE-09 and SESSION_LOG (merged result there too).

---

# Current handoff - Chet, 2026-10-12 (LIFE round 0 complete)

**Read docs/HANDOFF-eye-perf-windows.md and docs/verification/eye-perf/WINDOWS-T13b.md.**

- Windows **591/591**, evidence **2c7264139c03**. Game remains fa32368/T13b; this round changes docs and excluded measurement fixtures only.
- Plugged-in screenshot-free live A/B: eye GPU p95 down **16-19%**. Whole-run frame p95 **18.109 ms**, still above 16.7 ms. Near 60 fps average for both under VSync. Keep six-read shader; four-read mipmap candidate was slower.
- Fresh Windows/web ZIPs **include notebook N**, in Downloads/The-Windowsill-Playtest-2026-10-12-T13b. Manifest and screenshots in eye-perf/. Web eye view/notebook checked; Windows export launches/renders. No itch.io publication.
- Browser Chromium UnknownError persists; native physical-key/controller play and sound listening remain human checks. No game physics, twitch or SimClock change.

**Next: Claude, LIFE_DESIGN round 1, clocks and hunger.** Nathan's LIFE-03 answers stand. Chet pushes main and runs laptop update.bat; actual final commit is confirmed in chat. Older sections below are historical.

---

# Current handoff - Claude, 2026-10-12 (before Chet's measuring round)

**Latest:**
- **The eye picture is about a third cheaper** (T13b, PERF-02): six blur reads instead of twelve, and the full-size picture is read only inside the sharp fields. Measured on software rendering only (`docs/verification/eye-perf/`). **The laptop timing is Chet's.**
- **The plan for one whole life:** `docs/LIFE_DESIGN.md`. Nathan decided on death (LIFE-01: "real and jarring. not sensationalized").
- **The notebook** (LEARN-02) is in main. The friend ZIPs from 7e5c49d predate it.

**Next (LIFE_DESIGN, "Order of work", round 0), Chet:**
- On the laptop, time the eye view before and after T13b. Try the mipmap variant described in `docs/verification/eye-perf/results.txt` if it looks worth it.
- Rebuild the friend ZIPs from the new main.

Then Claude does clocks and hunger. Nathan answered the four questions in `docs/LIFE_DESIGN.md`: all proposals accepted (LIFE-03).

Evidence **2c7264139c03**: 591/591 (Linux headless, fixed 60 fps). Not run on Windows.

---

# Current handoff - Claude, 2026-10-12 (naturalist's notebook)

**Latest: the naturalist's notebook (LEARN-02 to LEARN-04).**
- Built while Chet's round was paused, kept on Claude's branch, and merged after his friends-slice round.
- 14 short, sourced pages open the first time things happen in play. N / D-pad up, or the Esc menu, opens the notebook.
- Pages are in `data/notebook/pages.json`; how far each source was checked is in `docs/NOTEBOOK_SOURCES.md`.
- It is the player's own file (`user://notebook.cfg`). Tests never write it.
- The friend ZIPs Chet made (from 48b84a0) do **not** include the notebook. A rebuild is needed if friends should see it.
- Evidence after the merge: see DECISIONS LEARN-04 and SESSION_LOG.

Next, by the release road (ROADMAP, "The goal"):
1. Read the friends' feedback (`docs/FRIEND_PLAYTEST.md`).
2. The eye-view shader is the first measured performance target (`docs/verification/release-slice/PERFORMANCE.md`).
3. Then "one whole life".

---

# Current handoff - Chet, 2026-10-12 (friends slice)

**Read docs/HANDOFF-release-slice.md first.** Game remains 48b84a0/T13a;
this round adds packaging instructions and Windows evidence, not gameplay changes.
Windows baseline **585/585**, evidence **db112e2fa006**, matches Claude.

Windows and web release ZIPs are in Nathan's Downloads/The-Windowsill-Playtest-2026-10-12.
SHA-256 manifest and all spec gate statuses are in docs/verification/release-slice/.
Nothing published to itch.io. Friend feedback sheet: docs/FRIEND_PLAYTEST.md.

Five-minute rendered source run on battery, 720p: **56.8 fps average,
21.448 ms p95**; normal eye view slowest (~51.6 fps). Two strike attempts,
successful struggles. F01's reporting clause is met; the 16.7 ms target is
missed. Measurement limitations and reduction plan are in PERFORMANCE.md.

Browser controls, both views, slow motion, pause and a preference reload
worked. Actual Windows export renders both views; native keyboard automation
was inconclusive because the tool emits incorrect physical key codes.
Sound needs listener verification, controller-only play needs hardware,
and browser Chromium UnknownError remains unresolved. M04 exhaustive
rendered matrix, U01 and E01/E02 remain open. These are friend-test builds,
not 1.0 or all-gates-closed evidence. Keep twitch and SimClock unchanged.

Chet finishes on main, pushes, runs the laptop updater and confirms the
actual commit in chat. Older handoffs below are historical.

---

# Current handoff - Claude, 2026-10-11 (T13a)

**Latest: vision realism part 2, ROADMAP step 5.** Start from main and read **docs/HANDOFF-vision-2.md**.
- In the spider-eye view, things moving in the soft surround shimmer: the lateral eyes' motion sense, presentation only.
- Two comfort switches, off by default: level horizon and grey picture.
- The eye view's notice no longer covers the sound captions.
- Depth from defocus waits for Nathan's decision (EYE-13). It would change jump accuracy.
- UV stays unsimulated (EYE-14): no published UV data for the house fly.

Evidence **db112e2fa006**: 585/585 (Linux headless), after Chet's 576/576 on Windows (5b1adc6e6a6b), which also passes on Linux. Not run on Windows. Next: Nathan plays; then ROADMAP step 6, handing back the slice.

---

## Chet's movement handoff (previous)


**Latest: movement realism part 2, ROADMAP step 4.** Start from main and read **docs/HANDOFF-surface-legs.md**. Added world-planted feet, steps during turns, rear-pair extension, abdomen/spinneret touchdown before visual launch, and landing absorption. Twitch stays. Reduced motion stays neutral. All new animation follows SimClock.DT; movement, jump and tether physics are unchanged. Instant hops use a short third-person presentation lead-in while the motor launches immediately; first-person camera timing is unchanged. Sources and approximation limits are in the handoff and DECISIONS LEG-05 through LEG-08.

Windows baseline on Claude's 17db650: **568/568**, evidence **77c9ef3b3bc6**. Final Windows full suite: **576/576**, evidence **5b1adc6e6a6b**. Touched leg/silk/eye checks: **46/46 at fixed 30, 60 and 144 fps**. Native quarter-speed screenshots and frozen reports are in **docs/verification/movement2/**. Every new script includes its .uid. Player settings/saves were isolated from testing.

Nathan can play the updated main and judge the gait, particularly short hops, turning and first-person view changes. Proposed next round is Claude's ROADMAP step 5 (vision realism part 2), subject to Nathan's choice. Full anatomical/species-specific rigs and a sustained laptop performance benchmark remain future work. Chet finishes by pushing main and running the laptop update.bat; the final chat message confirms the resulting commit.

---

## Earlier handoffs (historical)

# Where we left off — Chet, 2026-10-10 (America/Chicago)

**Latest: T10b, scientific eye-view refinement.** Start from `main` and read **docs/HANDOFF-retinal-scan.md** and **docs/VISION_RESEARCH.md** before the older handoffs below. Built on Claude's `2d6ea80`: two narrow principal-eye detail regions sweep together and twist behind fixed lenses; the camera/aim/senses stay unchanged. Removed the blue-as-UV shortcut; the green-weighted picture explicitly says UV is not simulated. Reduced motion freezes scanning; pause stops its clock. Windows full suite **548/548**, evidence **829573aaf835**; normal-speed eye tests **12/12**; native AMD/OpenGL captures in `docs/verification/t10b/`. Research-backed illustration, not a literal spider's colour experience. Nathan's playtest is still needed. The previous live-legs and T10a sections below are historical context.

**Start from `main`.** Nathan approved wiring the leg prototype into the real spider. The live-leg implementation is commit `a51d639`, based on Claude's `eacec52` (T09d controller remapping, assist presets, and Nathan's request to keep the twitch). Read **docs/HANDOFF-live-legs.md** first, then **docs/HANDOFF-chunk-9.md** for T09–T09d. Follow the one-agent/start-main/finish-main/laptop-update rule in **docs/SHARED_WORKFLOW.md**.

## Current result

- Eight animated legs replace the static legs. Walk/stalk gait follows local surface-frame movement; preparing spreads the stance, flight/hanging folds the legs, and stopping returns them to neutral.
- The existing snap turns, lurches, idle flicks, struggle jolts and catch recoil remain. Nathan: "its so fun, I love the twitchy ness. They almost look like they glitch in real life." Keep that character.
- Reduced motion holds neutral legs and turns off twitch/recoil, including a recoil already in progress.
- The prototype's cylinder scaling bug is fixed: rendered segments now meet at their knees and feet. The live material stays the same.
- Windows and Web presets now include the live leg script. The isolated preview scene is still excluded.
- Claude's T09d remapping and assist presets remain intact. Most help is intended for Nathan's son; presets still leave Reduced motion alone.

## Verification

**Combined evidence `cfdc7fac7ce0`: 536/536**, native Windows headless, accelerated fixed 60 fps, Godot 4.7.2/Jolt. **28/28 at normal speed** for the leg tests, supported locomotion (including F4) and T09d controller/preset tests. Reports are in `docs/verification/live-legs/`. These are not sustained GPU frame-rate or physical-controller playtest claims.

Before the pause, unmodified `run_tests.bat` completed on `b8716b4`: **522/522 at normal speed**, evidence `27b60f6974e8`. The previously failing F4 support-view test passed. Its frozen report and console are retained separately. The laptop was subsequently updated to T09d during the pause; its first snapshot in this session therefore has evidence `3fb300501a68`, and is not the older baseline's snapshot.

`update.bat` was successfully run on the laptop at session start. At handback, Chet pushes the combined work to `main`, runs the updater again, and confirms the final laptop commit in the closing message. No player saves or settings were used by the test runs.

Native AMD Radeon screenshots show the real windowsill spider's corrected legs, walk/stalk/preparation and Reduced motion. This is visual inspection, not Nathan's approval of the gait feel. See the live-legs handoff for export and snapshot results.

## Next

**Latest (Claude, 2026-10-11, T11c):** Nathan: "it all works great now. the tapping should be harder still", and "also make the bar bright red". A steady five presses a second is needed now (four loses the fly), and the grip bar is bright red, pulsing lighter when low (STRUGGLE-03). "Hold on automatically" is unchanged for his son. Evidence **77c9ef3b3bc6**: 568/568 (Linux headless). **Chet still has the next round: ROADMAP step 4, movement realism part 2** (list at the end of `docs/HANDOFF-sound-senses.md`).

**Latest (Claude, 2026-10-11, T12b):** Nathan heard nothing. A recording proved the mix was too low-pitched and quiet for laptop speakers. It has been rebuilt brighter and louder, with birds outside, and an Esc-menu **Headphones** switch (off: speaker tuning). Evidence **0c295e07077e**: 567/567 (Linux headless). See the T12b section of `docs/HANDOFF-sound-senses.md`. Chet still has the next round (step 4).

**Latest (Claude, 2026-10-11, T12a):** sound and the spider's other senses. There is a generated soundscape (room, flies, the shadow), a vibration sense through touching solids only, captions with directions, ripples, rumble, and volume sliders. Evidence **4daaf055b746**: 565/565 (Linux headless); not run on Windows, and nobody has listened yet. Read `docs/HANDOFF-sound-senses.md`. **Chet has the next round: ROADMAP step 4, movement realism part 2** (the handoff ends with the list).

**Latest (Claude, 2026-10-11, T11b):** Nathan played the whole checklist: everything works, "really fun, camera works great, 1st person is super cool". The struggle is harder and ends the moment the grip bar is full (STRUGGLE-01). Evidence **d9ed40eeeecf**: 557/557 (Linux headless); not run on Windows. Results in `docs/PLAYTEST.md`. U01's controller-only part is still open (no controller). Next by the plan: step 3, sound and the spider's other senses, unless Nathan picks otherwise.

**Latest (Claude, 2026-10-11, T11a):** one game clock and slow motion (T / RT), an easy first/third-person switch (V / Y, a line on screen, an Esc-menu button), and the playtest checklist `docs/PLAYTEST.md`. Evidence **e530e2f0810d**: 553/553 (Linux headless, fixed 60 fps); not run on Windows. Read `docs/HANDOFF-slow-motion.md`; the plan is `docs/ROADMAP.md`. Nathan's son needs no more help than Most help. The next step is Nathan's playtest.

**Spider-eye view (T10a, Claude, 2026-10-11):** built at Nathan's request. Read `docs/HANDOFF-eye-view.md`. V or Y switches between a first-person view from the principal eyes and the orbit camera. Decisions EYE-01 … EYE-06. Evidence **7169ecfd3663**: 544/544 (Linux headless, fixed 60 fps); not yet run on Windows or played. Nathan also said: "you can mess with any approved code its ok", and that his laptop is the shared home for him, Chet and Claude ("absolute permission for anything"). Claude itself works in a cloud copy and reaches the laptop only through GitHub and `update.bat`.

**Cross-device goal (Nathan, 2026-10-10 America/Chicago):** Nathan wants to play on PlayStation and other devices. Keep this in mind during Godot development. Roblox is a possible route, not a selected platform or an authorized port. Nathan, Chet and Claude will decide the approach and timing together. Chet suggested a solid Godot core followed by a small Roblox feasibility prototype before extensive additional content; this is a proposal, not an agreed milestone. See DECISIONS PLATFORM-01.

**Nathan, 2026-10-11 (after the legs):** "we can move on to the next thing. Eventually i want to add a first person spider eye mode so its more immersive." And: "we are going for scientific realism in terms of vision and movement and all." See DECISIONS T9e-03. Claude proposed a first-person eye mode grounded in salticid vision research and asked whether to start it now. Global slow time is deferred (T9e-01: it needs one simulation clock) and survival pressure waits for needs with consequences (T9e-02).

Nathan should try walking, slow stalking, aiming/jumping, catching a fly, and the Reduced motion switch. The gait remains a cosmetic prototype: no individual foot contact IK, world-space planted feet, turn-in-place steps or transition blending. Surface overlap/sliding during twitch and at edges is possible; physics and sensing are unchanged.

Remaining T09 work: global slow time, a separate survival-pressure setting, and a Windows interrupted-write test. Human U01/W01/E02/M04/F01 checks and the full Web platform playtest remain open. The live-leg work no longer reserves `main.gd`.

Do not restart chunks because chat history is missing. Keep the lab fixtures, append decisions, preserve approved hunt/camera/movement mechanics, and do not revive arbitrary-state resume S01 silently. Checkpoints remain S01-C (schema 3, upgrades from schemas 1 and 2).
