# Settings and touch controls — Windows acceptance, 2026-10-18

Incoming Claude bundle: `9c63783`, based on main `3b8a919` (published v19). No public audience or paid-peacock activation is part of this round.

## Review and first native run

Initial build `5d7a58e97bce417c`: engine 110/111, no skipped tests. All real TextService label/control measurements passed. The panel construction check failed because it called ContextActionService.BindAction from the server. Keep server construction/layout checks, and move binding/open/navigation/close verification into the actual client playback. Do not weaken production input binding to accommodate a server test.

An existing hop test held Jump across a Heartbeat. Under startup load that can exceed the nine-fixed-tick aim threshold and become an aimed leap (observed distance 2.6338). Queue press and release together for the short-tap case; the separate hold/cancel test still checks aiming. Jump physics and input timing are unchanged.

Review found newer settings_version values were accepted but cleaned to the current version, losing unknown choices on the next write. Refuse unsupported future settings versions and keep the entire stored value untouched. A regression checks read-only play and byte-for-byte preservation after periodic saving and departure. Normal schema-1 preference migration remains supported.

Incoming strict analysis passed; actual recursive compile count is 167/167, not the handoff's 172. Final checks and publication are recorded below when complete.

## Acceptance and limitations

Accepted build **d89045d8f2212cda**: CLI **47,547 passed, zero failed** (`cli.txt`); strict clean (`strict-final.txt`); compile **167/167** (`compile-final.txt`). Studio **111/111 engine, zero skipped**, **24/24 live client**, including settings opening/binding/navigation and real isolated DataStore operations (`accepted/`).

Normal game in Windowsill Save Tests (109879630247781): loaded existing progress, opened Menu > Settings, clicked master-volume slider to 75%, scrolled to Large text and enabled it. Stopped Play and immediately restarted. Start menu retained large text; Settings showed 75%. Screenshot `rejoin-large-volume.jpg`. Production saves were not used for these mutations.

Studio Samsung Galaxy S22 Ultra emulator: 360x772 portrait and 772x360 landscape, large text, mouse-driven emulated controls and scrolling. Screenshots `phone-portrait-large.jpg`, `phone-landscape-large.jpg`. Labels wrap and controls remain reachable. Short landscape is cramped: labels and slider controls can require separate scroll positions. Record this as a usability follow-up, not a claim of physical touch acceptance. Keyboard/controller binding has automated live-client evidence; the attempted native PageDown was intercepted by Studio, so it is not a manual keyboard pass.

Published v20 at 2026-10-18 09:04:19 UTC to existing place 120119801868085, universe 10771103250. Studio reports PublishSuccessful and the Dashboard published-only row independently confirms v20 (`published-v20.png`). Automatic approval initially blocked sync because Studio retained the old place title; its current session log verified both numeric IDs before sync was accepted. Audience, privacy, security and paid-pass state unchanged.

 Physical PlayStation, multi-finger touch and lower-end tablet performance are not inferred from Studio or shim tests. The next handoff covers device feedback, store presentation and notebook science review.
