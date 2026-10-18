# Roblox field notebook — Windows, 2026-10-17

Source/test build evidence: **2e7a7b9fda966ec0**. This earlier reader was not published. It is superseded by [the Claude/Chet integration results](merged/RESULTS.md).

## Logic and build checks

- Full Windows Luau suite: **45,478 passed, 0 failed**, 21 suites. `pure-suite.txt` contains the 20 suites excluding CLIENT; `client-final.txt` contains CLIENT 23 and a repeated NOTEBOOK 215. Count NOTEBOOK only once in the full total. Reader input/layout fixes add seven checks: final NOTEBOOK **222/222** in `reader-final.txt`, giving **45,485** accepted checks across the suites. Unaffected suites were not rerun after those isolated panel fixes.
- Notebook logic includes 35 ordered transitions exported by running frozen Godot `field_notebook.gd`; 30/60/144 Hz observation ticks; deduplication, safe record loading, genuine event conditions and rebase after world restoration. This checks behavior, not visual appearance or physical input devices.
- Strict source analysis clean (`strict.txt`). **140/140** source/test scripts compile (`compile.txt`). Rebuilt playable and test places; normal place excludes test drivers.
- Initial CLIENT run was 22/23: an older eye-view test required the shared status area to disappear after leaving eye view. A new notebook discovery legitimately uses that same area. The assertion now requires the normal FOV and absence of the eye-view label; it no longer rejects unrelated status messages. Final CLIENT is 23/23.

## Native tests

Initial native evidence **15151421f76313c9**: **94/94 engine, 20/21 client** (`initial/`). The reading scenario expected a fractional TextSize of 31.5, while Roblox stores an integer. Large sizes now explicitly round (32 px for the main fact), and both shim/native assertions use that value.

Intermediate evidence **2aa71ff3d83dc14b** passed **94/94 engine, 21/21 client** (`final/`). Manual keyboard use then exposed a gap: selecting a footer button caused Roblox's own GUI navigation to consume arrows before the notebook action. Footer buttons remain clickable/tappable but are not selectable GUI-navigation targets; the reading action owns directions/shoulders and Back. Added a native selection-ownership assertion and five shim action checks for D-pad, shoulders, stick and Roblox-menu precedence. That fix passed **94/94 engine, 21/21 client**, evidence **058d630f35a9c8a5** (`accepted/`). Manual N, arrow scrolling, full source reading, and left-arrow page/reset then worked (`notebook-sources.png`).

The 772 × 360 Samsung landscape emulator exposed a presentation issue: the illustration consumed most of the short reading area. Hide the sketch when the reading window is below 180 px high and restore it on larger screens. The shim now supplies ScrollingFrame's pre-layout window/canvas size (zero); two new checks verify both layout branches. Final compact evidence **2e7a7b9fda966ec0** passes **94/94 engine and 21/21 client** (`compact/`), including large-text reading, scrolling, modal pause and return. Manual emulator swipe scrolling reached the full citations, touch Next changed/reset the page, and restoring desktop brought back the sketch (`notebook-phone.png`, `notebook-desktop.png`). The existing in-game touch HUD still wraps some control words on this short preview; that is outside the notebook and remains a touch polish item.

## Scope and follow-up

The notebook has 25 sourced pages, 23 currently reachable. The two inherited felt/buzz entries await actual ported sensory events. Discoveries belong to the session, outside rest checkpoints and life resets; there are no DataStore writes. Existing source-review limits remain in NOTEBOOK_SOURCES.md, including wider-public-release review for the inherited wasp facts. This update keeps the existing playtest access.

Physical PlayStation/controller/tablet checks are **not run**. Native automated controller logic and desktop/emulated layout checks do not substitute for those devices. No F01 claim or low-end-device benchmark is made from this run.

Next: server-owned persistent player/world records, with failure-safe loading and an isolated test store. See HANDOFF-roblox-notebook.md. The peacock remains free; the dance, twitch, camera, quiet ambience, fixed simulation timing and collision rules are preserved.
