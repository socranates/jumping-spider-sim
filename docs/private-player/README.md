# Private version 13 published and played

2026-10-23 Central. The human explicitly authorized the prepared candidate and
read-only timing probe for the existing private Windowsill Save Tests experience.
File > Publish succeeded at23:26; Creator Dashboard's **Show published only**
view confirms **version13**, replacing published version2. Game access and
audience reach remain **Private**. No production publication, access/security
change, main merge or OneDrive/Godot/synced-source edit occurred.

Target: universe10771634917, place109879630247781.
[Private game page](https://www.roblox.com/games/109879630247781/Windowsill-Save-Tests).

## Exact candidate and publication proof

- Clean273-source model SHA256:
  `bf77f6c885237f14fd274cf4c419300a88507d876c3cf780824b18d9ca2577d9`.
- Published private variant has those same273 sources plus one read-only
  ReplicatedFirst arrival probe. Its generated model SHA256 is
  `d1e26861d04dd79aa1babc60f13a6e1682aeb3433a114ac57cbf70e2787ea8ed`.
- Initial saved editor SHA256 was8616844ac52cffcbac84ada921bc146c04c0eb75766ddcf32e74dc1809edb042.
  A new local copy was opened; only zero Game/Place metadata was rebound to the
  exact existing private target. All274 source bytes, normal gameplay settings,
  automatic detail, empty PortTests marker and fresh test-store selection passed
  the native guard before publication,23:25:18, and after publication,23:27:55.
- The local copy saved before publication is
  `C:/Users/natha/claude-xfer/Windowsill-private-publish-attempt1/VerifiedCandidate.rbxl`,
  SHA256 `b541faea86aa5d9fea9d36d6de442d97c83baded8cbe235629da07066181de09`.
  Original qualified snapshots remain unchanged. The separate SelfTest copy was
  never uploaded. No Rojo server was started for this publication.
- before-published/after-published screenshots and accessibility snapshots show
  the actual private publication marker; after-private-access.txt records both
  Private labels. studio-output.txt retains only the guard/publication events,
  with the full original Studio log bound by hash in observations.json.

The complete current CLI first pass passed **78 suites /468,967 checks /0**.
The new title regression's12 assertions are separately qualified, not added to
that default total. The same candidate also has the foreground native Studio
**274/0/0** qualification in ../native-integrated. The second complete CLI repeat
is separate audit work; it was started only after both Player measurements ended.

## Two standalone client runs

Studio was closed before either run. The heavy CLI was stopped during both.
The in-app browser's Play handoff displayed an install prompt despite Player
already being installed. It was dismissed without installation. Roblox's
documented [direct app link](https://create.roblox.com/docs/production/promotion/deeplinks)
launched the pre-existing client for this exact private place. No credentials,
auth tickets or security settings were handled.

Both runs completed six15-second windows and the bounded90-second probe,
reached title-ready with world_failed=false, and reported the exact
`WindowsillTest_player57_20261023a1` store. Ordinary gameplay selects fresh
`t<server os.time>_<UserId>` test owners. No production or retired QA actor was
selected. Begin a new life reached the playable sill; screenshots show the
spider, nearby fly and0/7 meal counter. This is normal menu entry, not an
injected restore or scripted SelfTest scene.

| Run | Title ready after probe began | Largest initial Heartbeat dt | Final30s mean / rate | Final30s worst / >50ms |
|---|---:|---:|---:|---:|
|1792816238921|9.42s|1562.7ms|17.83ms /56.09FPS|50.62ms /1|
|1792816638859|14.13s|1868.8ms|17.55ms /56.97FPS|31.58ms /0|

The first run spent most of its probe in the title/intro. The second selected
New about32s after probe start; TitleShots' normal intro lasts13.6s, so the last
30s is a bounded stationary windowsill sample after that entry. No traversal,
hunting benchmark, physical-phone result or general FPS improvement is proved.
The platform playtest tip remained visible in the second run; it is not game UI.

The initial Heartbeat dt can span time before the probe's own born timestamp.
These are observed arrival-frame gaps, not a claim that all that time happened
after the first phase timestamp or inside one game function. The initial stall
therefore remains **unresolved**. No direct runtime PlaceVersion property was
queried; publication history, guarded source identity and the expected running
probe connect this test to the private release. There is no independent download
and re-hash of the published server asset.

## Warnings, UI and scope limits

Both logs have zero CreatorError and zero recognizable Lua script-stack/error
records in the collector's explicit patterns. That is a bounded log check, not
a guarantee that every failure format is covered. Platform warning/error
categories remain counted. First run has three CreatorWarning records for
Roblox CorePackages' post-authentication attribution request; second has those
three plus two DiscoveryEventErrorLogger records. They are retained. A numeric
ClientMemStatus error at shutdown is not silently treated as a game exception
or declared fixed. Other platform Output diagnostics were reviewed as URL/
boot-duration/Hello World messages, not game stack traces.

First run also recorded three low-memory messages; Roblox reported unloading
its Lua App, freeing roughly160MB during arrival. The second run did not record
that warning but still had the larger startup gap. These observations do not
establish memory pressure as the cause of the stall. The Studio asset203785492
type warning also recurred before gameplay and is retained separately.

Small touch labels visibly split words such as Creep/Cancel on this desktop's
auto touch UI. This is a readability/polish issue in the saved gameplay captures,
not proof about a physical phone. Controls/settings were not changed. A single
W input was attempted; it is not a complete keyboard, controller or touch
comfort test. Audio balance, whole-map close clipping, all-mode natural lives,
30-minute memory behavior and a full online save/rest/rejoin loop were not
newly established by these two arrival runs. Earlier scoped save proofs remain
separate. No problem-free or goal-complete claim follows.

Both game windows closed through Roblox's own Close Roblox flow. Its two
owned launch-to-tray children were identified by exact path/parent/flag and
closed after their game parent exited. No unrelated app/process was stopped.
Full client/account/network logs were not copied to the repository; only this
probe's events, narrow guard/publication output, selected warnings and hashes.

## Recheck

```text
python docs/private-player/prepare.py --check
python docs/private-player/collect.py --check
python docs/private-player/verify.py --check
```

The finalized client receipts are private13-final-player.json and
private13-warm-player.json under ../integrated-release. private13-first-player.json
was an earlier collection before final exit; it is retained as provisional and
is not the qualification input. Current goal/audit status is in
../audit/HEALTH-CURRENT.md and the operational handoff is ../../chet/save-continue.md.
