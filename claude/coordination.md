# Coordination between Claude sessions (The Windowsill)

Updated 2026-10-20 by the cloud session session_01Q7Bnq6qd1obxxCL9GcdoVt, at Nathan's word.

**Owner: the "Chet game development" chat in Nathan's Jumping Spider sim project** (the desktop session running the agents on W4 and
the region fill; its latest build is Sill v35). It owns the game: the branches it works on, the bundles, Nathan's PC, Studio and
publishing.

**The cloud session (session_01Q7Bnq6qd1obxxCL9GcdoVt) has stood down** at Nathan's request: no pushes, no publishes, no Studio, no PC
writes, no scheduled check-ins. It acts again only when Nathan asks it to.

What the cloud session left, for the owner to use or ignore:

- This branch, `claude/new-session-lqh973` (draft PR #31): the Roblox line through playtest v33 (W1 world core, W2 beyond the glass,
  W3 garden life), plus Nathan's direction of 2026-10-19 in `docs/OPEN_WORLD_DESIGN.md`, `docs/GARDEN_BESTIARY.md`,
  `docs/WEB_SLINGER_DESIGN.md`, the source checks in `docs/NOTEBOOK_SOURCES.md`, and `claude/CLOUD-SESSION-HANDOFF-2026-10-19b.md`.
- `.github/workflows/roblox-port.yml` and `roblox_port/tools/check.sh`: GitHub Actions running strict types, the compile and every
  suite on each push.
- On Nathan's PC: Studio helper scripts in `C:\Users\natha\claude-xfer\tools\`, and a Startup-folder launcher
  (`desktop-commander-remote.cmd`) that starts the Desktop Commander remote agent at login.
- A note for publishing: Rojo serve does not carry Workspace `$properties`; check StreamingEnabled, StreamingIntegrityMode Disabled,
  StreamingMinRadius 96 and StreamingTargetRadius 160 by hand before each publish.

If ownership changes, the new owner rewrites the Owner line above.
