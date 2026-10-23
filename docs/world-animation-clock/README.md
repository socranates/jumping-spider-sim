# Roaming-animal animation clock

The wasp's walking legs, frog breathing and darner patrol used the original sill prey director's clock. That population deliberately waits while the player is elsewhere. This froze presentation even though the animals' simulation or the player's world continued. The cat had already been corrected separately.

SpiderClient now supplies the advancing world prey clock to these three presentation paths. Creature behavior, schedules, senses, attacks, food and save formats are unchanged; the sill population still waits as designed. No animation rate is reduced.

The real-client shim regression moves to the back room, holds the animal controllers in known drawable states, confirms the sill population clock is stopped, and observes the drawn wasp foot position, frog throat size and darner position over twenty frames. The preceding runtime fails exactly those three assertions (78 passed / 3 failed). The fixed runtime passes all 81 minimal-HUD/client checks. The fixture bypasses autonomous behavior only to isolate animation; this is not a native full-game wildlife walkthrough.

An exploratory edit accidentally read existing UTF-8 test strings using the Windows default encoding and produced unrelated counter-string failures. The test was restored from committed UTF-8 bytes before adding the ASCII regression; the retained baseline is the corrected fixture's three animation failures. No counter assertions were relaxed.

The focused receipt binds 20,611 passing assertions: minimal HUD/client 81, wasp 16,884, bodies 3,610 and world client 36. Strict analysis and all 222 module compilations pass. Full Windows/Linux gates, native cross-room review and release status must be reported separately. Nothing in this folder is proof of publication.
