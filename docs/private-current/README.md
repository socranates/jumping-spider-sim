# Current private Player candidate — 2026-10-24

**Published privately as version14 after explicit user approval.** The existing
**Windowsill Save Tests**, universe10771634917, place109879630247781, remains
Private for both game access and audience reach. The refreshed published-only
Dashboard confirms version14 at 08:08 Central on2026-10-24. Production was not
published. `publication.json` binds the authorization, file and guard events.
`prepared.json` and `native.json` retain their original pre-publication state;
they are preparation evidence, not current deployment status. See PLAYER.md
for standalone qualification and its limits.

## Exact upload candidate

`C:/Users/natha/claude-xfer/Windowsill-private-current-20261024a1/VerifiedPrivateCurrent.rbxl`

Native saved-file SHA256:
`2dbbb2091c5f1a6a67db3a8188767118d109440f328b3489175ab7c0ab24aca7`.

The reproducible XML input is `TheWindowsill-private-current.rbxlx` in the same
directory, SHA256
`1f19c9777b17add3806e95d4cd5049a1d9371aa98ee4a3ee1ab049cc2510a150`.
`prepared.json` records every source hash, settings and guard identities.

There are **273 unchanged game sources** from evidence032b5985ac17eeb2 at
source/test/export commitdd212105, plus one5664-byte read-only arrival observer.
Full CI40093189495 passes all80 suites, compilation, strict types, exports and
runner checks for those game sources. The new observer compiles at O0, and
the complete274-source private variant passes strict analysis.

Native guards before and after Save As confirm all274 sources, enabled scripts,
the exact private destination and the settings below. `native.json` and
`native-output.txt` retain this source/local-save qualification. No Play or
publication occurred in that private-target editor. Its native screenshot is
`native-saved-guard.jpg`.

| Setting | Published private build |
|---|---|
| World | Preserve |
| Gameplay | Ordinary menu and play; SelfTest=false, TestTarget=false |
| Detail | Automatic selection; no forced tier |
| Persistence | Normal engine adapter, separate test namespace |
| Namespace | WindowsillTest_playerRig_20261024a1 |
| Test owner keys | Existing ordinary t<fresh server time>_<UserId> policy |
| Production | No upload, namespace selection or save access |
| Extra code | Read-only observer; no LibMP, playback driver or SelfTest runner |

The namespace is new for this candidate. The empty PortTests folder is a marker
for the existing test-store/key policy, not a runner. A new server changes its
test-key prefix, so these arrival checks alone do not prove cross-server save
rejoin. Existing save-recovery evidence retains its separate scope.

## What the observer measures

`player-probe.client.luau` runs only in this private standalone experience,
for90 seconds. It observes six engine phases, first callback timing, readiness,
focus changes and six15-second Heartbeat windows. It reports raw dt separately
from the wall interval actually observed since its own start, avoiding the
earlier ambiguity around time before the probe existed. Stats are sampled only
at reports. It records skipped windows or truncated distributions explicitly.

It also records `game.PlaceVersion` at BEGIN and END, plus the replicated game
evidence and selected store. [Roblox's DataModel reference](https://create.roblox.com/docs/reference/engine/classes/DataModel#PlaceVersion)
documents the read-only version property. The standalone collector requires the
exact version observed in the post-publication Dashboard; it does not guess
that the next release must be14.

The observer creates no game objects, UI or network messages, changes no input,
camera, geometry, lighting, ecology or game state, and makes no save writes.
It disconnects seven listeners and removes both render bindings at completion.
Its own timing/listener overhead remains a measurement limitation.

## Native observer qualification

The observer body also ran in a **separate unpublished, unbound, memory-only
fixture**. Only its private identity gate is replaced with a Studio/unbound
gate and a diagnostic availability print. No SDK is included. The companion
startup diagnostic exercises ordinary construction/readiness and asserts save
cleanup. This fixture has277 sources and is **never an upload candidate**.

The first fixture failed its extra early Workspace-attribute assertion.
`failed-observer1/` preserves that failure, both source guards and the companion
startup PASS/cleanup. Its original model is unchanged. The second fixture's
early gate records Studio=true, place/universe0 and diagnostic attribute absent,
confirming ReplicatedFirst ran before that attribute arrived. The revised local
gate relies on Studio/unbound identities; the edit-time source guard establishes
the fixture flag. The actual private observer was not changed by this fix.

`native-observer2/observer.json` qualifies run1792846739757:

- Six complete windows,4971 Heartbeat callbacks, zero skipped/truncated windows.
- All six phase counters advance; expected game evidence and store match.
- Quantiles are ordered; observed interval totals match each window's wall time.
- Seven listeners disconnect and two render bindings are removed.
- No focus loss, no world-startup failure, no unavailable requested Stat.
- Both277-source guards and companion startup PASS/cleanup pass; zero
  CreatorErrors. Studio style/asset warnings remain in the retained output.

This proves the observer's callbacks and cleanup in that native fixture. It is
not standalone Player timing, a matched FPS comparison, a whole life or phone
test. The earlier Studio file stream showed substantial Studio/plugin startup;
the actual current Player path remains the next needed measurement.

## Publication and measurement sequence

1. Obtain approval for this exact current candidate and existing private target.
2. Open the saved candidate, verify its file hash, run its guarded setup and
   inspect the private target. Publish only that ordinary-play candidate.
3. Recheck sources/settings and Creator Dashboard's published-only version and
   Private access. Keep production and the separate native fixtures untouched.
4. Close Studio and heavy local jobs. Launch the private game in the existing
   Roblox Player and allow the full90-second observer to finish. Preserve any
   failed/incomplete arrival rather than restarting because a tool times out.
5. Use ordinary menu entry for a separate gameplay observation, clearly recording
   title/intro/play timing and inputs. Do not claim general FPS improvement from
   unlike workloads or real-device comfort from this laptop.
6. Collect only this probe's events and bounded diagnostics. `collect-player.py`
   requires the actual published version, exact evidence/store, all six windows,
   phase/readiness/cleanup and no recognizable script errors. See PLAYER.md for the completed standalone runs and remaining limits.

Recheck preparation with `python docs/private-current/prepare.py --check`.
The complete ordinary-source CI and prior native rig/matrix results remain
linked in `../audit/HEALTH-CURRENT.md`; no broad audit-complete claim follows.
