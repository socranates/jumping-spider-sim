# Dog collar and cat gait fixes

The dog lowered and rotated his neck to sniff, while the collar and tag kept their standing transforms. Both now inherit the same neck transform. Regression checks measure their position and rotation relative to the neck throughout the outdoor circuit, including sniffing, turns and weather stops.

The cat's body moved across rooms, but its pose used the original windowsill prey director's clock. That clock intentionally stops when its population is inactive. Cat presentation now uses the running world prey animation clock, as the other region-independent body drawers do. The existing distant pose throttle and pause/slow-motion behavior remain. The real-client regression enters the volunteers' back room, confirms the sill clock has stopped, and observes the drawn front paw still moving.

`regressions.json` and `before-*.txt` retain the failures reproduced against the preceding source. `receipt.json` binds the fixed production sources and test/type/compile evidence. These are automated checks under the Roblox shim, not native visual or device-performance evidence. Neither fix alters animal behavior, save schemas, collision geometry or population counts. Publication and native close-up review remain pending.
