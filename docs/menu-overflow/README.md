# Title menu overflow correction - 2026-10-23

The normal menu in the integrated candidate clipped the top of its title in a
short viewport. Native measurements showed 378 pixels of content centered in a
330-pixel scroll window: the first row began 24 pixels above the scroll origin.
CanvasPosition was already zero, so scrolling could not reveal that missing
part. See before.png and before-bounds.json.

CaughtPanel now centers title content only when it fits; overflowing content
starts at the top. Ordinary life/end cards keep their existing top alignment.
Two layout-change signals handle viewport resizing, text reflow and changing
choices without adding frame polling. Text, choices, input, game rules and save
code are unchanged. The correction remains a private source overlay; the
production source tree is untouched.

Validation:

- All 273 game sources compile and pass full strict checking; the private
  274-source player variant also passes strict checking.
- Eight targeted suites pass **1,427/0**, including 12 new regressions, title,
  HUD, continuation menu, recovery application, settings, client startup and
  mating-card behavior. Their original assertions/references are unchanged.
- Six real Studio reflow/scroll cases pass: normal text, large text and restored
  text in windows about 175 and 332 pixels high. The complete title starts at
  the visible top, and the footer can be scrolled to the bottom. The live font
  sizes are 58/72/58; the content grows 378 -> 516 -> 378 pixels. Changes to
  temporary widget sizes are restored; saved preferences are not changed.
- Exact-byte native guards passed before and after Play, including the final
  22:30:18.517 Central check: 274 sources, no extra editable scripts, an empty
  PortTests marker, normal Persistence, automatic detail and the correct test
  store. The command-bar fixture is outside the shipped model.

The prior complete 78-suite/468,967-check run belongs to the previous candidate.
This candidate changes exactly **one** game source, CaughtPanel. Its new evidence
is the focused cohort and native cases above; do not describe these as a fresh
78-suite run. Raw focused outputs/receipt are menu1-* under
docs/integrated-release. Native observations and screenshots are in this folder.
After Studio exited and flushed its log, collect.py independently matched both
native UI captures and the original clipping measurement. native-output.txt
retains only those nine geometry events, excluding unrelated local log data.
The initial native fixture's dynamic PlayerScripts require needed an explicit
any cast for edit-time analysis; it was corrected before execution. The final
fixture and its equivalent single-line command compile; strict output is retained.

Latest models:

```text
Clean: C:/Users/natha/claude-xfer/Windowsill-menu-overflow-attempt1/TheWindowsill-candidate.rbxlx
SHA256 bf77f6c885237f14fd274cf4c419300a88507d876c3cf780824b18d9ca2577d9

Private test: C:/Users/natha/claude-xfer/Windowsill-menu-player-attempt1/TheWindowsill-isolated-player.rbxlx
SHA256 d1e26861d04dd79aa1babc60f13a6e1682aeb3433a114ac57cbf70e2787ea8ed

Saved guarded editor: C:/Users/natha/claude-xfer/Windowsill-menu-player-attempt1/VerifiedEditorBeforeUpload.rbxl
SHA256 8616844ac52cffcbac84ada921bc146c04c0eb75766ddcf32e74dc1809edb042
```

The private test target remains Windowsill Save Tests, universe10771634917,
place109879630247781, test storeWindowsillTest_player57_20261023a1 and fresh
t<server-time>_<UserId> keys. It has not been uploaded or published. Use this
corrected candidate for the pending private-player test when authorization
arrives. Reopening a local file may reset game/place IDs to zero; bind only the
named test IDs before Rojo and require the exact source guard to pass again.

Reverify with the bundled Python, from C:/Users/natha/windowsill-save-continue:

```text
python docs/menu-overflow/prepare.py --check
python docs/menu-overflow/verify.py --check
```

For a new assembly, run build.py with a fresh --out directory, then the existing
integrated-release build-player-test.py with that candidate and a fresh output.
The source and builder are reproducible derivations of the unchanged originals.

No standalone-player startup/FPS, physical phone, complete controller comfort,
whole-map clipping or audio review is claimed. Those broader gaps remain open.
The outstanding private upload question remains pending; no new confirmation
was inferred from an automatic goal continuation. No production publication,
main merge, OneDrive/Godot/synced-source change or access-setting change occurred.
