# v51 verification ledger

Gameplay source `14e60991c785c4293c3560e6d8b7ecded7e7ac75`, evidence `d9ddc5e0ed43d301`. Published as v51 / Roblox place 140, 2026-10-22T03:07:06.023Z.

## Completed targeted checks

- Windows CLI rare encounter suite: **265 passed, 0 failed**, including real preserve client, a late saved-progress response, deterministic appointment/weather/season gates, dawn, per-life history, generation change, bounded overflow, graph encode/decode/commit, quiet discovery, occlusion, wing support, a real silk attachment with a far-away bend, and cleanup.
- All **215 source modules compiled**. Final changed client compiled again. Strict analysis clean using the Rojo sourcemap and Roblox definitions; informational definition-loading and watcher warnings are not type errors.
- Existing state suite: **503 passed, 0 failed** on the initial candidate; the final all-suites CI result supersedes this partial run. The first notebook candidate found an expected trigger-coverage list that needed the new client-owned event; it was corrected rather than weakening notebook discovery coverage.
- Native source comparison: **215/215** normalized source length and Adler-32 fingerprints matched the final checkout in the local review place, with no extra fixture module during this audit. The manifest also records SHA-256 for the source files. Production must pass the same guard before publishing.
- Final native luna fixture, full: **14 pass messages, completed**. Low: **14 pass messages, completed**. It verifies scheduled absence/arrival, 26-part budget, claim identity, observed notebook page, both supports, attachment identity, a settled motor and short walk, dawn waiting for rider, cleanup, retained page and a new life identity. This is a controlled fixture with a selected eligible appointment, not evidence that a randomly played life encountered it. Earlier corrected candidate B completed 13 checks per tier before the attachment assertion was added.
- Screenshots `native-full-moth.jpg` and `native-low-moth.jpg` show the earlier corrected candidate's real nighttime scene and the spider on a wing. `final-full-moth.jpg` shows the final source on a wing; `final-low-moth.jpg` caught its departure at dawn. Camera was fixed by the local fixture for visual review; production camera code was not changed.

## Native frame samples and limits

Three seconds in the occupied-wing view on this Windows laptop, Studio foreground:

| Source/detail | Frames | Mean frame | p95 frame |
| --- | ---: | ---: | ---: |
| Candidate B/full | 138 | 21.80 ms | 44.40 ms |
| Candidate B/low | 159 | 18.98 ms | 34.34 ms |
| Final/full | 119 | 25.32 ms | 37.77 ms |
| Final/low | 180 | 16.68 ms | 22.73 ms |

These are short observed scene measurements, not a before/after optimization experiment, a minimum-frame-rate guarantee, Roblox Player evidence, or phone hardware measurements. The final full-detail sample was near a strict-analysis run and used a smaller viewport because of the expanded command bar; do not use it as a controlled benchmark against either low sample. No CLI suite ran during these samples. Existing lighting is unchanged. A static settled moth avoids redundant per-frame CFrame writes; at most one 24-part body and two supports exist. Later cicada crowds and moving rides require their own budgets and measurements.

The final complete preserve traversal's later full-detail stress sample was substantially slower: 36.0 ms mean / 174.7 ms worst on the sill, and 73.7 ms mean / 855.8 ms worst in its subsequent far-preserve-removal experiment. That run had created/destroyed roughly 149,000 decor parts while touring the world. Its profiling check passing establishes a valid sample, **not smooth performance**. Keep those raw numbers in `native-final-preserve.txt`; do not substitute the short moth-view samples for whole-game performance or claim an optimization win from this release.

## Initial candidate finding

The first full fixture reached arrival, then failed its history assertion because its hook referenced a history table replaced by the saved-progress reply. Commit `26b15bc` preserves that table's identity and adds a late-response regression. The corrected full and low runs completed. `native-rare-all-passes.txt` intentionally preserves early candidate messages too; use the completed B/full and low sections, not isolated early PASS lines, as final evidence.

A subsequent source review found that testing the current silk pivot's distance would miss a wing attachment after the line bends around a distant object. Commit `14e6099` follows the actual attachment part, and the real silk-controller regression covers that geometry. Both final encounter fixtures were rerun. A preserve traversal on the predecessor source was deliberately stopped for this update; it is not a terminal native result.

## Terminal release receipts

- [Final CI run 39713498101](https://github.com/socranates/jumping-spider-sim/actions/runs/39713498101): **59 suites passed**, source `14e60991c785c4293c3560e6d8b7ecded7e7ac75`. All 215 sources compile and strict analysis is clean. See `ci-final.json` and `ci-all-suites.txt`.
- Native full-detail preserve self-test on the same final source: **274 passed, 0 failed, 0 skipped**. Source guard before the run: **215/215**. See `native-final-preserve.txt` and `native-final.json`.
- Final native luna fixture: **14/14 full and 14/14 low**, both terminal END markers. See `native-final-rare.txt`.
- Clean production place passed **215/215** source fingerprints, correct place/universe, no temporary fixture or debug overrides, streaming enabled and gravity 35 before publication. See `publish-native.txt`.
- Published **place 140**, existing place **120119801868085**, universe **10771103250**, at **2026-10-22T03:07:06.023Z**. Creator Dashboard with **Show published only** checked confirms it; see `published-place140.png` and `release.json`.
- This release implements **one of thirteen** rare creatures. The remaining twelve are planned in `docs/RARE_SIGHTINGS_PLAN.md`; the next two have source notes, not runtime registrations.

The tests establish the controlled encounter and regression coverage described above. A live DataStore rejoin that naturally encounters the moth and physical phone performance were not independently exercised in this release; no such claim is made.
