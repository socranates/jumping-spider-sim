# Movement realism part 2 — Chet, 2026-10-11

Built from main `17db650` (Claude T11c). Nathan's unchanged Windows baseline passed **568/568**, evidence **77c9ef3b3bc6**, headless at fixed 60 fps, before implementation. Laptop `update.bat` succeeded first. One writer throughout.

## What changed

- The live rig uses `surface_legs.gd`, extending the original preview rig. Each stance foot is stored in its touched collider's local coordinates; the hip can move above it without sliding the foot. Short raised swings replace contacts as travel or turning stretches the stance. Surface rays search inward at narrow edges rather than pretending a leaf extends into empty space. The queries only read WORLD geometry; they never authorize movement or supply forces.
- Actual world endpoints are interpolated, then the rods are drawn against the interpolated body. Rods use global transforms with their own physics interpolation disabled. This avoids interpolating a planted tip in a rotating body frame at quarter speed. Moving support transforms are respected; missing footholds tuck, and teleports/flight discard old contacts.
- Snap turns, lurches, idle flicks and catch recoil remain. All body animation now explicitly advances by `SimClock.DT`. No timing reads the engine's variable physics rate.
- Jump presentation: abdomen/spinnerets dip, rear pairs III/IV extend, then the legs fold into flight. The launch signal starts the same sequence for instant scripted jumps/tap hops. Landing compresses the body over 0.24 game seconds while feet retain contacts.
- A tap has no advance warning, and adding input delay would change the approved physics. Therefore third-person **presentation alone** waits at the launch pose for 0.067 game seconds, then catches up over 0.167 s. The solver is already flying its original plan. The active silk's drawn endpoint follows the visible spinnerets during this interval; its anchor, length, constraints and outcomes are unchanged. First person keeps the original camera/motor relation and does not delay the visible model behind the camera. The abdomen is hidden there, as the head/body already were.
- Reduced motion immediately clears contact animation, launch/landing offsets, twitch and recoil, retaining the neutral preview legs. First person uses a stable mask of the two distal front rods; proximal rods cannot pop across the near plane during a snap turn. It does not switch visibility on/off according to distance each frame.

## Biology and deliberate approximations

[Nabawy et al. (2018), *Energy and time optimal trajectories in exploratory jumps of the spider Phidippus regius*](https://doi.org/10.1038/s41598-018-25227-9) observed pairs III and IV extending at launch in P. regius. Their relative force contributions were not measured. The paper discusses hydraulic joint extension but finds estimated muscle capacity sufficient for the jump's power requirement. We illustrate rear-joint extension, not an exclusively hydraulic engine. Other salticids can use different rear pairs.

[Chen et al. (2013), *More than a safety line: jump-stabilizing silk of salticids*](https://pmc.ncbi.nlm.nih.gov/articles/PMC3758018/) documents pre-jump silk attachment and its stabilizing role in Hasarius adansoni. This motivates the abdomen dip; it does not justify silently changing our existing tether solver.

This remains an eight-foot, two-rod-per-leg **visual approximation**, not anatomical seven-segment IK, pressure simulation or measured species-specific gait. Step height, duration, clearance, bend and landing compression are authored for legibility. The lead-in is a presentation compromise, not a measured biological delay. No new jumping power, silk-stabilization physics or landing accuracy claim is made. Nathan should judge the feel, particularly very short hops and rapid view changes.

## Verification

Final results are recorded in `docs/verification/movement2/` and summarized in `claude/where-we-left-off.md`. Eight new tests cover planted world coordinates, turning without translation, attachment-before-push and landing, actual rear-knee straightening, wall/underside surfaces, leaf-edge/sill contacts, quarter-speed tick equivalence, and first-person/Reduced motion behavior. Existing walk-route invariance and silk recoil/physics-path checks remain. Old assertions that stopping must restore exact local foot coordinates were updated because that would intentionally slide world-planted feet.

Native Windows Godot 4.7.2, Jolt, AMD Radeon OpenGL Compatibility captures at 25% speed show leaf stance, abdomen attachment, rear push, landing, first person and Reduced motion. Reproduce with `--path . --script res://docs/verification/movement2/capture.gd`. Stills and scripted checks are not Nathan's playtest approval or a sustained frame-rate benchmark.

## Next owner

Start main, read this handoff, preserve Nathan's twitch and the SimClock rule. ROADMAP step 5 (vision realism part 2) remains Claude's proposed next round, subject to Nathan's choice. The renderer still uses primitive geometry; full anatomical joints, species-specific rig proportions and measured gait timings remain future art/biology work. No platform port or export round was included here.


Final Windows verification (Godot 4.7.2/Jolt): **576/576** at fixed 60 fps, no failures or skips. Targeted leg/silk/eye-view checks: **46/46 at each of fixed 30, 60 and 144 fps**. Evidence **5b1adc6e6a6b** (source d9480321, settings 8b6707d4, tests d29cd4d4). Frozen reports: `windows-full60.txt`, `windows-targeted-30.txt`, `windows-targeted-60.txt`, `windows-targeted-144.txt`. Native renderer log: `native-capture.txt`. These accelerated headless checks are not a sustained real-time performance measurement.
