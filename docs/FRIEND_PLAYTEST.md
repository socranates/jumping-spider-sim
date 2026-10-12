# Friend playtest instructions

THE WINDOWSILL - Friends playtest, 2026-10-12 - days, nights and hunger / LIFE round 1

This is the playable prototype, not the finished whole-life release.
Built from main 5ea6a45; game/test evidence 7c9539fd72c1; Godot 4.7.2.

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
From evening (18:00), resting there sleeps until morning and saves again.
The day passes slowly while active. Hunger thins the abdomen; meals fill it.
Starvation death and moulting are not implemented yet.
On a safety line: W reels up, S lowers; hold Q to let go.
R recenters the camera. H opens field notes. N opens the naturalist notebook
(controller D-pad up); pages open as you discover things. Esc pauses and
opens settings.
Most help assists aiming and holds prey automatically. Reduced motion,
level eye-view horizon, grey eye view, volume and remapping are in Esc.

TRY THIS
Explore the sill and leaves, stalk a fly while it looks away, try a jump,
and return to the silk-lined retreat to rest. Check both camera views.
Stay through dusk and try a night in the crack. Is the dark still readable?
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
600 automated Windows tests pass. Staged native day/night, sleep and body
condition checks passed; the morning checkpoint was kept. Night preserves
large shapes but makes small ground details harder to see, especially in
the eye view. A separate moving-sun frame-time report is in the repository.
Native physical keyboard/controller play and sound listening need people.
This web build: eye view, notebook, walking, view switch, slow motion and
arrow look checked. Embedded browser reported pointer-lock WrongDocumentError
and Chromium UnknownError; mouse-look remains unverified there.
Moving-sun run: about 60 fps average, 17.274 ms p95; strict 16.7 ms target
still missed. Timings are from the source runtime, not the release EXE.
This remains a friend-test prototype, not the full-life release.
