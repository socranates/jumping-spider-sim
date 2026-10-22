# Shadow bindings after stream-out

Read-only reproduction on gameplay source `fab75695ba918eeebe793e6768a08cabe99a70f3`. **No production fix yet.** Production and default-test inputs remain unchanged while the full Windows gate runs.

`WorldShadows.bind` records every arrived part in a holder's `bound` table and `count`, including invisible/non-shadow-casting parts. Only visible eligible parts enter `self.entries`. The slow parent check scans that latter list, so it never releases the hidden bindings. Once the holder's count reaches its expected number, `bind` stops checking the folder, even after it and those parts stream out.

The small fixture uses the real outer-sill region's three expected pieces and the real WorldShadows implementation. It binds hidden parts, destroys the folder, then creates new instances under the same region id and advances beyond the binding interval. It reports:

```text
SHADOW_STREAM_RETAIN old_parts=3 retained=3 fresh_shadow_off=0 expected_off=3
```

The assertion fails with native CLI exit 1 because the manager retains all three old instance keys. The replacement visible parts also remain outside distance-based shadow management. Changing visibility in the fixture exposes that functional consequence; releasing obsolete bindings is required even when the replacements have the same hidden flags. This is scripted stream-out/rearrival, not a native streaming, memory or FPS measurement.

This state can retain an initial set of obsolete bindings per region; it does not by itself prove unbounded growth on every renderer cycle. These are world collision-box bindings, not the drawn look folders that the long trace repeatedly creates and destroys. Do not attribute the measured BaseParts/Signals slopes to this bug without a matched native check.

The fix should check/release **all** bound identities with a bounded periodic budget, retain the existing visible shadow rule and preserve hidden parts' properties. Re-arrivals must be rebound after both child and whole-folder removal. Regressions should cover hidden, permanently non-casting and visible parts, mixed batches, repeated replacements, bounded retained membership, and normal distance behavior. Avoid scanning every region's descendants each frame or changing collision, lighting rules or habitat geometry.

`run.py` constructs a temporary bundle with current source and current shim, without editing the project's running full-suite inputs. `baseline-process.json` records the actual CLI failure and hashes every bundled source module; the helper itself exits normally after recording that expected observation. The new regression must fail the default test runner if its expectations fail after integration.
