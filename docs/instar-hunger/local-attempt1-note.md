# Local development sweep

`full-attempt1.txt` / `.json` are a development run, not an exact-head full pass. Source admission/credit validation was finalized while that serial development run was already underway. It records one wrong Normal-counter assertion in `state_client.luau`; that test used Easy's goal. Commit 78413065 corrects the assertion; the focused final result is 161/0.

After CI 40109708172 independently completed the old exact-head 82-suite sweep with that same recorded failure, the redundant local old sweep was stopped during Preserve self-test to release the laptop's CPU. Its unsigned Windows termination status is retained. The default full-suite qualification belongs to the separate exact-head CI 40110260962, not this partial log. No tests were removed or skipped to obtain the final qualification.
