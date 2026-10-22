# v50 verification ledger

Published v50/place139; see release.json and published-place139.png.
This ledger distinguishes different source revisions. Final source: `856c12e3e71d9b79282954013142fa5577fc3f19`, evidence
`3112f8aa4f3f192f`. Published 2026-10-22T02:15:08.763Z to the existing place.

## Regression lineage

The frozen Windows B run at `9e60bba569c05104ee193df91b529f4905a6ca0f`
finished 57 suites: 54 passed, 3 failed (settings, garden self-test host,
preserve self-test host). The first had an overlong settings description; the
others had stale expected check lists and playable-scene cleanup assumptions.
It predates the spawn-clearance suite. Do not present it as final 58/58 coverage.

The subsequent G GitHub run 39705987337 compiled and type-checked successfully
but failed two suites: state_client still expected the historical three/five
meal goals; selftest_preserve required a kept checkpoint after the final forced
death check. H uses the user's seven-meal rule and keeps an actual rest during
test cleanup. No game assertions were disabled.

H state_client: 142 passed, 0 failed. H source compiles 211/211, and strict
analysis has no type errors (only the client's watched-files warning).
Full H CI: https://github.com/socranates/jumping-spider-sim/actions/runs/39708111460
Completed success at 2026-10-22T02:03:34Z: all58 suites passed, including
embedded garden41/0/0 and preserve274/0/0. Raw suite stdout and run metadata
are retained as ci-all-suites.txt and ci-final.json.

Focused gameplay checks: feeding_survival 88/0, spawn_clearance 20/0,
flies 283/0, settings 1163/0. Older targeted client27/life20922/prey1668/
checkpoint545/minimalHUD37 also passed. The final full CI supersedes these
individual invocations for whole-source regression coverage.

## Native engine coverage

- A full-detail complete native self-test: 273 passed, 0 failed, 0 skipped.
  This predates the held shadow, fallback spawn, old-save and cat-carry repairs;
  its exact manifest is retained. It is not claimed as final-source coverage.
- G complete low-detail native self-test: 274 passed, 0 failed, 0 skipped,
  completed 2026-10-22T01:39:59.716Z. All gameplay matches H; H changes only the
  test selection/cleanup and state_client assertions.
- H selected low-detail rerun: 5 passed, 0 failed, 0 skipped, explicitly labelled
  selected scope: named robin anatomy, named frog anatomy, both repaired fallback
  spawns, visible meal/context controls, starvation ending and final kept rest.
  Completed 2026-10-22T01:53:58.123Z. This is not another complete 274-check run.
- H low meal fixture: exact jaw-frame distance0; held scale0.7 at nutrition0.16;
  real keyboard/left-stick/touch strings; three-part noninteractive husk with
  native sound asset loaded; cleanup, dusk cue, E rest and cue clearing passed.
  It creates a controlled catch, not an unassisted player hunt.
- H low tight-space checks: floorA, shelf, both cans, Crack, under-bench and
  milkweed perch all stayed attached with camera outside collidable geometry.
  Can walking reaches a rim/inner surface; it is not proof of walking out.
  The initial line fixture started beyond support, so its air/none result is
  not evidence of a silk catch. The corrected full fixture starts on the board,
  waits for motor:onLine(), and reports air/locked with zero camera overlaps.
- H selected full-detail rerun:5/0/0, completed 2026-10-22T02:03:29.408Z.
  Full meal, device strings, native audio load, dusk/rest and husk lifecycle
  also pass. Full floorA/shelf/cans/Crack/bench/leaf camera samples are clear.

## Survey scope and limitations

B's full-detail survey visited all233 declared regions using stand, walk and
hop inputs. No region failed readiness; decorative parts stayed within1500.
Six camera-interior observations were the stand/walk/hop phases at two declared
fallback spawns buried in shelf books and a boot sole. Their fallback positions
are repaired; geometry and saved player positions remain unchanged. New tests
reproduce both old overlaps and verify the real motor/camera at the new spawns.
The final H low-detail survey completed 2026-10-22T02:01:25.958Z:233 regions,
zero unready and zero camera-interior observations, within the500-part budget.
Raw record: native-H-low-visual-survey.txt. It includes the updated spawns.

The survey is a bounded sample at each region's spawn, not an exhaustive proof
that every possible point/animation is clear. Its historical `dry` output field
means visited regions; it must not be interpreted as certifying every pond
region as dry. Screenshot/art observations and remaining limitations belong in
the final review. Native counters are not phone hardware performance.

## Performance evidence policy

Baseline corrected routes use sill, garden_b2, meadow_a3, deck_n2 and hut_doorway,
both tiers. The original pond_a2 sample was an underwater camera; retain it as
an invalid route sample rather than describing a repaired camera defect.
Native samples taken during the frozen CLI run are excluded from before/after
claims. Full final after samples are retained in native-H-full-visual-profile.txt;
low after samples are in native-H-low-profile.txt. PERFORMANCE.md and
performance.json contain all20 before/after scene samples. Full after means
range17.43-22.38ms; low16.67-24.20ms. The low sill sample and full doorway
regressed, so there is no blanket claim of faster FPS. Surface-route warmup
remained active in the low sill sample. The corrected low silk catch also
passed (air/locked, camera overlaps0).

The full paired cat comparison measured every-render / cached / every-render
at17.62 /19.96 /20.85ms mean. That does not establish an FPS gain. Allocation in
the sound lap (which includes CatBody.draw) fell62 /36 /63KB per frame; whole
render allocation was161 /138 /166KB per frame. Keep the cache for the measured
allocation reduction; tests pin its10Hz pose cadence and smooth every-frame
body translation. No rendering rate is taken from a concurrent CLI run.

MicroProfiler was opened in the actual native low-detail play session, including
its detailed GPU/worker timeline during streaming traversal. Screenshots retain
the live frame variation; a single screenshot does not establish a bottleneck
or a causal speedup. The overlay is closed before timed route measurements.
Access follows the [Roblox MicroProfiler documentation](https://create.roblox.com/docs/performance-optimization/microprofiler/use-microprofiler).

No physical phone is connected. Any Studio phone view is layout/emulation only.

## Device and release closure

Studio iPhone17Pro landscape emulation: viewport749x381, TouchEnabled=true.
Tap Eat prompt at260,285 size289x26 fits; reserve and earned-ability hiding fit.
Older Focus/Creep/Recentre/Cancel labels wrap awkwardly; screenshot retained.
This is layout coverage, not a physical phone performance or controller test.

Native cloud source comparison211/211, correct existing place/universe, no
SilkPlayback/debug overrides, StreamingEnabled and gravity35 passed. Rojo was
disconnected before Publish. Lighting Future and streaming radii96/160 are
configuration values; this Studio command context did not expose their property
reads, so they are not claimed as separate native property assertions. No
lighting source/configuration was changed. Dashboard Show published only
confirms139. Its Last Updated timestamp is the saved version record, while the
native publish log records the actual publication operation at02:15:08Z.
