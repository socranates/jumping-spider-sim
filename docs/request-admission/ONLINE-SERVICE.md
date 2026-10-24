# Real-store service qualification

This is private continuation/save work on `codex/save-continue`. The published
game remains unchanged. The earlier native memory run and CLI qualification
retain their original scope; neither establishes real-store leave/rejoin.

**Verified:** the corrected private service now completes real-store protected
New, stored checkpoints in Main/Free/Easy, actual departure, a fresh-process
rejoin/ordinary Main restore, another credentialed checkpoint and another real
departure. `online-service-verification.json` and `verify-online-runs.py --check`
bind the two successful runs to the same 273-Source model. This is local Studio
with real Roblox storage, not a published-server release qualification.

## Scope and isolation

The Studio model is bound only to test universe **10771634917**, test place
**109879630247781**, and `WindowsillTest_v1`. Both diagnostic entry points assert
those IDs before application installation. A fixed allowlist permits only the
synthetic actor `qa_3cb3b30963a84dc6` and its P/R/A1/M1/Q1 keys. Normal Persistence
is disabled. The model must never be published or installed in production.

The adapter delegates to real `DataStoreService`, uses engine codecs and real
clock/scheduling, and observes real read/write budget allowances. Its 160/320
rolling limits are explicit diagnostic policy, not Roblox quota claims.
`store.data` is an audit cache of observed API returns, never a storage fallback.
Setup and final proof use distinct short epochs on the same account gate.

The downloaded original test-place backup is separately hash-bound in
`online-service-baseline.json`. Downloading caused Studio to save its existing
test-place draft. No candidate source was synchronized to that cloud editor.
Candidate source is synchronized only to an unpublished local diagnostic editor.

## Failures retained

1. Run **1792798756166**, model4: a diagnostic helper called nonexistent
   `Gate.enqueue`. No SDK request started. The helper now uses `Gate.request`;
   its separate smoke receipt does not count toward product checks.
2. Run **1792799053157**, model5: recovery, original archival and replacement
   succeeded. Main protected New refused and held the client. All three original
   rest archives remained exact, the archive was complete, and the held snapshot
   had 121 created/destroyed read options. The original snapshot omitted the
   worker's precise reason. Its partial-suite Stop also exposed a diagnostic
   `digest(nil)` error for an absent proposal; that is not a product departure
   failure and was not counted as a pass.
3. Run **1792799622833**, model6: fresh uncached reads first verified every
   retained R/A1/M1 digest from that failure, with no seeding/reset and the old
   lease released. Main New reproduced the refusal at phase `write` with
   `jobProblem="New write scope ended"`, session still active. The bounded
   failure detail now reports worker phase/state/problem and session/lease state.

Each attempt has its original diagnostic sources, manifest and failure receipt.
The audit cache JSON exceeded a Roblox log-line limit in attempt2; the receipt
does not pretend that truncated line is a complete stored record dump.

## Callback fix

Protected New formerly checked a coroutine-scoped baseline permit inside the
raw storage transform. That check passes for same-coroutine injected providers
but refuses a transform invoked on another coroutine. A distinct-callback
service regression reproduces the exact refusal with the former condition.

`new-policy-profile.luau` now requires the worker permit before constructing the
write attempt. Its private callback requires that exact attempt to remain
current, the job to remain pending, and all original session/selection/baseline/
deadline fences to remain valid. Completion or cancellation invalidates the
attempt; a callback replay returns nil. Existing raw-source compare-and-swap,
archive/proposal proof, typed admission and uncached retirement readback remain.
No baseline API or ordinary save authority is broadened.

The six additional service cases exercise Main/Free/Easy through actual New,
replacement and credentialed checkpoint saving with transforms on separate
coroutines, plus cancellation before each mode's native transform. Completed
and cancelled callback replays refuse. They are a separate regression cohort;
do not add their counts to the original full suite.

The corrected source is commit **866d217b497fc1f3b06dc305b9fac017792151dc**.
`native-callback-full-1` passes **289497 checks /0 failures**, with every full
summary matching the preceding service qualification. The separate
`native-callback-fixed-2` service cohort passes **2144 checks /42 cases /0**,
including the six new callback cases. All 51 overlay targets compile and pass
the full strict analyzer. The controlled former callback condition fails with
the same `New write scope ended` reason. `native-callback-qualification.json`
binds these outputs and source identity.

