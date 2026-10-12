# Friend playtest instructions

THE WINDOWSILL - Friends playtest, 2026-10-11

This is the playable prototype, not the finished whole-life release.
Built from main 48b84a0; game/test evidence db112e2fa006; Godot 4.7.2.

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
R recenters the camera. H opens field notes. Esc pauses and opens settings.
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
Did the eye view feel comfortable? Any missing sound, stuck keys or errors?
Include a screenshot if useful. No telemetry is collected by this game.

The eye view is a research-informed impression. UV is not simulated,
prey is still a fly-like prototype and jump gravity is tuned for play.
Engine and third-party notices: GODOT-LICENSES.txt.

VERIFICATION LIMITS
585 automated Windows tests pass. Browser walking, hop, view switch,
slow motion, pause and one preference reload were checked. Native export
rendering was checked; physical keyboard/controller play still needs a
person because automated native keys had incorrect physical key codes.
Sound should be checked by listeners. The browser logged a nonfatal
Chromium UnknownError; its cause remains unresolved. The eye view is
slower than third person on this laptop; the 60 fps p95 target is not met.
