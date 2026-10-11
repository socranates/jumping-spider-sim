# Shared GitHub workflow

Repository: https://github.com/socranates/jumping-spider-sim

Both Chet and Claude can code this project. Work one writer at a time. The repository files and commits are the shared record; chat history may be incomplete.

## Handoff rule (Nathan, 2026-10-11)

Nathan runs **one agent at a time** and hands off back and forth; he does not merge anything himself.

1. **Start from `main`.** Fetch, check out `main` (or branch from it), and read `claude/where-we-left-off.md` and the newest handoff.
2. **Finish into `main`.** When your turn ends, run the checks, update `claude/where-we-left-off.md` and your handoff, and put your work into `main` yourself (a branch plus a pull request you merge, or a direct push if your setup allows it). Never leave the other agent's starting point on a side branch.
3. **Nathan only says who is up** ("Claude, hand off" / "Chet, pick up from main").
4. **Nathan's laptop gets the latest too.** Nathan asked (2026-10-11) that both GitHub and his laptop be updated after each turn.
   - An agent working on his PC (Chet) runs `update.bat` in his project folder itself (or `git checkout main` and `git pull --ff-only`) after merging, and confirms the folder is on the new commit.
   - An agent in the cloud (Claude) cannot reach his PC. It ends every turn by telling him: "double-click `update.bat`, then `play.bat`".
   - `update.bat` refuses to touch local changes to tracked files and says so.

The rules below about inspecting local work and never force-pushing over another agent still apply.

## Start a session

1. Read `claude/where-we-left-off.md`, the latest `docs/HANDOFF-chunk-*.md`, and Nathan's newest notes.
2. Inspect `git status` and `git remote -v`. If the checkout is clean, fetch and fast-forward from origin/main before editing. If local work exists, preserve it and inspect divergence; never reset or overwrite it to make pulling easier.
3. Continue the named next task. Preserve Nathan's approved mechanics unless he requests a change or a demonstrated bug requires one.

## Finish or hand off

1. Run appropriate checks. Record exactly what ran, its evidence ID, and what is deferred. Headless fixed-FPS tests are not graphical timing evidence.
2. Update `claude/where-we-left-off.md` and the current handoff with completed work, unfinished work, test results, and any reproduction steps.
3. Commit the work and push it to the shared repository. If remote main advanced, inspect and reconcile changes; never force-push over another agent's work. Use a branch when work needs review or is incomplete, and clearly name that branch in the handoff.
4. Tell Nathan which commit/branch the other agent should pull. Do not assume another Claude session shares local filesystem access.

## Evidence and local files

Generated `.godot/`, `tests/reports/`, and `godot_path.txt` remain local. Selected frozen reports and preview images live under `docs/verification/` for cloud readers. The snapshot tool excludes `.git/`; Git history is shared through Git, not embedded inside each game archive.

Evidence hashes cover exact bytes. `.gitattributes` preserves bytes for the hashed game/test assets. Do not normalize those files merely for formatting; intentional byte changes should receive a new evidence ID and appropriate validation.

Engine: Godot 4.7.2 standard build, Compatibility renderer, Jolt physics. A fresh cloud session needs that engine to run the supplied tests; if unavailable, report the limitation rather than inventing a pass. Windows launchers find the local engine separately; no personal path is committed.

## Current baseline

Gameplay and project-settings hashes are unchanged from the fully tested chunk-8 build 182235d71390 (481 passed, one deferred save/load test). GitHub setup only changed snapshot tooling and its regression fixture, producing evidence 779a6714b373. The setup check passed 9 tests (the evidence fixtures plus A01 selected by the file filter); see `docs/verification/github-setup-report.txt`. The older full-suite results are preserved under `docs/verification/chunk8/` and are not relabeled as a full run of the new tooling ID.

Next planned implementation: T09, whole-world retreat checkpoints (S01-C) and accessibility, after Nathan's habitat notes.

### Update 2026-10-10 (Claude, T09 part 1)

T09 part 1 (checkpoints S01-C/S02, keyboard remapping, controller help, text size) is on branch `claude/jolly-bell-gq3mm8`, evidence 4267a104376a, 502 tests, 502 passed, 0 failed, 0 not run on Linux headless (fixed 60 fps). See `docs/HANDOFF-chunk-9.md` and `docs/verification/t09/`. Claude ran in a claude.ai cloud container with its own downloaded Godot 4.7.2, not on Nathan's PC. Its runs are Linux headless evidence, not Windows or GPU evidence.

T09b (hunt feel, same branch) moved the branch head to evidence 8149fa0be2b8, 511/511 on Linux headless; see the T09b section of `docs/HANDOFF-chunk-9.md`.

T09c (2026-10-11) moved the branch head to evidence 25d403c1ee02, 519/519 on Linux headless. Chet's `codex/packaging-spider-legs` (PR #2) is based on 3da4727 and adds files only; merge PR #1, then PR #2.

### Update 2026-10-11 (merge)

PR #1 (T09, T09b, T09c) and PR #2 (Chet's packaging and leg prototype) are merged into `main` (merge commit 41808ac). The merged state was verified before merging: **522/522** on Linux headless at fixed 60 fps, evidence **27b60f6974e8**. Not yet run on Windows.

