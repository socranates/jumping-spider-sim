# Windows acceptance - perception part 1, 2026-10-15

Verified and imported Claude's bundle, source commit 41d1148e5470f4d8013c5579c13cc59c8bce38f4 (five commits after 61f2d49).

Windows Luau 0.742, tests/run.py, exit 0:
- SUMMARY 182 passed, 0 failed
- PERCEPTION 4669 passed, 0 failed (includes the 29 Godot-exported scenarios)
- BOXWORLD 15 passed, 0 failed
- CLIENT 11 passed, 0 failed
- LOOK 72 passed, 0 failed
- WORLD 71 passed, 0 failed
- luau-compile: 60/60 files under src, tests and tools compiled.

Strict analysis was not rerun on Windows; Claude's Linux zero-diagnostic result remains separately attributed. No Studio run or place rebuild: the new pure modules are not wired into gameplay. Both places and the frozen Godot scripts/data/tests/SPEC are byte-unchanged from 61f2d49. The exporter lives beneath roblox_port/.gdignore, outside Godot's imported project tree.

Keep the existing eight/nine-tick sight-loss boundary for parity; no gameplay policy change in this merge. Next: part 2 world sampling, occlusion, peripheral cues, Focus, memory-only marks and labeled target, followed by P01 in Studio and a rebuilt playable place. Flies remain a later chunk.
