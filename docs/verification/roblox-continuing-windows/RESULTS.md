# Death/continuing Windows verification — 2026-10-16

Final game/test evidence: **589d9e7bbe94f6b1**. Built with Rojo; publishable file SHA-256 `9a25c51a7dd835db1acc12f3d25abbf40e7f0bb27be7558c09da47d1853690fb`.

- **85/85 native engine and 18/18 live client**, Studio 0.743.0.7431133. Matching structured reports here. Initial 53c86f528da1894c reports preserved in initial/.
- **44,819 passing checks across final suite results**: full Windows run in cli.txt plus corrected/expanded CLIENT **23/23** in client-final.txt. The initial full run caught two failures: home guidance hid the peacock dance hint; a new gentle-floor assertion needed floating-point tolerance. Both were corrected and the entire affected client suite rerun, also adding independent main/free-rest recovery. The full run is preserved honestly with those initial failures; it is not relabelled as one clean final-build full run.
- Existing LIFE 20,846, WASP 15,815; CHECKPOINT now 145; new CONTINUING 87. Godot-generated continuing_reference covers real starvation/weakness thresholds, gentle drain and progress behavior. Standard/Gentle wasp catch-versus-touch remains covered by WASP.
- Strict source analysis clean; **127/127** Luau source/test files compile. Godot reference exporter ran successfully and its engine-generated .uid is included; Godot gameplay remains frozen.

Native playback walked from (-22, .31, 6) through the retreat entrance before pressing rest, and verified a checkpoint. It then starved, returned to last rest, ended again and continued as an unrelated spider with no inherited checkpoint. Menu large text, focus and Free play flags/floor passed. Existing silk, prey, eye, peacock and sound checks remained passing. The normal playable file (no test runner) was then opened: launch menu appeared, Begin a new life worked by mouse, M reopened the menu, arrow-key selection scrolled into view, and Return started Free play. Screenshots start-menu.png and free-play.png show this actual Studio viewport (about 812 x 298), not a claimed 1080p run.

Physical controller, PlayStation and tablet checks await Nathan. Scripted input and keyboard focus are not physical-controller evidence. The incidental prey/wasp timing reports were collected while CLI checks also ran; no new F01/frame-rate acceptance claim. There are no live DataStore writes; checkpoints/progress remain session-only, and growth/Easy earning and notebook remain later work.

Publication: pending final Studio submission to existing place 120119801868085, universe 10771103250. Downloads/Windowsill-PUBLISH-Life-589d9e7b.rbxlx is the playable backup; never publish TheWindowsillTests.rbxlx.
