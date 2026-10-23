# Save service owner: production verification

Source under test: `2170f99e001c4c0a42e86454974f594820e86667`, on `codex/save-continue`. This adds independent admission capacity for recovery receipts to the optional service owner introduced in `927e816`. The default engine startup still creates a normal SaveSession. No publication or normal-save migration is claimed.

The reason for the fix, private adapter and actual service/client transport cases are documented in [RECOVERY-SERVICE-OWNER.md](../save-slot-isolation/RECOVERY-SERVICE-OWNER.md). The older `save-service-owner-hook/` directory records the superseded initial hook.

## Exact-source gates

`full-verification.json` is the terminal combined proof. Its verifier refuses to produce it while the Windows process is live or the Linux job is incomplete. Do not infer a full pass from `windows-full-start.json`: that file intentionally retains the historical start status.

- Windows: `full.py` extracts an immutable Git archive of the exact source and tests into a temporary directory. `windows-full-process.json` records terminal exit and the input hash map; `windows-full.txt` retains the output. Expected result: 76 suites, 468,506 passing checks and zero failures.
- Linux: [run39945051568](https://github.com/socranates/jumping-spider-sim/actions/runs/39945051568), the existing push job for the same source. `ci-final.json` retains job/step metadata and downloaded log hashes. `ci-suites.txt` contains 76 suites and 468,506 passing checks with zero failures. Pinned tool downloads passed their checksums.
- Production compile and strict analysis: `checks.json` binds 222 compiled modules, clean strict output and five runner infrastructure regressions. The runner log deliberately includes rejected missing-file cases; its terminal `Ran 5 tests` and `OK`, with exit0, are the gate.

Verify the retained artifacts, without rerunning completed suites:

```powershell
python docs/save-service-owner-final/verify-gates.py
python docs/save-slot-isolation/verify-recovery-service-owner.py
```

The second verifier covers a separate private cohort: 2,745 new service-owner assertions plus 184,404 preceding assertions, 187,149 total. Its adapter uses actual SaveService, SaveClient and datastore/compression adapters over a fault-injected memory facade. These counts are separate from the production-suite total. Entry compilation and full strict analysis of all 34 private candidate modules are retained in `service-owner-types-3-*`.

## Local candidate

`build-production.py` built `C:/Users/natha/claude-xfer/Windowsill-production-2170f99/TheWindowsill-production-candidate.rbxlx`. All 222 script sources match the committed source exactly; no private prototype or injected diagnostic is included. `production-candidate.json` records SHA-256 `59bb06d720169a727976e6a80be3eb11058569edc439bc245ea8563992eba0bd`. The earlier `441eaca` model remains untouched. This new candidate has not been exercised in Studio or published.

## Evidence limits and next work

The full production CLI gate does not prove native gameplay, physical controls, real online datastore/rejoin, frame rate or publish safety. Earlier native evidence belongs to its recorded source and component scope. In particular, a narrow native budget-observer probe does not cover whole recovery.

The private owner is selection scoped. The real menu does not yet defer protected legacy restore, adopt the server's recovered world, or pause/resume around its receipt/grant. Capability negotiation, destination profiles, explicit replacement epoch handoff and measured entry payload/resend costs are also open. Keep live engine installation disabled. [CLIENT-INTEGRATION-PLAN.md](CLIENT-INTEGRATION-PLAN.md) gives the next implementation order and acceptance cases. The broader optimization/reliability goal remains active.
