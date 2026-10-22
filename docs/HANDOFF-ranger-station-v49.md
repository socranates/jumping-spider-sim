# Ranger station v49 — work in verification

Branch: `codex/v49-ranger-station`. This is not a published release receipt.

Latest state: `docs/verification/v49/IN-PROGRESS.md`. Final production freeze is **5938aac41371ca005f73e4c21e7089404496b9a6**, rebuilt evidence **542472fc2539e00f**. **Not published.** The native self-test finished **271 pass / 0 fail / 0 skip** on predecessor `1f81d7c`; the full CLI is still running. Subsequent single production change: three dark inset rug drawings are full-detail-only, retaining the physical rug and full-tier appearance while bringing low decoration from 153 back to the unchanged 150 cap. Final preserve rerun **1154/1154**, station **38/38**, HUD **37/37**; final strict clean and compile **209/209**. These supersede early counts below. Do not publish the older v49 candidates.

The Windows control helper timed out during stop/state capture after the self-test, including recovery retries and a kernel reset. **Stop outcome and current debug attributes are unknown.** Recover with fresh observation before cleanup or publication. Cloud Studio was disconnected on v48. Native performance samples overlapped CLI work and are not a final performance claim.

Final archive: `C:\Users\natha\claude-xfer\v49-final-5938aac.zip`, SHA256 `b9d5ad3dea54899df2c07e19c6466334b8cb1e06520c8b78da5787b6a2833fab`. Rebuilt outputs: `C:\Users\natha\claude-xfer\v49-release-5938aac\roblox_port`; playable SHA256 `66200ccf3b206653385d5254f17f1954bb65aaf38665f81d4d76d5c08309870c`. XML matches **209/209** source files. The regenerated `C:\Users\natha\claude-xfer\v49-final-source-audit.luau` targets this source/evidence; use it to verify stopped Studio. Tracked repository `.rbxlx` files are older: use rebuilt outputs or build from source.

Cloud Claude can clone `codex/v49-ranger-station` from `https://github.com/socranates/jumping-spider-sim.git`. Local C: links alone do not transfer files. Preserve the failed predecessor budget record and passing final-source rerun; do not describe them as a single 56/56 final-source run. See `native-selftest-final.txt` for the complete latest native output.

## Player requests implemented

- A slightly larger, wordless reserve bar: 150 × 6 pixels.
- A tiny 2 × 2 pixel manual aiming dot from the beginning. No new aim assistance, reach colours or hints. Hidden during sleep, death and modal screens.
- The back room's sash is cracked five centimetres. Its outer sill, rough log descent and ground meet the existing path. Fixed the exterior casing, previously a solid panel across the window.
- Nearby sustained walking wakes a sleeping cat. It gets down along its existing authored route; creeping does not wake it. Notice range is 125 cm and recovery is 12 seconds. Cover blocks sight and interrupts attacks.
- Fixed the client reporting identical speed for creeping and walking: cat movement evidence now comes from displacement. Added the new field gear to its stalking obstacles.
- Station field gear: radio with antenna and display, thermos, boots, field pack and first-aid case. Physical support remains present on low graphics.
- Three scattered house flies on floor clusters, one per occupied cell at either tier. Seeded positions, actual flight/feeding directors and existing offscreen replacement rules.
- One ambient mouse travels supported routes through both rooms, pauses and scurries near danger. It is neither a meal nor a new damage source. Sixteen non-queryable presentation parts.

The existing run/lock moult gates, seven then ten whole-fly meals, movement/camera, rival and wasp residency remain in place. The new back window can be reached before Run; escape should be difficult rather than artificially locked. Difficulty needs player feedback.

## Verification to date

- Focused station CLI: 33 passed, 0 failed. Real motor traversal through the crack, down logs and onto the path; floor-fly support/population; mouse determinism, floor support and part budget.
- Minimal HUD CLI: 37 passed, 0 failed, including the tiny starting dot and no unwanted words/ticks.
- Preserve CLI: 1154 passed, 0 failed before the final thermos drawing/obstacle additions. Station threats: 32883 passed, 0 failed. Client smoke: 27 passed, 0 failed.
- Strict analysis clean and 209/209 modules compile before those final presentation/obstacle adjustments. Repeat against final frozen source.
- First native full-tier Studio pass: manual dot and reserve dimensions verified; actual creeping leaves cat asleep, actual walking wakes it; native route motor reports zero detached ticks and reaches the path at x537. These were isolated Free Play diagnostics in a local place (PlaceId/GameId 0), not a complete Normal-mode difficulty playthrough or performance benchmark.
- Native first pass predates rounded thermos presentation and the final added cat obstacle bounds. Repeat final-source native checks.

## Still required before release

1. Complete the frozen full CLI suite, final strict/compile checks and Studio self-test.
2. Review final full/low station visuals, mouse, cat visibility/cover, floor hunts, exits and performance. Save screenshots and logs.
3. Remove all temporary playback and Workspace overrides. Rebuild playable artifact from verified source; compare all script sources.
4. Publish only to existing place `120119801868085`, universe `10771103250`, then verify the published version in Creator Dashboard.
5. Push this branch to remote `github`; never push the read-only OneDrive `origin`. Supply a bounded handoff package and release receipt. Do not modify Claude's branch or merge main.

`docs/verification/v49/station-playback.luau` is an isolated Studio review driver, not production code. Do not publish it as `SilkPlayback`.
