# v51 — Rare Sightings, first build

Published **v51 / Roblox place 140**, 2026-10-22T03:07:06.023Z. Final CI: **59 suites**; native preserve **274/0/0**; native luna **14/14 per detail tier**; compile **215/215**, strict clean. See `docs/verification/v51/release.json`.

Nathan approved **all thirteen, over successive builds**. This release implements **one: the luna moth**, and the shared save/observation foundation. Twelve remain unimplemented. Read `docs/RARE_SIGHTINGS_PLAN.md` for their ordered build groups and acceptance gates; the supplied proposal is preserved in `docs/reference/rare-sightings.md`.

## Source and changes

- Branch: `codex/v51-rare-sightings`, based on final v50 documentation tip `b9bf4ba6384127e82255d11e327852c0adb435b3`.
- Tested gameplay commit: `14e60991c785c4293c3560e6d8b7ecded7e7ac75`.
- Evidence: `d9ddc5e0ed43d301`. The playable and test `.rbxlx` files were regenerated from it.
- New code: `Shared/Data/RareSightings`, `Shared/Life/RareDirector`, `Shared/Life/RareLedger`, `Client/RareBody`.
- Integration touches `SpiderClient`, `SaveProgress`, checkpoint validation and notebook generation. It does not change the fly, feeding, settings or menu implementations. Coordinate before either agent changes those systems again.

## Player experience

A warm, dry spring/summer night may bring a large luna moth to the outer ranger-hut windowsill. It flies in, rests until dawn, and has supporting wing surfaces the spider can walk on. It is ambient life, not a prey/lock target or food source. Dawn departure waits until the spider and its nearby silk anchor are clear, then removes the body and supports. A continuous, unobstructed close view opens a sourced notebook page without a notification. No unseen page, counter, quest marker or collectible reward is exposed.

The first procedural body has 24 drawing parts plus two inset supports at both detail levels. Shapes are intentionally simple; silhouette and anatomy can be refined later without changing the event or save contract. Its nighttime color is subdued under the existing lighting. No porch lamp, bats, new nectar-feeding behavior, full seasonal ecosystem or photorealistic moth asset is being claimed.

## Save semantics

The optional progress `rare` ledger stays outside rest checkpoints. Each new life/generation has a serial; species claims are monotonic high-water marks. A checkpoint during a visit restores the same identity. Rewinding to a pre-arrival checkpoint cannot spawn a replacement for a visit already claimed. Legacy rests reuse the current identity conservatively. The bounded generic `once` map is ready for Atlas/cicadas, but their encounters do not exist yet.

An early native fixture exposed a stale reference after the initial saved-progress reply: the live client replaced its history table while the test retained the old table. The final implementation merges into the existing table, with a real-client late-response regression test. The failed first fixture is not final passing evidence.

The new fields are additive to the existing schema-2 progress and object-graph rest format. Old records with no rare data are accepted. New rare life/visit fields are validated before checkpoint restore. Do not deploy an older server that drops the new progress field against production saves. Once two species are registered, implement a **shared maximum-two appointment budget** before adding independent event rolls.

## Verification and release receipts

The authoritative status, native transcript, CI run, source fingerprints, measurements and published-place proof are in `docs/verification/v51/RESULTS.md` and `release.json`. A source build or a green CLI check alone is not publication proof. The fixture `docs/verification/v51/luna-native-review.luau` is local-place-only and must never be installed in the published game.

## Next build

Start with Eastern Hercules beetle and rainbow scarab. Opened primary sources and remaining range/season checks are in `docs/reference/rare-build-2-research.md`. Add the shared appointment budget, grounded armored nonfood bodies, the lamp/dog-linked visit conditions, quiet sight-gated pages, and persistence tests. Native full/low review must establish support, camera, cleanup and frame cost before release. Moving walkingstick rides and new predator defenses are later builds; do not turn this first moth drawer into a generic catchable creature.

## Picking up the files

Use the latest tip of GitHub branch `codex/v51-rare-sightings`, including its documentation commits, or unpack the transfer recorded in `docs/verification/v51/portable-package.json`. The package includes all active Roblox source/tests/tools/assets and the one frozen `data/notebook/pages.json` input needed by the notebook generator. It excludes the Godot runtime and old snapshot archives. Create the next build's own branch from this tip; do not begin from the older `main` or replace it with a fresh empty project.

From `roblox_port`, run `python3 tests/run.py /path/to/luau`; the focused gate is `python3 tests/run.py /path/to/luau rare_sightings.luau`. `tools/check.sh compile` and `tools/check.sh types` use the tool paths described in `.github/workflows/roblox-port.yml`; `python3 tools/build.py /path/to/rojo` regenerates both places and the evidence ID. A cloud CLI run does not establish Studio collision, streaming, audio, native frame times or publication. Keep those claims separate until locally verified. A long full-detail traverse still shows uneven frame times; preserve the raw measurements and the maximum-two encounter budget before adding crowds.

Preserve Nathan's existing controls, seven/ten whole-meal moults, surprise Run/lock unlocks and quiet HUD. Keep the original OneDrive project and synced `sources/` read-only. The writable clone is `C:\Users\natha\windowsill-publish`; push only the dedicated branch to remote `github`. Godot remains frozen.
