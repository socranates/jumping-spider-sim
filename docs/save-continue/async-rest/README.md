# Local last rests prepare across frames

Unpublished source `133aa60342d03b534f9dbbf5f6399244714b9fc7`, on `codex/save-continue`. Release XML and BuildInfo still describe older code. Do not publish this diagnostic place.

## Behavior

The simulation captures a coherent snapshot synchronously at the existing safe tick boundary. Validation, local store encoding, defensive copies and network candidate preparation then run on private inputs across frames. The old local rest stays visible until a complete validated replacement is ready. Publishing swaps the store once without yielding. The previous valid rest remains the backup. The source store's revision, slot, world generation and pending token must still match.

New rest attempts supersede old jobs. New lives, explicit returns and generation changes cancel obsolete work. Storage failures leave the committed current/backup data intact. A broken network path does not disable local last-rest storage. The UI does not announce a rest before completion; an actual network Saved status still requires the exact durable receipt. Delayed successful completion preserves newer visible gameplay notices, including the run unlock. Delayed failure remains visible alongside them.

Memory-store forks share only store-owned immutable entries, with independent dictionaries and metadata. Get/Remove return defensive copies, Set copies inputs, and Set/Remove advance mutation revisions. Pending lifecycle tokens and private presentation revisions do not enter captured world records. Valid direct restores finalize external pending tokens as cancelled.

The lifecycle save callback now returns a mutable `{ok=false,pending=true,message=""}` result for accepted work. `ok` becomes final only when `pending` clears; cancelled results have `cancelled=true`. Existing immediate refusals remain immediate. Native SelfTest and CLI fixtures wait at storage completion boundaries. Controlled clock fixtures use zero-delta actual frames while preparing; a separate actual-client test explicitly proves normal live simulation continues.

## Verification and remaining work

- Prior source `8db0f6d` now has terminal full Windows and Linux success: 72 suites / 444,582 checks / zero failures on each platform. Those receipts belong to that source, not this change.
- Current focused regression and native receipts are collected alongside this document. Compiler receipts under `release-check` bind the final source bytes. Earlier compile attempts are retained separately.
- This does not make snapshot capture asynchronous: coherent capture still costs a frame. Local Continue, Backspace and end-screen last-rest return remain synchronous. Large remote Continue latency and occasional long cooperative steps also remain optimization work.
- Shim tests do not prove physical controls, rendering, comfort or native engine behavior. Studio diagnostics use a local unpublished place and disabled production persistence; no online/rejoin or physical-device performance claim.

The broad foundation goal remains active. Save compatibility, all dormant ecology, exact request/epoch/ticket authority and confirmed selections must remain intact. No release or laptop synchronization is claimed.

## Native result, 1792699532277

All 15 assertions passed, with zero Creator errors and all 223 script fingerprints matching source. Production Persistence was disabled and PlaceId was zero. The diagnostic was stopped, saved/closed, Studio exited, and the original diagnostic bytes/hash restored.

For a 1,501,336-character record: coherent capture took 139.495 ms; first-rest preparation took 693 steps / 11.691 s elapsed / 1.628 s CPU, maximum update 40.284 ms. Replacement preparation (including preserving the prior rest) took 1,091 steps / 18.515 s elapsed / 2.609 s CPU, maximum update 52.894 ms. Preparation is spread over actual frames; there is no claim of reduced total CPU or a hard 2 ms frame ceiling. Initial Heartbeat gaps can include preceding synchronous capture/probe canonicalization and must not be attributed solely to worker updates.

The paused large-record cases provide repeatable cost measurements. A separate small fresh-world running case completed in ten steps and proved prey ticks/lifecycle time advanced while preparing. This is not a fully explored running-world performance test. There were 233 region initialization attempts subject to streaming readiness; resident ecology counts were not measured. Studio reported Low System Resources; no controlled FPS speedup or physical phone performance is inferred.

CLI focused receipts and full gate status remain separate from the native proof. New full Linux run 39846269494 checks source 133aa60; a new full Windows archive run will be retained here. Expected 74 suites / 444,637 is not a passed result until both finish.

## Corrected focused verification

Verification source c4bcc6a changes only the title-screen fixture: it awaits actual rest completion before asserting Continue/Resume. The original focused run is retained with its single title fixture failure. Its other22 suites passed; the corrected title suite independently passes21/0. The verifier binds all current inputs, permits only that test-file difference, and aggregates23 suites /25,187 passed /zero remaining failures. Runtime source remains133aa60 and exactly matches all223 native fingerprints; no native or compile rerun was needed for a test-only correction.

Windows98692 and Linux39846269494 use the original title fixture and are superseded for current full-proof purposes. Preserve their terminal results. Current corrected Linux run 39846956444 is active. Corrected full Windows run waits for98692 to close, then uses full-corrected.py. Expected74/444637 remains unverified.
