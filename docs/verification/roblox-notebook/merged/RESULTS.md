# Combined notebook and checklist — Windows, 2026-10-17

Final source/test evidence: **3525b7b58f9afc70**. Claude branch 657ce9d and Chet branch 77ca385 were reconciled with both histories retained. Accepted native replay: **98/98 engine and 23/23 live-client checks**, zero failures (`accepted/`). Published as **version 18**.

## Verification

- CLI: **46,152 accepted checks across 21 suites**. `pure-suite.txt` is the full run: 20 unaffected suites passed, and NOTEBOOK exposed an obsolete expectation that short-screen hints must remain visible. The native-tested layout intentionally hides those hints to leave reading room. The corrected notebook and later full-text-height fix each pass **889/889** (`notebook-final.txt`, then `notebook-height.txt`). Counts use NOTEBOOK once, not three times. The final audio edit changes only the native test's synchronization.
- Strict analysis: no source diagnostics (`strict.txt`; the LSP registration warning is tooling-only). All **142** source/test Luau scripts compile (`compile.txt`). Generator reproduces the exact checked NotebookPages bytes.
- Native engine results include all-page TextService measurements at eight screen sizes and normal/large text, real instances, raycasts, movement, silk, perception, life and sound. Native client replay adds actual discovery events, retained notes after recovery/new lives, modal pause and correct return owner, checklist checkmarks, large text, full long-label height, scrolling and end-screen return.
- Physical PlayStation/controller/tablet: **not run here**. Nathan's next playtest is required. Phone emulation is not device hardware performance evidence.

## Failures caught and fixed

- `initial/`, b14d040bc22d17ef: engine 96/98, client 23/23. Imported heading and hint text exceeded narrow-screen bands. Shortened heading, enlarged permitted hint area and hid hints when reading space would become too short.
- `final/`, f47e5d0b3aebd3ae: engine 98/98 and client 23/23. Manual resizing then exposed a problem not covered by these assertions: AutomaticSize clipped the later checklist entries. `build-equivalence.json` records only the intermediate, test-expectation-only aa2b800588fbcbfb build and is superseded.
- `height/`, a58f99f547d6ad8b: engine 98/98, client 22/23 in iPhone 17 Pro emulation. Explicit measured heights fixed the complete checklist; new full-text assertions passed, and manual scrolling reached the final dance item (`checklist-phone-end.png`). The remaining failure was the existing sound test checking `Playing` after a single Heartbeat. Sound is updated by BindToRenderStep; the test now waits up to one second for onset, still within the eight-second warning. Production sound code did not change. Final rerun is in `accepted/`.

## Manual checks and scope

Normal game starts with the menu, runs without the test target/automation, opens the notebook with N, and C opens To try. Desktop and compact layouts were inspected. The fixed phone reader scrolls through all twelve invitations to the final peacock item. Native selection is cleared so Roblox does not swallow directions. Earlier source panels and input fixes are recorded in the parent directory, but that reader was not published.

The existing gameplay touch buttons still wrap awkwardly on a short phone (Focus/Creep/Recenter); this is called out for the next device-polish chunk. Notebook footer buttons and full text were the scope here. Session-only notes/checkpoints are stated in the game. No server persistence or public-audience changes.

Timing samples in the native report directories are diagnostic samples from the test session, with other Studio work and CLI checks active; they are not a controlled F01 benchmark or low-end-phone measurement. No claim of feature parity or public-release readiness is implied by the test count.

## Publication

Published the normal default project to existing universe 10771103250 / place 120119801868085. Studio reported PublishSuccessful at 2026-10-18 01:23:15 UTC (October 17, 8:23 PM CDT), identifying v18 and the correct place. Creator Dashboard independently lists **18** under Show published only (`published-v18.png`); its saved-version timestamp is 8:19 PM. No test runner or replay is in the normal place. Final synchronized normal-place smoke opened the menu, Notebook and To try before publishing; `checklist-desktop.png` records this final production UI. The test-only audio synchronization change does not change production sources.

Public access, Data Sharing and monetization remain unchanged. Rejoin a fresh PlayStation session to test v18; physical device acceptance remains pending. Temporary Rojo servers and test play sessions were stopped. The release checklist and next persistence chunk are in `docs/PUBLIC_RELEASE.md` and `docs/HANDOFF-roblox-notebook.md`.
