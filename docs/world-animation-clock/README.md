# Roaming-animal animation clock

The wasp's walking legs, frog breathing and darner patrol used the original sill prey director's clock. That population deliberately waits while the player is elsewhere. This froze presentation even though the animals' simulation or the player's world continued. The cat had already been corrected separately.

SpiderClient now supplies the advancing world prey clock to these three presentation paths. Creature behavior, schedules, senses, attacks, food and save formats are unchanged; the sill population still waits as designed. No animation rate is reduced.

The real-client shim regression moves to the back room, holds the animal controllers in known drawable states, confirms the sill population clock is stopped, and observes the drawn wasp foot position, frog throat size and darner position over twenty frames. The preceding runtime fails exactly those three assertions (78 passed / 3 failed). The fixed runtime passes all 81 minimal-HUD/client checks. The fixture bypasses autonomous behavior only to isolate animation; this is not a native full-game wildlife walkthrough.

An exploratory edit accidentally read existing UTF-8 test strings using the Windows default encoding and produced unrelated counter-string failures. The test was restored from committed UTF-8 bytes before adding the ASCII regression; the retained baseline is the corrected fixture's three animation failures. No counter assertions were relaxed.

The focused receipt binds 20,611 passing assertions: minimal HUD/client 81, wasp 16,884, bodies 3,610 and world client 36. Strict analysis and all 222 module compilations pass. Full Windows/Linux gates, native cross-room review and release status must be reported separately. Nothing in this folder is proof of publication.

## Current full gates and prepared native fixture

Production source is `441eacaec05d0e1164473f19764f7d56f12b8482`. Windows handle 13178 is running its immutable snapshot in `full-windows/`; Linux run 39912299139 is also running. Neither is a terminal result yet. `fetch-ci.py` collects the existing job without dispatching a duplicate, and `verify-gates.py` refuses incomplete/mismatched results. The expected total is 76 suites / 468,487 checks; this remains an expectation until complete output is verified.

The five local Python runner failure/cleanup regressions pass (`runner.json` and `runner.txt`). Their intentional missing-file messages exercise error handling and are not missing project inputs in the full run.

The prepared local package is `C:\Users\natha\claude-xfer\Windowsill-world-animation-441eaca\Windowsill-world-animation-review.rbxlx`. Its manifest and edit-mode guard bind all 223 scripts, with the production persistence script disabled. Never publish this diagnostic. No native result has been recorded for it yet. Execute the guard in Studio edit mode before Play; after the probe completes, `collect-native.py --log PATH` checks the guard, 17 assertions, matching run identity, viewport and absence of CreatorErrors.

The probe exercises the real player's HUD and render callback: initial/partial/second moult counters, Large Text, dusk wording and fit, then moving wasp/cat paws, frog throat and darner position while the sill prey clock is stopped. Animal controllers are deliberately held in known poses only to isolate presentation. This is neither a naturally played hunt/life cycle nor physical-controller, actual-phone, FPS or real-service save evidence.
