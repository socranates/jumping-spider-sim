# Growth and peacock polish — Windows, 2026-10-17

Published **version 15** of existing place **120119801868085**, universe **10771103250**. Creator Dashboard confirms it with **Show published only** selected (`published-v15.png`, saved time 03:56 America/Chicago). Studio logged `PublishSuccessful` at 08:56:59 UTC. Source build evidence: **0ee32d97f26bd2fd**.

## Verification

- Full Windows Luau run: **45,263 passed, 0 failed**, 20 suites (`pure-suite.txt`). Includes GROWTH 433 and CHECKPOINT 156. Growth compares 30 transitions exported from the frozen Godot implementation, including a restored in-progress moult. Rest/moult integration is exercised at 30, 60 and 144 Hz.
- Final Studio native run: **91/91 engine checks and 19/19 live-client checks**, evidence **ece0772bc0acda77** (`final/`). The new live scenario grants three meals through the needs API, rests through each moult, verifies movement lock/pale skin/checkpoint restoration, and reaches adulthood to open Easy. It then explicitly confirms the Easy selection. This is an accelerated automated scenario, not three naturally hunted meals.
- Initial native run: 91/91 engine, 18/19 client (`initial/`). The test selected Easy once but did not confirm the existing confirmation screen; the test was corrected. Actual adulthood had passed. Native inspection also caught the day/notice overlap, fixed by sharing one vertical HUD layout.
- Strict source analysis clean (`strict.txt`). Final compile **132/132** (`compile-final.txt`). Last visual reruns: GROWTH 433 and LOOK 102 (`visual-final.txt`). Full peacock budget 119 parts; low detail remains 80.
- After the final native run, four garbled em dashes in client/motor labels were repaired. No behavior changed; rebuilt artifacts have evidence 0ee32d97f26bd2fd. The synchronized normal release was then smoke-tested in the existing online place: launch menu, Begin, day/stage HUD and normal scene (`synced-play.png`). No test runner was synchronized or published.
- `peacock-adult.png` shows the staged adult peacock dance, closer camera and final fan colours in Studio. The automatic scenario places the spider for this portrait after its assertions.

## Performance and remaining playtests

During three accelerated moults: 1,549 frame samples, median **16.99 ms**, p95 **22.83 ms**, maximum **87.22 ms** (`final/growth-frame.json`). A CLI run overlapped this sample; power state was not controlled. This is a useful smoke measurement, **not an F01 pass or a low-end-device benchmark**.

Physical PlayStation/controller/tablet acceptance was **not run**. Nathan can rejoin the existing game to try the closer peacock, dance and quieter ambience. Room volume changed 0.16 → 0.09 (about -5 dB); warning/flies unchanged. Subjective speaker loudness remains Nathan's check.

## Publication and preservation

Opened the existing online place in Studio, downloaded its pre-update draft to the workspace's `publish_verify/before-growth-20261017.rbxl`, synchronized only `default.project.json` through the existing Rojo plugin, disconnected and stopped the temporary loopback server, smoke-tested, and used ordinary Publish. No privacy/access/Data Sharing changes, new experience, monetization or DataStore.

The open local test session was preserved separately as `publish_verify/growth-test-session-20261017.rbxl` when automatic approval declined discarding its unsaved state. No state was discarded. Generated release/test files remain in `roblox_port/`.

Progress, checkpoints and Easy unlock remain **session-only**. The next chunk is the field notebook; server-owned persistence is a separate follow-up. See `docs/HANDOFF-roblox-growth-polish.md` and decisions ROBLOX-35/36.
