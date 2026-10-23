# Roaming-animal animation clock

The wasp's walking legs, frog breathing and darner patrol used the original sill prey director's clock. That population deliberately waits while the player is elsewhere. This froze presentation even though the animals' simulation or the player's world continued. The cat had already been corrected separately.

SpiderClient now supplies the advancing world prey clock to these three presentation paths. Creature behavior, schedules, senses, attacks, food and save formats are unchanged; the sill population still waits as designed. No animation rate is reduced.

The real-client shim regression moves to the back room, holds the animal controllers in known drawable states, confirms the sill population clock is stopped, and observes the drawn wasp foot position, frog throat size and darner position over twenty frames. The preceding runtime fails exactly those three assertions (78 passed / 3 failed). The fixed runtime passes all 81 minimal-HUD/client checks. The fixture bypasses autonomous behavior only to isolate animation; this is not a native full-game wildlife walkthrough.

An exploratory edit accidentally read existing UTF-8 test strings using the Windows default encoding and produced unrelated counter-string failures. The test was restored from committed UTF-8 bytes before adding the ASCII regression; the retained baseline is the corrected fixture's three animation failures. No counter assertions were relaxed.

The focused receipt binds 20,611 passing assertions: minimal HUD/client 81, wasp 16,884, bodies 3,610 and world client 36. Strict analysis and all 222 module compilations pass. Full Windows/Linux gates, native cross-room review and release status must be reported separately. Nothing in this folder is proof of publication.

## Current full gates and prepared native fixture

Production source is `441eacaec05d0e1164473f19764f7d56f12b8482`. Windows handle 13178 completed with exit 0; Linux run 39912299139 completed successfully. Both terminal logs verify 76 suites / 468,487 passing checks / zero failures. All 222 modules compile, strict analysis is clean, and five runner regressions pass on each platform. `full-verification.json` binds the immutable committed Windows snapshot, complete Linux logs and native fixture evidence. Do not restart these completed jobs.

The five local Python runner failure/cleanup regressions pass (`runner.json` and `runner.txt`). Their intentional missing-file messages exercise error handling and are not missing project inputs in the full run.

The local package is `C:\Users\natha\claude-xfer\Windowsill-world-animation-441eaca\Windowsill-world-animation-review.rbxlx`. Its edit-mode guard matched all 223 script fingerprints and confirmed production persistence disabled before Play. Native run 1792738483442 passed all 17 assertions at 1105x428, without CreatorErrors. `native-receipt.json` and `native-events.txt` preserve the result. The session was stopped and closed, temporary editor changes discarded, and the original package hash rechecked (`native-close.json`). Never publish this diagnostic.

The probe exercises the real player's HUD and render callback: initial/partial/second moult counters, Large Text, dusk wording and fit, then moving wasp/cat paws, frog throat and darner position while the sill prey clock is stopped. Animal controllers are deliberately held in known poses only to isolate presentation. This is neither a naturally played hunt/life cycle nor physical-controller, actual-phone, FPS or real-service save evidence.

## Production candidate

`build-production.py` built `C:\Users\natha\claude-xfer\Windowsill-production-441eaca\TheWindowsill-production-candidate.rbxlx` from the verified default project. `production-candidate.json` records its SHA-256 and confirms all 222 production script sources match the committed snapshot. There is no injected SilkPlayback diagnostic and normal production persistence is enabled. The builder does not publish or open the candidate. Full release audit, service/rejoin verification, main integration and release synchronization remain outstanding; do not treat this package as a disposable save test or a published release.
