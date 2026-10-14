# Handoff — Roblox safety silk (Chet, 2026-10-14)

Built from main e183efc. Roblox-only; Godot and SPEC stay frozen. The playable and test places are rebuilt and committed. Open roblox_port/TheWindowsill.rbxlx in Studio, then Play; reopen after update.bat.

## Delivered

TetherMath ports the pure unilateral constraint and scalar helpers against Godot-exported fixtures. SilkController handles anchor-local tracking, flight payout, missed-jump catch, damped hang, reel/lower, one bend with snag feedback, edge-first lowering, contact recovery and deliberate release. SpiderClient wires those into fixed 1/60 ticks; JumpMath is unchanged. Appearance/BulkMoveTo rig retained.

F / gamepad X / touch Silk requests lowering; on top of a leaf it walks to the nearest usable edge. Hold to continue lowering. While hanging, W/up reels and S/down lowers (stick/D-pad and touch directions use the same path). Hold Q / B / Let go to release: 0.4 s grace, then a fresh 0.6 s hold. A preheld button cannot accidentally release. Focus loss/disconnect clears inputs. Cancel movement cancels edge approach. Gamepad X is intentional: D-pad down remains directional movement/lowering.

At the shortest line, legs acquire a nearby real attachable face within 0.6 stud, with a body sweep against intervening geometry. This Roblox contact adaptation fixes being stuck just below a padded leaf lip. It is not claimed as complete Godot contact parity.

## Evidence

Windows **115/115 pure Luau**, **18/18 Studio** (includes two completion rows), **3/3 actual-client scripted sequences**, evidence **d1a1cff5c06eafe3**. All 22 Luau files compile. See docs/verification/roblox-silk/RESULTS.md, reports and native screenshot. No device/frame-time acceptance claim. Tests exposed and fixed edge-direction ties and short-line leaf recovery.

## Next Claude chunk: recovery camera and control acceptance

Make recovery easy to see before starting perception. Read frozen camera_rig.gd and test_camera, test_camera_framing, test_camera_ordering and test_catch_camera. Implement horizon-stable collision-aware framing, including the accepted maximum 45-degree catch adjustment and immediate player-look takeover. Keep jump and silk rules unchanged; port pure camera decisions into CLI fixtures and add real Studio camera tests.

Make action prompts device-aware and check wrapping/safe areas. Preserve keyboard, touch hold/release and gamepad controls together. Add deterministic recovery scenarios covering missed jumps, leaf/wall/planter lowering, reeling, snag/obstruction, early/preheld release and focus-loss cancellation. Run a ten-miss recovery sequence before claiming the Godot M03 intent satisfied. Keep the inventory partial until those checks pass.

Chet/Nathan on Windows should then check actual controller and simultaneous touch/camera input, small tablet layouts, and frame intervals during catches (median/p95/worst, warm-up separate, no screenshot stalls). Claude should record unavailable device checks honestly; do not block pure/Studio implementation on hardware access. The current stock camera leaves the hanging spider small; screenshot is useful starting evidence.

After that chunk: perception (observation/association/memory, inspection cone, peripheral cue and Focus), then flies, LIFE/wasp and DataStore saves. Preserve uncertainty/identity guardrails. No new Godot features, no publishing or production save setup.

Finish main, update the laptop when accessible, and update where-we-left-off, decisions, inventory and this evidence chain. Nathan does not merge branches.
