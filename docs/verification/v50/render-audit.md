# Rendering audit before final measurements

- LookPlan retains 1500 full / 500 low decorative parts; LivingWorld separately
  retains 420 / 150 total local parts and rebuilds bounded 12-stud cells.
- StreamingEnabled=true, min radius96, target160. Native region readiness and
  later traversal must confirm support; configuration alone is not proof.
- Shared Shapes decor is anchored, noncolliding, nonqueryable, untouchable and
  shadowless by default. Dog shadows are limited to three big masses on full;
  low keeps none. WorldShadows separately maintains visible walkable shadows.
- Imported scenery uses Part+SpecialMesh rather than MeshPart, so MeshPart-only
  RenderFidelity/CollisionFidelity properties do not apply. The separate World
  boxes remain authoritative support; do not add collision to the meshes.
- LivingWorld updates small lives/weather/detail at20Hz. Grass placement uses
  retained arrays and BulkMoveTo about rooted pivots. Nearby leaf sway refreshes
  its list every3s, radius60, cap28full/8low. Reduced Motion removes bending.
- Rain is bounded32full/10low strands, not emitters. Ground/roof discovery is
  cached, with a moving grid and staggered cursor. Weather lighting refreshes
  every.5s. No full-scene raycast for every strand every rendered frame.
- Preserve the liked Future lighting, weather colour and sun direction. No
  ShadowMap switch or global shadow removal in this candidate.
- CatPose.parts rebuilt detailed specs every frame even at long distances. The
  candidate draws that geometry at10Hz beyond180 studs, never throttling senses,
  travel, attacks or audio. Near geometry refreshes immediately. Unit checks
  pin cadence and sound; foreground before/after profiles decide retention.
- No physical phone is connected for this task. Any Studio device-emulator
  result will be labelled as layout/viewport coverage, not phone performance.

Baseline timing files retain the first underwater pond fixture and the corrected
bank route separately. Final measurements and clipping outcomes are still pending.
