# Actual engine stream-out and return

Production source `695e772d9d1ece490dd32132c655ac60c226c7b8` is unchanged. `verify-engine-stream.py` binds the observations to both saved models, all 222 committed production script hashes plus the private probe, manifests, guards, editor copies and filtered output. Both fixtures are unbound, saving-disabled, full detail and Free play. Both use the actual client and production WorldFocus remote. Neither probe deletes or reparents collision.

| Observation | Default | Opportunistic diagnostic |
|---|---:|---:|
| Checks passed | 11 | 25 |
| Garden/pond collision ready and server focus observed | Yes | Yes |
| Engine removed garden collision while at distant pond deck | Not observed in 45 seconds | Yes |
| Player held while engine collision was absent | Not observed | 4 Heartbeat observations |
| Complete return resumed the same life/motor | Not exercised | Yes |
| CreatorErrors during the running fixture | 0 | 0 |

The route starts on Atomic `garden_b4` (9 physical pieces), moves to distant Atomic `deck_n4` (25 pieces), and requests the garden again if the first model streams out. The settings are 96-stud minimum and 160-stud target radii in both models. The additional diagnostic changes only the stream-out policy to Opportunistic; it does not change production settings. The game reports its location through the existing remote; the probe observes the replicated server focus part rather than moving it locally.

During the four missing-collision observations, position, velocity, mode and life/needs/prey clocks stayed unchanged. Complete collision return released the hold and the same simulation objects continued. Free play clock retention does not independently prove Normal-mode energy behavior. Low detail has not been run in this experiment yet.

The Opportunistic fixture then collected 120 RenderStepped intervals in the garden: mean **16.676 ms**, p95 **18.193 ms**, maximum **18.991 ms**, viewport **1105 x 433**. This is a short foreground sample in a controlled diagnostic/Free play scene. It is not a before/after optimization comparison, whole-game FPS result, phone benchmark, allocation rate or long-session proof. Arrival timings in the raw observations combine collision readiness and focus acknowledgement; do not label them network download latency.

The first preflight failed before Play because Workspace.StreamingMinRadius was not Lua-readable in the installed Studio. No game test ran in that attempt. The corrected builder verifies the serialized radii/policy in XML, resolving the enum through installed Rojo; the runtime guard verifies supported reads, unbound PlaceId, disabled persistence and all script fingerprints. The failed preflight, its exact old probe and a separate editor copy remain preserved (`engine-full-default-preflight-*`). It is a harness correction, not a production-game failure.

Exact final runs:

- Default: `1792762040042`, receipt/output `engine-full-default-attempt-2-*`; model SHA256 `0b6f11341b063f9f194863e045882cefc006f76675066947916d3f5f8d04cc52`.
- Opportunistic: `1792762293163`, receipt/output `engine-full-opportunistic-*`; model SHA256 `8f8aca3b874ffe02ceaf4f0c03dcf6e696bf48b45be8d4bd8c509e52e6c01ccb`.

Both places were stopped and closed, original models unchanged, editor copies saved separately. Studio is closed. The verifier needs these laptop model files; a cloud checkout can inspect committed source/probes/receipts but cannot reproduce native execution merely by running the CLI suites.

Next: repeat the native case at low detail, exercise the loading hold in Normal with an explicit energy assertion, then continue actual recovery menu/profile/model adoption and replacement-epoch work. Keep the current full production gates and native receipts; no production source changed, so those completed gates do not need repeating. Default-policy network/memory pressure, natural whole-life/input/audio/long-session/performance and online/release requirements remain open. Nothing published or merged to main; the broad goal remains active.
