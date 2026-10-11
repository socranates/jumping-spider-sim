# T10b — principal-eye scanning and spectral honesty

Chet, 2026-10-10 (America/Chicago). Built on Claude's `2d6ea80`. Nathan requested more scientific accuracy in first person, specifically how the front eyes sweep and colour the world.

## Implemented

- Replaced the stationary broad oval with two overlapping narrow, softened boomerang-shaped regions of detail. A conjugate horizontal sweep repeats over 1.6 seconds; slower torsion spans ±25 degrees over 8 seconds. These are illustrative rhythms within reported research ranges, not measured P. audax behavior.
- Kept the camera stable during those automatic scans. Player-controlled gaze, movement, inspection, reach fade, jump aim and gameplay RNG are unchanged.
- Removed the blue-channel-as-UV colour contrast. RGB assets have no measured UV reflectance. A green-weighted brightness approximation remains, labelled persistently as "UV not simulated". Red is relatively dim, not declared invisible.
- Scan time stops with pause and freezes at its current phase under Reduced motion. Orbit view does not run or display it.
- Added research notes in `docs/VISION_RESEARCH.md`, distinguishing related-species evidence and illustration choices from biology. Do not claim the green display is literal spider colour experience.

## Verification

- Windows Godot 4.7.2 headless fixed 60 fps: **548/548**, evidence **829573aaf835** (source 397ee1a2, settings 8b6707d4, tests 941389a2).
- Focused first-person tests: **12/12** at both fixed 60 fps and normal speed. Four new tests cover stable aim/sensing, Reduced motion and orbit behavior, elapsed-time consistency at 30/60/144 sampling rates, and tree pause.
- Native Windows AMD Radeon Compatibility/OpenGL rendering completed with no reported engine/shader errors. Three fixed-scene screenshots show scan phases at 0, 0.4 and 2 seconds, with leg/HUD context. These are visual checks, not sustained frame-rate benchmarks or Nathan's playtest approval.
- Isolated APPDATA and disabled autosave in the capture fixture protected player settings and saves. Frozen full-suite and normal-speed reports and native output are in `docs/verification/t10b/`.

## Continue from main

Press V / controller Y or use the eye-view menu option; look at leaf edges and flies to see detail sweeping. Reduced motion stops that sweep. Nathan should judge comfort and hunting readability. Actual UV material/lighting data, stimulus-dependent scan bouts and tracking, depth from defocus and the full secondary-eye panorama remain future work. No exported packages were rebuilt in this pass.

The local integration checkout contained two untracked generated UIDs that upstream now tracks. They were preserved in the parent workspace's `eye_scan_uid_backup` before fast-forwarding. No user work was reset or discarded.
