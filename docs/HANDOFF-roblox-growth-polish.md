# Growth, moulting and peacock polish — Chet, 2026-10-17

Nathan requested a closer camera for the smaller peacock, a better look, quieter low ambience and the next chunk. Roblox remains active; Godot gameplay and SPEC stay frozen. See ROBLOX-35/36 and verification/roblox-growth-polish/RESULTS.md for exact checks/publication.

**Accepted on Windows and published as version 15.** CLI 45,263/45,263; Studio 91/91 engine + 19/19 live client; strict clean; 132 scripts compile. Native evidence ece0772bc0acda77; final build 0ee32d97f26bd2fd differs only by four repaired label encodings. Normal synchronized release launch/play smoke passed. Physical device acceptance remains open.

## Delivered

- Growth.luau ports frozen growth.gd, verified against 30 Godot-exported transitions: food actually granted, readiness at 0.9, three 12-hour moults, 10-hour softness, old skins, restoration and adult stopping. Durations are compressed game tuning.
- Resting in the crack while ready starts a moult; movement, jump, silk and appearance changes wait until completion. Simulation uses the existing fixed tick and LifeClock.advanceMoult, never a frame-rate-derived timer. Wasp eligibility receives moulting state. New skin briefly reduces jump reach to 0.7 using Godot's sqrt(reach) speed/time limits; gravity/collider remain unchanged.
- Stage scales 1/1.15/1.32/1.50 grow drawn body, legs, markings, palps and fan about the support plane, preserving world-space planted contacts. Condition fills/thins the abdomen independently; soft pigment fades back. Reduced motion, idle movement and the dance remain.
- Main/Standard adulthood now actually opens Easy; the notice explains its session scope. Free/Gentle never earns that unlock. Recovery/new lives preserve player progress outside checkpoints. Schema 3 keeps growth/food cursor; schemas 1/2 start young without recounting previously granted food. Invalid records leave the world untouched.
- Peacock camera uses 0.62 of the chosen orbit distance, eased on appearance change, and widens gently with growth. Manual zoom and collision/recovery casts still apply. Fan colour/shape polish plus six fine scale streaks: 119 parts full, still 80 low. The cosmetic male plumage/dance remains available at every gameplay stage intentionally; no claim of a biological juvenile Maratus courtship.
- Room ambience volume 0.16 to 0.09; wasp/fly audio unchanged. Day/stage and notices share one vertical layout so they cannot overlap each other.

Peacock stays free. No passes or privacy changes. Checkpoints, Easy and progress remain session-only; there is no live DataStore yet.

## Next chunk for Claude: notebook

Port the frozen field notebook and notebook watcher (`scripts/learning/field_notebook.gd`, `notebook_watch.gd`, `scripts/presentation/notebook_panel.gd`, `tests/integration/test_learn01_notebook.gd` and their data). First inspect the real paths and rules; keep documented observations distinct from artistic simplifications.

1. A pure notebook model with Godot golden scenarios: reveal an observation once, stable page IDs, no spoilers before the observation, source links retained.
2. Wire actual events from hunts, silk catches, sleep, moults, adulthood and wasp encounters. Use the existing event loop; do not infer discoveries from HUD text. Keep notebook progress outside world checkpoints so returning to a rest cannot erase learning; carry it to an unrelated new spider.
3. A readable notebook panel with keyboard, touch and controller/PlayStation prompts, scrolling, large text and proper focus/pause ownership. Avoid an input conflict with dance/change/menu. Keep the existing life menu as the entry point if binding another button is awkward.
4. Test event deduplication, mode switches, checkpoint recovery, a fresh spider, source visibility and short-screen text. Chet runs Studio and publication checks on Windows.

Then plan **server-owned DataStore persistence separately**: schema migrations, a validated save boundary, player-progress/world separation, retry budget, concurrent session ownership and interrupted writes. The current local solo simulation is not authoritative server data; do not simply accept arbitrary client checkpoint payloads into a DataStore. No typed naming UI without Roblox filtering.

## Publishing route

Use only default.project.json/TheWindowsill.rbxlx for the existing place 120119801868085 (universe 10771103250). Publish As hangs here. Working route: existing Rojo 7.7.1 plugin, localhost-only `rojo serve default.project.json`, connect/inspect/accept into the existing online place, disconnect, ordinary Publish (Alt+P), then verify the published version. Stop the temporary server afterwards. Never sync tests.project.json into the published place.

Physical PlayStation/tablet acceptance is Nathan's next playtest. No physical devices were available to Chet.
