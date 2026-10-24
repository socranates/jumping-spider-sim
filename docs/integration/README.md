# Normal build integration — 2026-10-24

Branch: **codex/verified-integration**. Local checkout:
C:/Users/natha/windowsill-verified-integration. This activates the verified
273-source candidate into the ordinary Roblox source tree. No publication.
The frozen verification checkout remains C:/Users/natha/windowsill-save-continue
at c457af12; OneDrive, Godot and synced project references are unchanged.

## What is integrated

promotion.json records59 added/changed files from the224-source base. Their
normalized bytes match the native-verified font candidate, model SHA256
64a3ff7e865ce53d401569e8e12605ddff419028ccfd887d518e03e2514b0a6b.
This includes the previously qualified save/Continue recovery, ordinary startup,
scenery cache, title reflow and one-line touch-font fix. No new game rules.

The normal CLI now discovers269 ModuleScripts lazily, preserving separate
server/shared admission facades. The qualified server-clock shim and12-check
title regression are included; the default is79 suites. check_runner.py proves
all79 programs match qualified staged programs byte for byte after normalizing
only the independently verified font assignment. This is program equivalence,
not a new native execution. Five runner infrastructure checks and143
selected normal-path checks passed. The standard Windows command then completed
all79 suites with468979 top-level passes and0 failures (exit0). full-cli.txt and
full-cli-receipt.json retain the ordered summaries and exact input/model hashes.
collect_full.py --exit-code 0 --check revalidated that completed output before
any later source edits; use the receipt's cohort when interpreting this result.

## Normal commands

Use Python3.10+ and the pinned toolchain in the GitHub workflow. From roblox_port:

    python tests/run.py /path/to/luau
    python -m unittest discover -s tests -p test_runner.py
    python tools/build.py /path/to/rojo

The normal source and these commands need no external Windows staging folder.
The promotion script is a local provenance tool, not a prerequisite to build
a clone. Native historical collectors still require their original laptop logs
and snapshots; run older source-derived verifiers in the frozen proof checkout.

The build exports TheWindowsill.rbxlx (normal gameplay) and
TheWindowsillTests.rbxlx (local Studio self-test). Both contain273 identical
game sources. Normal mode excludes PortTests and uses ordinary store selection.
The test model contains an empty PortTests marker, current Client/SelfTest,
fresh test owners and WindowsillTest_studio_integrated. It excludes the legacy
server runner and SilkPlayback that previously contaminated a test.

**Never publish the self-test model.** Open it locally, press Play and inspect
the original SELFTEST END line, failures, warnings and skips. An unbound model
cannot prove real DataStore behavior. Legacy PORT_TEST_REPORT collectors apply
to the retired runner, not this export; its source fixtures remain in Git.

build-receipt.json records the output hashes, source hashes and authored mode.
The portable evidence ID is Workspace.PortEvidence in generated models. The
builder checks lighting/material invariants, source identity/enablement and
normal/test separation, then cleans its temporary project files. It does not
stamp source files; old BuildInfo belongs to the legacy runner. Current build
evidence:4f45e2b55221e1f3. Build identity is not native execution or publication.

## Evidence and remaining work

The integrated sources compiled273/273 and passed strict analysis on the normal
project mapping. compile.json and strict.txt retain those results. The native
font proof is in ../touch-labels; full pre-font CLI repeat and native/online
storage proofs retain their exact earlier cohorts. No claim that a narrow font
check completes controller, phone, audio or full-world performance verification.

The published production baseline remains140; private test13 predates the font
fix. No new upload, main merge or laptop synchronization is claimed. Follow
../audit/HEALTH-CURRENT.md and ../../chet/save-continue.md for the remaining
audit, content correction, source/CI checks and release decision. Linux CI run
40067737217 is still running at this checkpoint; Windows success does not
substitute for that independent job's completion.
