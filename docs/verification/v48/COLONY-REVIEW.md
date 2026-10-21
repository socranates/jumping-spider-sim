# Ambient colony and grub review, v48 work in progress

The ordinary-camera review showed workers near the nest, but their old radial orbits never reached its entrance. The three soil ellipsoids also looked like separate stacked discs. Workers now follow clock-derived, curved out-and-back trails: emerge from the nest, walk to a small food fragment, pause with moving antennae, return carrying a crumb, then disappear into the entrance. Eight workers remain at full detail and three at low detail. These are ambient fragments, not food deducted from the saved prey ecology.

The mound is now a low, overlapping soil heap, with grains on its actual drawn surface and an entrance at its crown. Its three support identities remain stable; their steps are now 0.2 cm, with smaller inner footprints. This is unpublished v48 scenery, not relocation of a previously released landmark. The physical support remains three boxes; sampling bounds its difference from the visible mound to less than 0.26 cm. It is an approximation, not a claim of exact mesh collision.

Workers use the visible mound profile rather than snapping between hard-coded tier heights. They remain visible from neighbouring regions within 40 cm, shelter in heavy rain, quieten after dark, and stop travelling under Reduced Motion. One additional pooled part per worker draws its carried fragment; overall renderer limits remain 420/150.

## Verification

- Living-world checks: **3,842 passed / 0 failed**. Coverage includes complete forage cycles, direction of travel, carried loads, deterministic reconstruction, bounded trails, both native renderer tiers in the shim, Reduced Motion, weather shelter, local visibility, connected soil caps without air gaps, and physical/visible height tolerance.
- Strict analysis: no diagnostics. **207/207** source files compile.
- Native full-detail V2 inspection shows the low mound and moving workers in the ordinary camera. Five-second samples record workers inside, outbound, foraging and returning, with two to three visible mouth fragments in the recorded samples. The three-second approach remains attached at `(-182,-84.29,-197.54)`. This image predates the final material refinement.
- Native low-detail V3 crossing stays attached after 5.4 seconds, at `(-182,-83.89,-203.54)`, on the mound's middle support. Traffic samples retain one to two visible mouth fragments. The close inspection exposed stretched Ground texture; the final surface uses fine-grained Sand material in the same soil colour. V4 repeats this low-detail walk on final source, attached at `(-182,-83.89,-203.50)`. Its endpoint is a close camera view with the spider hidden; it is useful for soil inspection, not proof of comfortable camera framing over the whole mound. The V3 image shows the spider on the same support geometry. No frame-time claim is made while the frozen CLI suite runs concurrently.
- Native baseline grub review: wet soil produces an occasional visible cream grub with a brown head in the normal camera, captured in `grub-normal-camera.jpg`. The event log also records emergence and withdrawal; grub timing/body code is unchanged by this colony pass. This proves a local encounter, not coverage of every outdoor region.

`studio-colony-review.luau` is a Studio-only driver. The full tier approaches for three seconds; low walks for 5.4 seconds onto the mound. Remove the temporary `SilkPlayback` instance and forced detail setting before release.

Cleanup was verified in stopped Studio at 2026-10-21T18:52:59Z (`[CHET_COLONY_REVIEW_CLEAN]`); neither the temporary instance nor the forced detail attribute remains.

## Release status

No v48 publication. The frozen 55-suite regression against commit `4a828e0` is still running and has already failed `client_mating.luau` and `notebook.luau`; the latter explicitly contains old moult-count expectations. Those results predate this colony change. They must be investigated and corrected without reversing the user's progression/HUD requirements, followed by appropriate reruns. Native performance, broader ordinary travel and weather transitions remain open.
