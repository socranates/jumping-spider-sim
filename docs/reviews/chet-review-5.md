# Chet review 5: T09 / T09b

Reviewed PR [#1](https://github.com/socranates/jumping-spider-sim/pull/1), branch `claude/jolly-bell-gq3mm8`, commit `3da472772732b99fba539edb0533b3ba5dcf5406`. Review performed on Windows with Godot 4.7.2 standard. Nathan approved the existing mechanics and asked for packaging and a separate leg prototype; no shared gameplay file was changed in this review branch.

## Findings

### P1: saving overwrites an unsupported newer checkpoint

`scripts/persistence/checkpoint_store.gd:114–123`. `decode()` correctly refuses a newer schema, but `save()` treats every refused current file as damaged and deletes it before installing the new checkpoint. Reproduction: write an otherwise valid record with schema 3 (this build reads 2), call `load_best()`, then save a valid schema-2 record, as resting does. Loading reports that the newer file was left untouched; saving returns `ok=true` and the newer file is gone. Reproduced against the reviewed code in an isolated test save directory on Windows. This can destroy the player's only newer-build checkpoint when they briefly run an older build.

Requested fix: distinguish unsupported schema/content from actual corruption before any write, refuse overwriting it or preserve it under a separate recoverable name, and show a clear explanation. Add a regression for **save after newer-schema refusal**, not only refusal on load. Consider a good backup from a newer build as well. No fix is included here; coordinate the persistence change with Claude.

### P2: remapped feeding/cancel keys still have default-key prompts

`scripts/needs/feeding_controller.gd:196–200` and `scripts/presentation/pause_menu.gd:129`. Remapping Eat/rest from E to another key updates the action, but the ordinary Holding prey/Eating prompts still instruct E (and Q for cancellation). The release-line option also hardcodes Q. The new struggle prompt already uses `_key()`, so a player sees a correct remapped key during the struggle and an incorrect one immediately afterward. This makes the remapping accessibility feature misleading during the core loop.

Requested fix: generate all these prompts from current bindings, including controller alternatives, and cover the post-struggle/feed/cancel prompts in remapping tests. Nathan asked for advance coordination before feeding/settings/menu edits; those files remain untouched on this branch.

## Scope and assessment

Reviewed checkpoint capture/validation/store/restore, hunt struggle and escape bookkeeping, keyboard remapping and UI flow, habitat changes, cosmetic twitch integration and associated tests. The world-replacement checkpoint approach and separation of cosmetic motion from motor state are sound design choices. Neither a passing suite nor this review constitutes exhaustive proof against malformed save records, real power-loss recovery, browser persistence failures or every input device.

The prototype remains suitable for continued development, but address the checkpoint-overwrite finding before describing unsupported saves as safely preserved. Do not merge or modify the protected files merely because this review documents a fix. Coordinate ownership with Nathan and Claude first.

## Verification

The baseline snapshot matched **8149fa0be2b8** and its archive read-back verified every file. Full Windows launcher results and packaging/prototype results are recorded in `docs/HANDOFF-packaging-legs.md`; archived reports live in `docs/verification/packaging-legs/`. New prototype files intentionally give the development branch a different evidence ID.

The native normal-speed run did not reproduce Claude's all-pass Linux result: `test_supported_locomotion.gd::test_support_view_toggles_with_f4_and_draws_the_normal` fails because the normal remains at the origin and no probe rods are visible at assertion time. The filtered file also fails (10/11 passed), while invoking that same test alone in a minimal diagnostic SceneTree passes. This is an unresolved execution-context/timing sensitivity, not proof of a gameplay regression; the test and support-debug implementation are unchanged by T09. Preserve the failed reports and investigate lifecycle/process-frame ordering rather than weakening the assertions. No full-suite pass is claimed.
