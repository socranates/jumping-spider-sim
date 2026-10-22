# Save/Continue: repeated-offer cost reduced; first-load cost still open

Active branch `codex/save-continue`, checkout `C:/Users/natha/windowsill-save-continue`, source `47241c994c7b2fbd4eb3fed0c4affd75ece88c10`. Actual game/menu use protocol3. Nothing published; runtime XML/BuildInfo are still the earlier snapshot and must not be published as this source.

Current source-bound focused proof: **11 suites/1,591 passed/zero failed**,220 compilation, strict analysis clean and runner5. Results: menu32, continuation125, intent57, observation50, state1013, older-peer client161, offline8, storage14, compression57, save notice53 and title21. `cost-reduction/receipt.json` and root `verify.py` verify committed source and exact snapshot inputs. The retained first failed fixture assumed nonnil callbacks for empty-slot withdrawals and reused an old offer id for a new retirement marker. The final fixture handles withdrawals and gives each new immutable observation a fresh id; production was not weakened to accept id redefinition.

The menu/controller behavior remains the explicit-choice flow described in `menu-ready/README.md`: displayed-id New/Continue selection, confirmed replacement of a running world, one-time restore, safe failed restore, separate slots/Easy unlock, correct temporary play on older peers, and exact-credential durable receipts. Fly, feeding and settings are outside these changes.

## Current optimization and paired evidence

- SaveRest.check optionally validates against the actual client world. The client now runs size/type/mode/full-graph validation once, rather than validating against a stand-in and then decoding the graph again against the real world. Server callers retain their original stand-in checks. All3 slots have valid/malformed/input-immutability coverage.
- Offer callbacks carry metadata or nil withdrawal, not an unused deep copy of the complete record. The full record is copied only for explicit consumers/restoration.
- Repeated delivery of the same immutable offer id keeps the previously validated private record, advances its channel watermark and does not revalidate/copy/repaint it. A changed repeat body cannot redefine the private world; conflicting protection cannot redefine the same id. A genuinely new observation still receives full validation and a private copy.

`cost-reduction/paired-cost.py` compares exact baselineac898f4 and candidate47241c9 through one identical233-region checkpoint (2,277,087 canonical characters), serially under the CLI. Raw source/test/probe/bundle hashes and outputs are retained. In one pair, receiving the initial snapshot measured716.6ms baseline/683.4ms candidate; queuing it748.0/699.5ms; outgoing deep copy58.6/52.2ms. These single-run small timing differences are not a causal frame-rate claim. The explicit Continue core sample was slower161.6/210.3ms, reinforcing the need for native profiling.

The decisive repeated-work result was5 unchanged full offers: baseline3,837.5ms and candidate0.0103ms, with validation calls7 to2 and nonempty callbacks6 to1. Both retain the same outgoing2,277,178-character candidate and pass all14 full-world storage checks. The receiver never swaps in the repeat's body; it keeps the previously accepted private observation. Metadata-only100-read loops still make zero full-world copies.

**First-offer and new-checkpoint validation still take roughly0.7s in these CLI samples.** No overall optimized/FPS/phone/network or peak-RSS claim. Heap readings vary with GC. Next profile the actual native offer/queue/restore path and the individual validation phases; investigate cooperative preparation without weakening immutability, message ordering, local checkpoint retention or server authority.

## Outstanding gates

Prior sourceac898f4 full Windows exec63820 and GitHub run39827147497/job119993315925 remain running at last verified poll; do not restart those existing handles on an observation timeout. Their immutable inputs cannot be changed by this newer source. The new47241c9 source has focused gates only; prior full results cannot certify it. Source-bound artifact rebuilding/BuildInfo, native current-feature controls and cost/network/streaming evidence, actual online rejoin, older-world restoration and the broader28-item audit/release/device/collision/audio requirements remain.

Historical menu integration receipts are in `menu-ready/`; the old stable predecessore315b3a has separate full65-suite/443946 Windows/Linux and native synthetic cleanup9-case/62-assertion receipts in `../save-lease-cleanup/`. Overall goal remains active.
