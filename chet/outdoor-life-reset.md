# Outdoor life reset handoff

Source `3c8de801e5fab68598e1e5323e7f5e1c8151b0e6`, evidence `d543592dddf4e621`, branch `codex/outdoor-life-reset`. Unpublished; the branch inherits the caption fix and earlier foundation work.

New Life and successful return to a rest now clear unsaved frog, crab-spider and robin encounters. Same-day restarts previously retained combat/cooldown/sighting state. Resets preserve object references, seeds and enable flags, then apply the current rule mode. The client's stale robin-shadow cue and frog tongue target are cleared. No save schema, hunting rule, schedule, movement, camera or habitat change.

The old frozen source fails 15 assertions in the new preserve integration regression. The fixed regression passes 45. Five targeted suites pass 29,166 checks; 216 modules compile, strict types are clean, and five runner regressions pass. A source-guarded native Studio run passed 46 assertions with persistence disabled, including actual client New Life and in-session rest recovery. This does not prove online rejoin or performance.

See docs/outdoor-life-reset/README.md and receipt.json for exact bindings, test limitations and unfinished full-run/CI gates. The local native review place is diagnostic and must never be published. Continue polling the existing Windows process and CI run 39761460756; do not restart a live test because an observation times out. Resolve any failures before promotion.

The animation cache remains an isolated experiment with modest/mixed timings; it is not integrated. Remaining audit work includes the long memory session, legacy-world save policy, foreign-lock Continue UX, AI preparation timing, save-error presentation, toolchain pinning and native/phone checks. No claim of overall problem-free status or release readiness is made.
