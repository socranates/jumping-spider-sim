# Preserve captions verification

Final test source: `bd91ee2ec2f4db1dad296cd2be9fc1ee23f4938e`, evidence `fbcc7d9ce546a9b8`. Its 216 production modules are byte-identical to initial caption source `a36789375dd75920c0eca59ac524644b8776477f`. This branch fixes opt-in captions in the minimalist preserve HUD. Default and Reset are Off only in the preserve; saved explicit choices remain effective. No new setting or save schema.

`check.py --full` builds both XMLs, compiles all 216 modules, checks strict types, runs four targeted suites and five runner regressions, then the full 62-suite Windows run. `verify.py` checks source fingerprints, retained results, release XML contents, CI steps and native caption events. It rejects the test place as a release.

## Native caption check

The local diagnostic build is **never publishable**. It includes one injected SilkPlayback probe, diagnostic Workspace attributes and authored Persistence.Disabled=true. There is no save backend in this test. `build-native.py` builds from source hashes checked against the production commit, with 217 scripts total; the command-bar guard checks the entire authored script set before Play.

Native log: `0.744.0.7441077_20261022T093948Z_Studio_F2FE6_last.log`. Run `1792662057872` passed 18 assertions. The retained bounded events are in `native-caption-events.txt`; source manifest and guard are copied alongside. Five ordered stages verified default Off, Normal, Large, Off and Reset Off. Normal was enabled using the real menu row. Both visible caption sizes reported TextFits=true (15 and 23 point); hunger remained unlabeled throughout. Off hides a currently active caption. The actual client was switched through keyboard/gamepad/touch modes, but no physical controller or phone was tested.

The Normal caption was also visually inspected in Studio at a desktop viewport. The Large stage has native TextBounds/TextFits evidence; its brief screenshot window was missed, so there is no separate visual sign-off for Large. This is not a performance run, persistence/rejoin test, phone/layout matrix or release approval. The probe was stopped after completion. No publication occurred.

## Evidence boundaries

The initial regression used an invalid device name `controller` instead of `gamepad`; it did not demonstrate gamepad coverage. Native uses the correct name. The test-only correction passed a separate 1,398-check targeted run, five runner regressions, 216-module compilation and strict types. Final-source Linux CI run 39758249693 completed successfully (compile, strict types, all suites and runner regressions); ci-final.json retains its metadata and steps. The initial full Windows run passed 62 suites / 443,424 checks, exit zero; it remains bound to a367893, not relabeled as a run of corrected tests. Initial build/type/targeted receipts are retained under initial/.

The earlier baseline regression's first attempt hit a test assertion on an absent shim property; its log is retained as `baseline-regression-initial.txt`. The hardened final old-source run reaches the actual client and fails 17 caption assertions (46 pass), versus 63 passing on the candidate.

A11 is only partially addressed: save-error toasts remain a separate issue. The rig transform cache is an isolated experiment, not integrated here. Foundation audit and performance work remain open.
