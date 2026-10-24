# Complete real-engine self-test - 2026-10-23

The current menu-corrected candidate completed the entire foreground Studio
self-test: **274 passed / 0 failed / 0 skipped**, 591 seconds. The raw retained
output and receipt are attempt1-output.txt and attempt1-receipt.json. This is
native engine evidence, separate from the prior CLI stand-in run.

The source was the saved, guarded menu-player candidate, SHA256
8616844ac52cffcbac84ada921bc146c04c0eb75766ddcf32e74dc1809edb042.
Its 273 game sources plus the dormant read-only arrival probe remained exact.
Only the local copy's SelfTest attribute was enabled. Supported local game/place
binding selected private test universe10771634917/place109879630247781, with
the normal engine save adapter and fresh synthetic test keys. No seed/reset of
retired actors, production saves, security changes or upload occurred.

Source guards passed before Play and after Stop. The test fixture was saved as
C:/Users/natha/claude-xfer/Windowsill-integrated-native-attempt1/NativeSelfTest.rbxl.
It is **test-only; never publish it**. The deployment candidate remains the
separate menu-player file with SelfTest false. Studio8124 has exited, flushing
the exact log used by collect.py. No Rojo process was needed or left running.

The self-test checks region arrivals, movement/line, presentation, wildlife,
feeding, checkpoint and death components. It deliberately manipulates state
and holds some threats off except during their own checks. It is not proof of
a full naturally played life in every mode, every camera/mesh angle, physical
controller/touch comfort, or standalone/published behavior. The music reported
IsLoaded true; that is not an audible-balance or complete audio-permission test.

One five-second sill sample recorded 301 frames, mean16.7ms, worst21.5ms,
physics60fps. Render callback mean5.18ms/worst10.2ms. This is a short sample in
the scripted Studio run; it does not prove a general FPS gain, mobile behavior,
the full eight-scene matrix, or leak-free memory. The comparison with far
geometry removed and shadows disabled was mixed, not an optimization win.

Ten CreatorWarning records are retained: eight CornerRadius StyleRule failures
before Play, and two asset203785492 type mismatches (one before Play, one near
startup). Neither literal reference is in this staged source/config. Their
origin remains unresolved; pre-Play occurrence does not identify the source
or justify calling the game warning-free. The collector was corrected to read
CreatorWarning/CreatorError as well as CreatorOutput before final qualification.
Unrelated local log data is excluded.

Reverify with the bundled Python:

```text
python docs/native-integrated/prepare.py --check
python docs/native-integrated/collect.py --log C:/Users/natha/AppData/Local/Roblox/logs/0.744.0.7441077_20261024T033831Z_Studio_D3324_last.log --check
python docs/native-integrated/verify.py --check
```

The private-upload question remains unanswered. This local engine run does not
substitute for the standalone player startup check or final release. The fresh
foundation ledger is ../audit/HEALTH-CURRENT.md; the exact staged lexical map
is ../audit/integrated-source/MAP.md.
