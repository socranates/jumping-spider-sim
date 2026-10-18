# Public-release readiness — 2026-10-17

The Windowsill is a playable private test experience, not yet a durable public release. This round updates the existing place (universe 10771103250, place 120119801868085), without changing who can play.

## Recommended order

1. **Persistent player progress and rest saves.** Implemented and reviewed (ROBLOX-39..47): real isolated DataStore checks passed, with notebook and separate rest records. Windows verification and publication status are in verification/roblox-state-windows/RESULTS.md. Physical PlayStation leave/rejoin remains a release check. A failed load must never overwrite good progress with defaults. Keep player discoveries separate from world rewind and main/Free-play saves.
2. **Settings and device polish.** Give players usable sound/reduced-motion/camera/accessibility options, fix cramped touch gameplay controls, and verify a complete life with physical PlayStation and a lower-end tablet. Studio checks are not physical-device acceptance or a controlled F01 performance pass.
3. **Release presentation and science review.** Choose a proper icon/thumbnail/description and explain Standard versus Free play and saving. Review inherited notebook claims and asset/source provenance; existing citations do not mean every paper was read in full. Keep the daughter's spider and whole game free. Peacock remains free for testing until Nathan changes that decision.
4. **Nathan completes Roblox account/audience prerequisites, then chooses release scope.** These are separate from whether the game builds or publishes.

## Dashboard observed read-only

Creator Dashboard > Manage audience showed **ready to test**, available to the creator, collaborators and early testers; it explicitly said playtesters under 16 do not have access. Its wider-audience checklist marked identity verification, two-step verification and the content-rating questionnaire incomplete. It also showed 0/250 highly engaged players for review and a 1,000 Robux Kids & Select publishing-fee item, with an optional refundable fee mentioned for speeding review. These are displayed requirements, not a promise that paying immediately unlocks all ages. Nathan must review the current flow himself before identity, security or financial actions. No account changes or fees were made here.

Evidence: `verification/roblox-notebook/merged/audience-readiness.png`. Recheck immediately before release. Official references consulted:
- https://create.roblox.com/docs/production/publishing/publish-games-and-places
- https://create.roblox.com/docs/production/publishing/kids-and-select

A limited public alpha could intentionally remain session-only if Nathan accepts that limitation and the store page says so clearly. For the kids' whole-life game, durable saves and device acceptance are the recommended readiness bar. There is no honest single percentage for the remaining work: the loop is playable, while physical-device acceptance, presentation and platform audience requirements remain.
