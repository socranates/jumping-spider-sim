# Rare Sightings build 2 — research leads and implementation guardrails

Prepared while v51 verification ran, 2026-10-21 Central. **Neither beetle is implemented in v51.** These notes distinguish facts read from sources from game design and remaining source checks.

## Eastern Hercules beetle — Dynastes tityus

The [Missouri Department of Conservation account](https://mdc.mo.gov/discover-nature/field-guide/eastern-hercules-beetle), opened, describes males approaching 2.5 inches including their two forward horns, hornless females, variable pale/spotty wing cases, rotting-wood larvae, adult sap/fruit feeding, and occurrence around lights at night. Do not use tropical **Dynastes hercules** measurements or a moth's nonfeeding adulthood for this animal.

The [University of Kentucky account](https://www.uky.edu/Ag/CritterFiles/casefile/insects/beetles/hercules/hercules.htm) opened initially; later section requests timed out. Its accessible account supports the two large male horns, smaller secondary projections and attraction to ultraviolet light in warm months. A normal porch-light visit remains authored timing, not a measured probability for this exact lamp.

**Range gate:** a [University of Arkansas museum search result](https://arthropod.uark.edu/eastern-hercules-beetle/) places its northern interior range in southern Illinois/Indiana; direct open returned HTTP 502. Treat that as a lead, not an opened source for a shipped notebook. Resolve the precise station setting versus its solar latitude of 41.88 degrees before claiming the beetle is common locally. A documented occasional/translocated visitor is preferable to silently broadening a species' range. Also verify larval duration before copying the proposal's one-to-two-year statement.

Design: a grounded night visitor on an existing compact hut patch, with one horn pair recognizable from a spider's viewpoint. Keep it nonfood. Standing on its back is an explicit gameplay concession. Do not imply that being harmless to humans establishes safety for every spider. If it moves with a rider, implement moving support and attached-silk transport first; otherwise let it settle and wait until unloaded before departing, as the luna does.

## Rainbow scarab — Phanaeus vindex

[UF/IFAS IN1003](https://ask.ifas.ufl.edu/publication/IN1003), opened, supports eastern-US presence, roughly 1–2.2 cm adult length, metallic green wing cases with bronze/red pronotum, and sex/size variation in the male horn. It identifies a tunneling dung beetle with underground brood/food balls; adults also consume dung. Its discussion includes dogs among dung sources, but not a guaranteed response the next morning.

The opened [Missouri Department of Conservation account](https://mdc.mo.gov/discover-nature/field-guide/rainbow-scarab) describes the backward-pointing male horn, orange clubbed antennae, strong digging forelegs, and burial beneath the dung pile rather than a long scenic ball-rolling journey. This gives the encounter a distinct animation and silhouette.

Design: record one real dog visit/deposit event keyed to the saved day and patch, then allow an authored following-day scarab appointment. The current dog loop alone is not a saved deposit event. Show small local soilcasts and alternating foreleg excavation; do not cut a new hole in the traversal collision floor. Keep all dressing noninteractive. Armor/nonfood and tolerance of the player are authored rules, not sourced claims of universal invulnerability. Never draw waste or creature parts at map origin when support lookup fails.

## Coding order and acceptance

1. Extend the persisted per-life appointment record and ledger with a maximum-two total budget, species identity and appointment phase. Decide and test whether a missed appointment consumes a slot. Preserve luna saves; an old optional field cannot be reinterpreted as a new event.
2. Add an explicit dog-patch event with deterministic replay and no repeated deposits from a per-frame loop. Register the two beetles only after their range/season checks are resolved.
3. Build separate bounded rigs with six legs, antennae and correct horn placement. Ground casts select real support in existing dense areas; missing support postpones/declines an appointment rather than floating or spawning underground.
4. Test observation through walls, menus, death, old rests, a rest during the event, generation changes and late server progress. No page, notification, target lock or meal credit before the relevant real event.
5. Native full/low review: arrival, a complete dig/visit, motor/camera clearance, anchors, cleanup, actual part counts and foreground frame samples. Keep the liked lighting, quiet HUD, seven/ten-meal progression and controls. Ship as the next small build, not alongside all the remaining predators.

Source photos were inspected through their pages only. MDC marks some images as restricted; none were copied into the game or transfer package.
