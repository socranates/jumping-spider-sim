# Dragline, falling leaf, grass and hunger — Chet, 2026-10-18

Nathan reports v22 runs great on PlayStation and the wasp is scary. This is positive play feedback, not a measured console frame-time result. He requested a more believable hang, the Godot falling platform, small grass tufts, less frequent feeding, and a Hard mode design.

## Changes

- SpiderRig tilts its drawn body around the rear silk outlet while the real motor is on a taut line. The head hangs below the spinnerets and the unplanted legs adopt a suspended pose with small alternating adjustments. Reduced Motion removes those adjustments. The physical root, camera, tether solver, reeling and jump landing rules are unchanged. The drawn line now ends at the actual animated/condition-scaled spinneret point, including during jump preparation and courtship.
- Breakaway restores the authored `leaf_tip` at the far east end. Like frozen `scripts/habitat/windowsill.gd`, a committed jump to that target makes it give way; merely aiming does not. Its physical surface stops accepting casts; its rounded leaf artwork falls for 0.7 simulated seconds, then disappears. It returns after eight simulated seconds only when the spider is clear. Reduced Motion hides the falling motion. The same identity remains available for checkpoints; optional validated `breakaway.left` retains the cooldown, and older checkpoints restore an intact tip. An old jump outcome cannot retrigger it after recovery. The actual east-leaf-to-tip miss is tested through Motor/SilkController in both the CLI and Studio.
- Fourteen sparse grass-like seedling tufts around planter soil and sill edges: 70 decorative blades full detail, 42 low. They do not collide, receive touch or participate in queries; no wind scripts or new physics. Full decor is 964 parts and low is 207, under existing budgets.
- Normal gameplay uses 110% of the original awake/asleep hunger drain. Easy/Free apply their existing gentle modifier on top. The client reapplies this tuning after old or new rest recovery. Original Godot fixtures still use the original factor by default. The moult goal remains three housefly-equivalent meals, displayed as a simple count. Small prey contributes exactly half (0.175 energy). Live growth credits swallowed food, even with full energy, normalized to the existing 0.9 growth threshold; saved growth remains intact.
- Four solid stalking obstacles beside hunting perches (bark pieces and a low leaf ridge) block sight and can be climbed in both detail tiers. Decorative grass remains nonblocking.
- `HARD_MODE_DESIGN.md` is a design only: separate save slot, 50% more food than new Normal, slight prey/wasp challenge, unchanged fair warning/retreat/silk/accessibility. No Hard menu entry, schema migration or monetization was enabled.

## Science and intent

Rear attachment and attitude response are informed by Chen et al. (2013), *More than a safety line: jump-stabilizing silk of salticids*, https://pmc.ncbi.nlm.nih.gov/articles/PMC3758018/ . That work supports silk's stabilizing role, not this game's exact suspension angles. Roessler et al. (2021), *Hanging by a thread: unusual nocturnal resting behaviour in a jumping spider*, https://pmc.ncbi.nlm.nih.gov/articles/PMC8127284/ , documents suspended positions in **Evarcha arcuata**; do not call its resting behavior a universal Phidippus or Maratus behavior. The active recovery pose here is illustrative display tuning, not a measured species-specific animation. No simulated extra pendulum force is added.

## Next

See `verification/roblox-dragline/RESULTS.md` for accepted builds, counts, publication and limitations. Nathan: jump from the east leaf toward the pale dry tip, watch the line catch, reel back, and try it with Reduced Motion and in eye view. Physical-device acceptance for this update remains his.

Implement Hard only as the separate, safe next chunk in the design document: save migration and isolated real DataStore acceptance before exposing its button. Compact phone HUD, notebook science review and store presentation are still release work. Preserve the free full game/first spider and free peacock testing; future cosmetic target remains about US$0.99. Keep SimClock; Godot/SPEC remain frozen.

## Later requests in the same round

The wasp now uses live multipliers (search 1.6, notice 1.2, inspection 0.8); defaults still replay Godot. The optional brown rival is Shared/Predator/RivalSpider.luau, with plain state in life.rival, semantic checkpoint validation, generic movement-only perception, a low-detail SpiderRig and the new rival death reason. Its one-second windup and committed lunge are game tuning. Jump contact before its lunge captures it; it takes five seconds of still eating, worth two houseflies. No new controls or payment. It pauses attacks during a wasp visit and never attacks in the retreat. Old saves initialize a new dormant rival; saved consumed rivals stay consumed. See ROBLOX-62 for research and intent. Check actual difficulty with Nathan before raising it further.


Rival scope: one floor-territory encounter per life, not a general NPC surface-walker. It does not climb walls, spin silk, hunt the fly population, or use species-specific cognition. Its patrol/lunge stays within the eastern sill and is blocked by solid cover. The player's existing jump provides the capture action; eating pauses while moving. Future animation can tuck the captured rival's legs and improve patrol avoidance without changing the food/save ledger. Do not advertise it as a complete second spider simulation.

Update (ROBLOX-67/68, docs/HANDOFF-roblox-daily.md): the rival is no longer optional. A new rival arrives each morning after one is eaten, and the wasp visits every day from day 2. The scope limits above (one encounter on the eastern sill, no climbing or silk) still hold; "one encounter per life" now reads "one rival at a time".
