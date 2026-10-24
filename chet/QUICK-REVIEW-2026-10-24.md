# Quick review for Claude — pause point, 2026-10-24

Nathan asked for a short Claude review before Chet resumes. This is a review handoff, not a request to redesign or implement the next changes. Return findings and any design decisions to Nathan; he will bring them back to Chet.

## Where to start

- Repository: https://github.com/socranates/jumping-spider-sim
- Branch: `codex/verified-integration` (fetch this branch explicitly; do not assume main has this work).
- Local working checkout: `C:/Users/natha/windowsill-verified-integration`.
- Latest evidence documentation commit before this handoff: `62269f2a`.
- Source/test commit: `3f6ed486cf0a6fa2b20c47c1b0c857ef7ff98200`.
- Active project: `roblox_port/`. Godot is frozen. Leave the OneDrive original and synced project `sources/` alone.
- `roblox_port/sourcemap.json` is an existing untracked local file; it is not part of this handoff and must not be staged or overwritten.

Read `docs/generation-route/README.md`, `qualification.json`, and `native-final/native.json`, then the latest headers of `docs/audit/HEALTH-CURRENT.md` and `chet/save-continue.md`. Older sections retain historical results and rules; do not treat them as current design instructions.

## Qualified result

The default **female** spider completed a controlled native reproductive route in Normal, Easy and Free: 90 complete meals, nine moults/hardenings, three matings/sacs/guarding/hatchings, three guarded-family local returns, and three newborn local returns. Normal used its live seeded acceptance decision (first court refused, next accepted). Free used Follow and reached an attached newborn after 12.075 seconds. The 276-source diagnostic guards passed before/after, and Studio exited with the immutable model unchanged. Zero game script errors; six retained Studio style/asset warnings.

This fixture scripts captures, safe positions and player approach/facing, accelerates waiting clocks, and uses an isolated yielding memory backend. It is not evidence of natural hunts, complete map collision, real online persistence/rejoin, physical input devices, or FPS gains. The three routes are difficulty coverage, not sex coverage.

Full CI succeeded on source/test commit `3f6ed486`: all 80 suites, compile, strict typing, normal/self-test exports, and runner cleanup checks. Receipt: `docs/generation-route/github-ci.json`. Run: https://github.com/socranates/jumping-spider-sim/actions/runs/40102350037

An apparent three-meal reset after Carry was a disproved observer hypothesis. The UI callback precedes the ordinary tick that already admits the seven-meal rules, before feeding. No game-code fix was made for it. The added client assertion passed unchanged game sources. `red.txt` and `defect-native2/` retain their original investigation names but are explicitly explained as passing evidence / a deliberately stopped partial run, not a confirmed product defect.

## Nathan's newest decisions — not implemented yet

1. **Normal progression must be 7, then 15, then 20 meals** for the three moults. Current code is still Normal 7/10/5. Easy/Free are currently 7/10/3; Nathan specified Normal, so leave their thresholds alone unless he says otherwise. Preserve consumed growth credit, previously earned stages and unlocks, and an already-ready save. Keep the counter derived from the actual threshold; do not replace meals with days. Run remains unlocked after moult 1, lock-on after moult 2. Existing native receipts prove the earlier thresholds and must not be relabeled as validating 7/15/20.
2. **The spiders must not walk through each other after mating.** This is a reported problem to reproduce and fix, not a completed fix. The mate currently routes toward its exit via `MateDrive` -> `RivalDrive` -> the kinematic `SpiderMotor`; no partner body avoidance was found on that route. Review both player-into-mate and mate-into-player movement, both mate sexes, ordinary departure and skipped scenes. Keep purposeful courtship/mating contact, surface attachment, retreat exclusion, world obstacles, and stable controls. Prefer a bounded clearance/steering fix with actual movement tests, not a teleport or decorative pose offset. Native visual verification is still needed.
3. **The male does not lay eggs or care for the young.** Nathan and Claude are discussing separate male and female playthroughs. Keep that design open for their discussion. Current `Mating.sexOf` selects a sex from appearance, but `Mating.woke` creates the sac after mating without a sex gate: a known male-route design gap. The native route above used the default female; it does not validate male brood care. Do not invent a male continuation mechanic during this quick review.

## Questions for the quick review

- Do the source/log/CI receipts support the female-route claims within their stated limits? Any concrete missed life-cycle or save regression?
- For the future Normal 7/15/20 change, any save-readiness or difficulty-switching edge case we should cover before coding?
- For post-mating clearance, what is the smallest safe fix and which native reproduction should gate it? Flag any concern with leg/body size, walls, differing support planes, or player movement.
- Capture the male/female design direction you and Nathan agree on separately from the existing female audit; distinguish agreed decisions from proposals.

Please cite actionable findings by file/function, severity and reproduction. A brief prioritized review is enough. Do not publish, merge, or make broad changes for this review.

## Publication / resume boundary

No new release was published by this audit. Private Windowsill Save Tests remains v14, evidence `032b5985ac17eeb2`; ordinary current export evidence is `5e9ac432e9933ed9` (273 game sources). Production, main, the OneDrive original and frozen Godot were not changed. The broad optimization/foundation audit is incomplete and is now paused at Nathan's request. Studio/Player are closed; no native run or pending operation needs preserving.

On resume, read Claude's review and this handoff first, implement the two new concrete changes above with focused regressions and full CI, then obtain native collision evidence. Continue the broader natural-attack, world-collision/content, device and measured-startup audit afterward. Do not claim the old native cohort validates new code, and do not publish a newer candidate under the earlier private v14 authorization.
