# Save slot isolation candidate

Unpublished branch `codex/save-slot-isolation`, source `3647a94c67f83076a0c7be09d75ef4a60bb0b4d5`, evidence `1984fdd8e8dee0ad`. Builds on the independently verified save adapter fix (`dc1c4b8`); includes the earlier lossless compression and durable New Life work.

## Player-facing change

One unreadable or newer rest now protects its own slot for the remainder of the visit. The notebook and unaffected main/Easy/Free rests continue saving. The protected stored envelope and its backup are never repaired, retired, overwritten or deleted automatically. A valid backup may be offered in memory. The menu explains the partial protection instead of claiming either everything is Saved or everything is session-only.

Unreadable progress still stops all saving. Foreign ownership and life identity checks still apply. Temporary API read failures retry and do not permanently protect a slot. A new visit reevaluates externally repaired storage. No storage or network protocol schema increment is required; optional protected-slot metadata extends existing loaded/status messages.

## Implementation

SaveSession keeps a per-slot protection map and abandons only that slot's queued work. It refuses replacement rests and New Life intents before mutation; UpdateAsync callbacks also cancel when protection has been established. Life request serials remain to prevent delayed intents becoming fresh. SaveService sends copied protection metadata on load and status changes, and resends it on a refused protected-slot life intent. SaveClient drops futile queued requests for that slot, ignores late life acknowledgements, and keeps protection sticky across repeated load replies.

Save-status wording is the only menu presentation change. No fly, feeding, settings, movement, camera, lighting, habitat or golden data changed.

## Verification

See `docs/save-slot-isolation/` for exact receipts. Regression cases cover all three slots against corrupt, invalid and future envelopes; unaffected saves through a rejoin; backup preservation; heartbeats; no false retirement acknowledgement; transient reads; sticky protection; client retry suppression and server metadata. Existing corrupt/future progress tests remain globally conservative. Tests previously expecting an unreadable rest to stop every save now assert slot protection and retain the original no-overwrite assertion.

The 216 source modules compile and strict types pass. Release XML matches all 216 source fingerprints, with no diagnostic helpers. The preflight refuses the test-place XML. Windows final-source targeted verification: four persistence suites, 957 checks, exit 0. The first broad Windows run completed with 61 successful suite summaries and one obsolete rest_storage assertion; its failed process and original log are retained. The corrected full-world test adds independent notebook persistence and still checks the exact damaged stored bytes. The final follow-up commit changes only that test and the generated test evidence stamp. It does not change production code. A full Windows run after that test-only update was not repeated. Final Linux CI on the exact source passed all 62 suites / 443,398 checks, strict types, compile and five runner regressions: https://github.com/socranates/jumping-spider-sim/actions/runs/39739254321. The receipt confirms all offline gates; publication readiness remains false.

Native Studio verification now passes on this exact source: all 216 production source fingerprints matched before Play; preserve self-test 274/0/0; nine native codec/session cases, 110 checks, using the 2,276,508-character fixture. The probe verifies protected compressed bytes, readable backup, independent notebook/healthy-slot persistence and session-level rejoin for main/Easy/Free and corrupt/invalid/newer envelopes. It uses a local synthetic backend. Actual client disconnect/rejoin and online DataStore verification for this changed source remain outstanding. It is not published or release-ready. Do not publish any diagnostic/test/profiling place. The preflight refuses all six known diagnostic artifacts.

## Remaining foundation work

This isolates the consequences of the historical-world compatibility issue; it does not migrate an old test_garden ecology into the preserve. The remaining audit includes deterministic route activation, foreign-lease Continue UX, caption/error visibility, measured full/low scene profiling and the long memory trace. The greedy-merge analysis is on the separate `codex/greedy-merge` branch and correctly stopped below the requested ten-percent gate; there is no runtime merging to integrate.