`qualify-native-callback.py` binds the exact single-source change, strict mounts,
the unchanged full-suite summaries, additional callback cases and the retained
failing counterexample before the corrected online builder will accept it.

## Repeatable online continuation

`prepare-online-service.py --resume` preserves the actor and generates the
diagnostics/builder. The current partial-source branch is deliberately bound to
the retained failed actor and checksums; it cannot initialize an arbitrary fresh
namespace. With no Q1 control record it verifies those exact retained records
and resumes at protected New. With an `await_rejoin` Q1 it verifies every stored
record uncached and takes the actual rejoin path. Other states refuse.

`build-online-service.py --out <new directory>` compiles and strict-checks all
273 Sources, verifies all 51 private targets from 50 sources, and fingerprints
the local model. `verify-online-service.py` independently reconstructs it.
Before Play, synchronize that model and execute its exact `guard.luau`; the
guard checks IDs, attributes, all Sources and disabled flags.

After all three fresh checkpoints, the client arms a real Kick. Only the actual
PlayerRemoving path after that arm may qualify departure. BindToClose/Stop
still closes the owner but cannot produce success metadata. After closure,
fresh proof checks the released lock, exact original archives and all ordinary
current checkpoints, then inserts guarded Q1 continuation metadata. A second
Play must read that metadata and every stored value fresh, restore Main through
the real menu/callback, obtain a real writable grant, save again and depart.

Release remains gated on those actual receipts. Normal-startup installation,
gameplay/input/comfort/audio/device tests and sustained performance remain
separate work. No general FPS, loading speedup or problem-free claim follows
from this save test.

## Actual results and remaining work

Model7 SHA256 `465c60f09961fa666ae442ee9b37a9a4228325af9c28ad6491f64d5d59ecc783`
contains the corrected callback and unchanged remaining private overlay.

| Run | Scope | Client checks | Server checks | SDK starts | Read options destroyed |
| --- | --- | ---: | ---: | ---: | ---: |
| 1792800470163 | Exact retained failure through all three New/checkpoint paths and real departure | 52 | 18 | 222 | 188/188 |
| 1792800884543 | Fresh process, uncached stored records, real Main Continue/restore/save/departure | 15 | 24 | 37 | 32/32 |

Both runs end with no provider or account scope, released locks, no service
exceptions, exact original archives and guarded continuation metadata. The
first leaves Q1=`await_rejoin`; the second leaves Q1=`done`. The second also
checks the exact restore payload digest and unchanged other current slots.
Roblox logs the intentionally triggered Kick as a CreatorError; it is retained
as the expected disconnect, not mislabeled as zero engine log errors.

Studio's first Kick dialog did not respond to Close/Stop. Its completed server
receipts and released lease were collected before restarting only the owned
local editor. The rejoin then used a fresh Studio process and the same
fingerprinted model. The local Rojo transport was overridden to port34872 on
that restart; model sources/IDs/persistence isolation were unchanged and the
full guard passed again. No candidate was published to the cloud test place.

The first corrected run recorded a server service-step maximum of14.0364ms and
client application/update maximum of5.3955ms, but a whole-client-frame gap
reached1.029s. These are diagnostic observations with copy/logging and Studio
overhead, not matched benchmark/FPS results. Attribute the frame gaps in the
normal startup/gameplay path before claiming the game is reasonably optimized.

Do not run this actor again as a fresh test: Q1 is deliberately terminal `done`.
Preserve its stores and evidence. A future independently seeded test requires
a separate explicit namespace/fixture; this retained-failure fixture refuses
other actors and never silently resets records.

Official references for the diagnostic APIs: [request types](https://create.roblox.com/docs/reference/engine/enums/DataStoreRequestType),
[budget observation](https://create.roblox.com/docs/reference/engine/classes/DataStoreService#GetRequestBudgetForRequestType),
and [Rojo local project binding](https://rojo.space/docs/v7/project-format/).
