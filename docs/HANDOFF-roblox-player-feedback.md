# Player feedback: food, jump controls, habitat and vision — 2026-10-18

Nathan asked for a food bar, left-stick jump aiming on PlayStation, slightly easier catches, more twitch, a richer/larger habitat, a second prey type, meals toward the next moult, a clear coloured centre with muted peripheral vision, and visible hydraulic-style jump preparation. These are one update on top of settings v20, main e4a2b5a. Publication/accepted evidence is recorded in `verification/roblox-player-feedback/RESULTS.md` when complete.

## Implemented

- Food reserve bar and words, visible with hints off. It is not a separate hit-point system.
- Growth percentage plus approximate housefly meals remaining. READY_FOOD remains 0.9 and a full housefly gives up to 0.35: about three meals from empty. Actual granted food drives progress, including part meals; eating while already full may grant less. Adults have no further moult goal. Existing saved growth remains authoritative.
- Left stick joins right stick for look/aim while holding jump; it no longer walks the body while aiming. Release still launches the displayed reachable plan. Cancel and focus-loss rules stay unchanged.
- Housefly contact tolerance increases from 0.70 to 0.75 including spider radius, about 7%. No changes to flee detection, speed or struggle difficulty; walls still block capture and an ordinary fall is not a strike.
- A smaller tan/red-eyed fruit-fly-inspired prey every third new spawn. Food 0.18, drawn scale 0.60; uses the existing flight/decision model and conservative housefly path clearance. This is not a species-accurate Drosophila model. Existing fly-profile checkpoint references remain stable; a separate fruit profile reference is registered. Old rests gain mixed replacements as their population turns over.
- Two additional Pilea leaves with climbable stems, a low terracotta step and a broad upper wooden ledge. Old support IDs, retreat and bounds remain. The new lower leaf was narrowed after the wasp clearance regression found it blocked floor_west's take-off path. Full-detail decor is 894 parts, low detail 165. Native route checks cover support on both new leaves and the ledge, not exhaustive manual route acceptance.
- Short asymmetric body snaps run on both detail tiers. Root, camera and planted-foot anchors do not twitch. Reduced Motion and courtship display bypass them.
- Visible jump loading: lower/brace while holding jump, brief rear-leg extension after launch. Driven by existing fixed-tick events and simulated animation time; no charge multiplier, delay, pressure meter, inflation or solver change. Feet remain planted during preparation. Reduced Motion suppresses the extra pose.
- Eye view keeps a coloured clear centre in wide and Focus views. Four wider neutral edge gradients mute the surround; whole-screen BlurEffect is disabled. **This is a grey contrast wash, not true per-pixel greyscale, a regional blur shader, or an exact spider-eye simulation.** It adds no render pass or scene copies. Focus zoom, retinal strips, sensed movement cues, EyeGrey and Reduced Motion remain. The central zone is deliberately enlarged for playability, not a measured angular fovea. Historical comments about the earlier whole-screen side-eye blend are superseded by the revision note in Eyes.luau.

## Scientific basis and limits

Principal eyes resolve detail and secondary eyes guide them toward motion: Jakob et al., 2018, *Lateral eyes direct principal eyes as jumping spiders track objects*, https://pubmed.ncbi.nlm.nih.gov/30253146/ . The game combines those streams on a flat screen; it cannot reproduce subjective vision or simultaneous all-round visual fields. Roblox's blur affects the entire scene: https://create.roblox.com/docs/reference/engine/classes/BlurEffect . Nathan chose a lighter muted-surround approximation after that limitation was explained.

Nabawy et al., 2018, *Energy and time optimal trajectories in exploratory jumps of the spider Phidippus regius*, https://www.nature.com/articles/s41598-018-25227-9 , documents use of legs III/IV and cautions that muscular power can meet the jump requirements; hydraulic augmentation is not established as energetically essential. Also see the species differences in *Jump takeoff in a small jumping spider*, https://pubmed.ncbi.nlm.nih.gov/33712882/ . The drawn preparation is explanatory game tuning, not measured pressure or a universal timing waveform.

## Next handoff

1. Start from the accepted main and evidence in RESULTS. Nathan should try left-stick aim, catch tolerance, food/growth wording, eye-view comfort and slow-motion take-off on PlayStation. Physical controller/tablet checks remain his; emulation is not acceptance.
2. Keep the first spider and full game free; peacock still free during tests, future cosmetic-pass target approximately US$0.99. Do not activate sales as part of this feedback work.
3. Release presentation and notebook science review remain next. Audit inherited colour/UV/defocus claims, distinguish evidence by species, and update the notebook's old description of sharp strips: they are overlays, not separately rendered high-resolution images. Keep normal-vs-Free-play and cloud-save expectations clear on the store page.
4. Short landscape phones, especially large text, need a more compact HUD/touch presentation. Do not confuse a keyboard-driven playback running inside a touch emulator with real thumb-layout acceptance.
5. Run an uninterrupted low-end-device frame-time check before public release. Nathan handles identity/security/content-rating/audience/fee screens himself.

Godot and SPEC remain frozen. Keep SimClock, Reduced Motion, one writer, source history and the normal main/laptop handoff rule.

## Final acceptance and latest request

Published v22, final build c2dcf7301abf3792. CLI 48,218 accepted, strict clean, 167 scripts compile. Native 111 engine + 27 live-client passed before the final soft-skin update; see RESULTS for exact provenance. Nathan also requested slower movement after a moult: walking/stalking now 65% while soft; the existing 0.7 jump-reach reduction stays. Both derive from saved growth and return to normal at hardening. Silk walk-to-edge timeout accounts for the slower pace. Add a native soft-skin movement/leave-and-rejoin check next, along with the previously listed device and release tasks.
