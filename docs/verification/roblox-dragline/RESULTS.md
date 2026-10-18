# Dragline, cover, meals and predators — Windows verification

Build: `2ed6a64d5e6d9d58` (2026-10-18). Previous published playtest: v22.

## Accepted checks

- Native Windows Studio: **111/111 engine checks and 29/29 live-client checks**, same build. Reports in `native-final/`.
- The live client constructs the rival rig, captures it, eats it for exactly two housefly-equivalent meals and confirms no repeated reward. Engine rays confirm the four cover pieces obstruct sight and leave clear sight above them. Existing jump, silk, menus, settings, rest recovery, growth, wasp audio/catch and courtship checks pass.
- One native check is explicitly **not run**: the real DataStore test, because this local test place is unpublished. Prior published save acceptance remains separate evidence; do not claim a new cloud round trip here.
- 170 Luau scripts compile; strict source analysis succeeds (`compile.txt`, `strict-final.txt`).
- Full CLI: **48,279 passed, 0 failed, across all 26 suites** (`accepted-cli.txt`, `cli-summary.json`).

## Scope and provenance

Earlier logs and `native/` predate the meal-count, cover and predator requests and are development evidence, not final acceptance. `cli-final.txt`, `rival.txt` and `meal-cover.txt` include superseded failures (fixture expectations, shim vector validation, and a runner started before a module was registered). Their fixes are checked in the accepted run.

Grass is decorative (70 full / 42 low blades); cover is solid and queryable. Full decor 964 parts / low 207. The rival adds one low-detail rig only while present. Native cost samples were collected alongside CLI work, so they are diagnostic, not a controlled frame-time acceptance run.

No physical PlayStation/controller/tablet check was performed this round. Nathan's positive PlayStation report refers to the preceding build. Try the new meal counts, hiding behind the bark, the eastern rival and the dry leaf-tip jump on PlayStation after rejoining. Hard mode is a documented proposal, not enabled.

Published **v23** to the existing Windowsill place `120119801868085` in experience `10771103250`. Studio reported publish success at 10:32 UTC; Creator Dashboard confirms v23 with Show published only enabled (`published-v23.png`). The row time is its earlier save time, 05:24 CDT. Audience, permissions, security and monetization were not changed. GitHub/laptop synchronization follows this evidence commit; the user-facing handback reports its hash.
