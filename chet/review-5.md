# Chet review 5 - v50 feeding, survival and preserve pass

**Published v50 as place139**, 2026-10-22T02:15:08.763Z. Source
`856c12e3e71d9b79282954013142fa5577fc3f19`, branch
`codex/v50-feeding-survival`, evidence `3112f8aa4f3f192f`.
Builds on v49/place138; the adopted prompt's v48 baseline and v49 release name
were stale. Historic v47 report: `docs/verification/v47/review-5-original.md`.

## Player-facing changes

After every catch in all modes, the actual Feed control appears: E, Xbox
left-stick click, PlayStation L3, or touch Grip/Eat. Taps subdue and eat.
Each valid eating tap renews a bounded0.38-second bite window, without banking
nutrition or exceeding the old eating rate. Movement or loss of support
interrupts eating. Optional Automatic Grip also supports automatic eating.
The prey follows animated jaws, the head/chelicerae/palps pulse, the body
empties, and a three-part noninteractive husk falls and fades. Reduced Motion
reduces pulses to20%. Soft built-in bite/end audio respects mute/volume/pause.
Held flies no longer retain a perched shadow at the mouth.

At dusk a brief cue names the local home (the silk-lined Crack on the sill).
At restable shelter it names the real Feed/rest button. Rest clears it; the
next night repeats it. Show Control Hints covers both new cues. No map marker
or future unlock hint. The wordless150x6 reserve,2px dot, seven/ten full-fly
moults, partial meals, earned Run/lock, existing bindings, jumps and lighting
remain. This is the explicit narrowing of the prior hunger-only HUD rule.

## Findings and repairs

The previous minimal view suppressed ordinary control hints although Feed
still controlled catching/eating. A dedicated contextPrompt now survives
minimalView and uses ControlText's actual device names.

Published Normal was not immortal: it died after48 empty-reserve game hours,
with weakness after24. Accelerated empty/default/full examples died around
48.4/59.2/68.4h; Easy/Free never starve by design. Nathan's exact prior mode is
unknown. Live Normal now weakens after6 empty-reserve hours, dies after12,
and an unfed full reserve is bounded by three game days even using sleeping
drain (71.524h theoretical; integration pinned within72.5h). Rest does not
refill food or erase the streak; save roundtrips preserve it; real death reaches
the end screen and lineage. Kept-rest rewind remains intentional. Frozen pure
references retain24/48 defaults. Pre-v50 saved meals can omit bite fields
because ObjectRecord.commit clears constructor defaults; applying live rules
now supplies missing optional fields. Actual graph roundtrip tested; no schema
bump, ledger wipe or changed credit.

Two fallback spawns were buried in props: shelf book and floorA boot sole.
Shelf now starts on the upper book, floorA beside the boots. Prop geometry,
existing saved positions and layout revision are unchanged. New tests reproduce
the old overlaps and verify motor/camera at the repaired points. Native low
rechecks pass. Full survey sampled233 regions with stand/walk/hop and found
six camera observations, the three phases at these two points. Final low
survey visited233/233, zero unready, zero camera-interior observations, all
within500 decorative parts. Final full targeted checks also pass: both repaired
spawns, both can interiors, Crack, under-bench, leaf perch and actual silk catch.
The same supported-edge silk check passes at low. Sampling is not exhaustive
proof of every possible crossing or pose. Full/low screenshots are retained.

## Performance and limitations

`docs/verification/v50/render-audit.md` records current budgets, shadow culling,
BulkMoveTo grass, bounded leaf sway and rain, and cached roofs. Part+SpecialMesh
scenery uses separate support; MeshPart-only fidelity properties do not apply.
Cat pose specs refresh10Hz beyond180studs, with actual body motion
every render and unchanged AI/audio. Retained for measured allocation savings:
paired every-render/cached/every-render sound-lap allocation62/36/63KB per frame
(the lap includes CatBody.draw); total161/138/166KB. Mean frames17.62/19.96/20.85ms
are inconclusive for FPS. PERFORMANCE.md records all ten scene comparisons,
including regressions: full after17.43-22.38ms, low16.67-24.20ms. These are
5-second desktop samples, not steady-state guarantees. The low sill still had
surface-route warmup. Native MicroProfiler overview and GPU/worker timeline
screenshots are retained, with overlay closed before final timing samples.

A close milkweed screenshot still exposes the broad rectangular support
shape beside the detailed blade. Drawing records are centered over the old
boxes and fit their long axes; no confirmed origin-offset defect was found in
that source audit. The oval mesh cannot exactly cover a rectangular support
footprint at every angle. This remains an art/support-shape refinement, not a
change to saved geometry in this release (final-full-leaf-review.jpg).
Procedural legs can intersect soft foliage, cans are faceted, and low detail
omits decorative imported leaves while retaining support. Husk is simplified.
Ants/grubs/fleas/dog are not new food types. No physical phone/controller is
connected: simulated device labels and emulator layout are not hardware proof.
Studio iPhone17Pro landscape layout749x381 was checked with TouchEnabled=true.
Tap Eat fits at260,285 size289x26; reserve and hidden locked abilities fit.
Older Focus/Creep/Recentre/Cancel labels wrap; phone-layout-iphone17pro.jpg
records the remaining UI limit. New prompts do not overlap the touch buttons.
Lighting is preserved. Remaining art observations/screenshots will be listed.

## Evidence and release

`docs/verification/v50/RESULTS.md` preserves exact source scopes and earlier
failures. G complete low native274/0/0; H selected5/0/0 at each tier after test-only changes;
A historical full273/0/0. H state_client142/0, compile211/211, strict clean.
Full58-suite CI passed, including embedded41/0/0 and274/0/0: https://github.com/socranates/jumping-spider-sim/actions/runs/39708111460
Published existing place120119801868085/universe10771103250 after211/211
native source comparison, removing temporary overrides and disconnecting Rojo.
StreamingEnabled/gravity35 and IDs passed the clean-place guard. Lighting and
streaming-radius configuration were preserved; their direct command-bar reads
were unavailable in this Studio context. Dashboard Show published only confirms139.
Receipt: docs/verification/v50/release.json; proof: published-place139.png.
The source package receipt is docs/verification/v50/portable-package.json.
OneDrive/Project sources stayed read-only; Godot stayed frozen. No mail was sent.
The latest GitHub email alert was the earlier failed G run; final H CI is green.
