# Dog locomotion and outdoor presence, v48 work in progress

The dog now has planted world-space paws and two-bone legs. Travel determines the alternating diagonal steps; stopped swings settle, and reaching paws reposition during turns. Body motion runs at render frequency, separately from the bounded 20 Hz close-detail update. The existing part count is unchanged.

Sniffing eases the head toward the ground, with the neck following it, rather than tipping the nose upward. The tail turns around its base. Reduced Motion retains a static leg pose without stepping/bobbing. These are authored presentation choices, not a claim of measured canine biomechanics.

## Physical space and weather

The original route crossed raised garden beds. A supported paw test alone missed that problem: a ray starting below the raised soil could find lower ground while the dog's body intersected the planter. A first westward revision then crossed the far garden's decorative planters, which have no colliders. The final compact circuit stays on the northern lawn west of the hut, clear of both sets of beds, with room for the head and tail. Tests sample the animal's length at four heights against physical obstacles and visible backdrop planters, as well as checking its feet.

The old rain shortcut interpolated the dog straight across scenery. The local wander state now finishes the supported circuit to a sniff stop near the hut when rain is strong, waits there, and resumes when rain eases. It does not teleport to shelter. This ambient wander/animation state is transient; it does not alter checkpoints, the saved ecology, hunting, or player collision.

Native streaming also hid the dog when ground outside the player's streamed area was absent. `DogGround` indexes authored physical boxes only around the dog circuit. Native rays take precedence; known, unloaded terrain supplies distant visual support. It creates no floor or collision parts. Unknown/out-of-map terrain is still unsupported. The index agrees with server-built geometry along the circuit in the CLI checks.

## Verification

- Dog gait: 29,959 passed, 0 failed. Includes bone lengths, joint continuity, planted paws, stopping, turns, teleport reset, missing terrain, Reduced Motion, and rain stop/resumption. This count includes repeated samples of the same invariants.
- Living world: 3,438 passed, 0 failed. Includes dry/wet ground coverage, body clearance, native-box/proxy agreement, unloaded-ground presentation, lowered sniff posture, existing habitat detail budgets, pause, cleanup and solar checks.
- Strict analysis clean; 206/206 source files compile.

The first native run exposed missing streamed ground and is superseded. The second run verified continuous rendering and zero measured paw slide/gap over 30 seconds, but its old route still crossed beds and is also superseded. Retain those observations as diagnostic history, not release evidence for the final route.

The final compact lawn route is the V4 native run in `dog-native.txt`. No CLI work ran concurrently. In 30 seconds it sampled 1,735 frames, 17.30 ms mean and 49.33 ms worst. The dog was rendered for all 1,735 frames, with zero measured world-space stance-paw displacement and zero foot-to-ankle gap. The gait reset count was one (initial placement). Client render-step profile: 5.68 ms mean, 16.2 ms worst. This is a bounded PC sample, not a phone benchmark, complete performance gate, or published evidence.

The normal spider camera caught the dog passing close by (`dog-spider-view-full.jpg`). After sampling, diagnostic close-ups showed its lowered sniffing nose and articulated legs on the northern lawn, clear of the decorative beds (`dog-sniff-closeup-full.jpg`, `dog-moving-closeup-full.jpg`). `studio-dog-review.luau` disables depth of field only for this optional close-up. Those close-ups are not the normal player camera.

The V3 run also kept the actor rendered, but its longer westward route still crossed decorative beds and is superseded by V4. The Studio-only `SilkPlayback` instance and review/detail attributes must be absent before publication; cleanup is recorded in the native receipt. Native low-detail appearance remains to be checked.

This is one part of the living habitat goal. Ordinary encounters, wider density/art work, remaining insect/weather inspection, the frozen full regression suite, and publication remain pending.
