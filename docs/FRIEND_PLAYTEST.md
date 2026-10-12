# Friend playtest instructions

THE WINDOWSILL - Friends playtest, 2026-10-12 - notebook / T13b

This is the playable prototype, not the finished whole-life release.
Built from main fa32368; game/test evidence 2c7264139c03; Godot 4.7.2.

WINDOWS: Extract the entire ZIP, then run TheWindowsill.exe. Keep its
TheWindowsill.pck beside it. Godot does not need to be installed.

WEB: This is a hosting bundle. Serve its contents over HTTP/HTTPS; opening
index.html directly as a file is unsupported. index.html belongs at the ZIP
root for an itch.io HTML upload. This build has not been published.
Click the game to focus it and enable browser audio. Browser saves belong
to that browser/site and may disappear when site data is cleared.

CONTROLS
WASD walk; mouse or arrows look; Shift creep; right mouse Focus.
Tap Space to hop; hold Space to aim, release to jump. Q cancels aiming.
V switches first/third person. T toggles slow motion (speed in Esc menu).
After catching a fly, tap Space or E quickly until the red grip bar fills.
E rests in the silk-lined starting retreat and keeps a checkpoint.
On a safety line: W reels up, S lowers; hold Q to let go.
R recenters the camera. H opens field notes. N opens the naturalist notebook
(controller D-pad up); pages open as you discover things. Esc pauses and
opens settings.
Most help assists aiming and holds prey automatically. Reduced motion,
level eye-view horizon, grey eye view, volume and remapping are in Esc.

TRY THIS
Explore the sill and leaves, stalk a fly while it looks away, try a jump,
and return to the silk-lined retreat to rest. Check both camera views.
The pale leaf tip beyond the eastern leaf gives way: the dragline catches
you. Use W to reel back. Checkpoints rewind the whole sill; they are not
an exact resume of an airborne/feeding moment.

TELL NATHAN
Your device/build; whether controls and sound worked; what felt slow.
Could you land where you meant within ten minutes? Explain silk recovery.
Why did your hunt succeed or fail? Did you stop just to look around?
Did the eye view feel comfortable? Try N: did the notebook open and show
what you discovered? Any missing sound, stuck keys or errors?
Include a screenshot if useful. No telemetry is collected by this game.

The eye view is a research-informed impression. UV is not simulated,
prey is still a fly-like prototype and jump gravity is tuned for play.
Engine and third-party notices: GODOT-LICENSES.txt.

VERIFICATION LIMITS
591 automated Windows tests pass. This rebuild: browser eye rendering,
view switching, walking, slow motion and notebook opening/closing checked;
Windows executable launch/rendering checked. Earlier build also had browser
hop, pause and preference reload checks. Native physical keyboard/controller
play still needs a person because automated native keys had incorrect codes.
Sound needs listener verification. The browser still logs a nonfatal
Chromium UnknownError; its cause remains unresolved. Plugged-in laptop:
T13b eye GPU p95 is 16-19% lower, but whole-run frame p95 is 18.109 ms;
the strict 16.7 ms goal is still missed. Performance data is from the rendered
source runtime, not a release-executable benchmark.
