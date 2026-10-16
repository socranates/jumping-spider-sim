# Peacock Windows verification â€” 2026-10-16

Imported Claude's five commits through 903bf49 onto main 059811b. The appearance and dance stay free/unlocked; no monetization code or service changes.

## Command-line checks

- Full Windows Luau run: **44,721 passed, zero failed** (`cli.txt`). This run began before the compact landscape fix; it is not relabelled as a full run of the final build.
- Affected suites after the layout change: SUMMARY **185**, PEACOCK **80**, CLIENT **19** all passed (`layout-checks.txt`). The new SUMMARY assertion checks on-screen prompt bounds across nine safe-area sizes.
- Final source: strict Roblox Luau analysis clean; **124/124** source/test files compile (`compile.txt`).

## Native Studio

Initial integration **e54de70c7907c0a8**: **84/84 engine**, **15/15 live client**. Reports in `initial/`. This includes PeacockSpec's rig/pose checks and a full live loop: choose while resting, open fan, unchanged motor position, walk to stop, restore the first spider.

Final build **2c8f574734259bd8** adds the compact landscape fix and one native PromptSpec row. **85/85 engine and 15/15 live client passed**, collected from Nathan's Studio run (0.743.0.7431133). Final structured reports are in this directory. Downloads/Windowsill-Peacock-Test-2c8f5747.rbxlx is the test copy; the older e54de70c file does not test this layout change.

## Limits and remaining checks

No physical tablet/controller/PlayStation run this round. Native text measurements and pure geometry are not a multi-finger device test. Fan z-fighting at close zoom, the folded silhouette under Roblox lighting, feet on walls/undersides, and the aesthetic feel of the full dance still need a human visual pass. No new GPU/performance acceptance claim; recorded wasp/prey samples are incidental to automated playback. No live publication verified.
