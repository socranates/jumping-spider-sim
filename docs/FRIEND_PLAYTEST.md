> **Godot-era document (2026-10-13); the Roblox playtest is described in docs/HANDOFF-roblox-*.md.**

# Friend playtest instructions

THE WINDOWSILL — Whole-life friend playtest, 2026-10-13

A playable prototype with hunting, hunger, days/nights, three moults,
a mud dauber wasp, death and continuing. This is not the finished release.
Godot 4.7.2; Windows correctness evidence 2c1c789ef545 (644 tests).
The ZIP filename and BUILD.txt identify its exact game source commit.

WINDOWS: Extract the whole ZIP and run TheWindowsill.exe. Keep
TheWindowsill.pck beside it. Godot need not be installed.
WEB: Hosting bundle, with index.html at ZIP root. Serve over HTTP/HTTPS;
opening the file directly is unsupported. Not published to itch.io yet.
Browser saves belong to the browser/site and can be lost with site data.

START: Standard is the main life. Free play is gentle and has its own save.
An adult of the main life unlocks Easy. Arrow keys, D-pad or stick move
menu focus; Enter/Space/A accepts. Mouse buttons also work.

PLAY: WASD walk; mouse or arrows look; Shift creep; right mouse Focus.
Tap Space to hop, hold/release to aim/jump; Q cancels. V switches views.
T toggles slow motion. Tap Space or E rapidly after catching prey, or use
the automatic grip option. E rests in the silk-lined crack and saves;
at night it sleeps until morning. Eat enough, then rest there to moult.
F lets down on silk (walks to an edge first where needed); hold to lower.
On a line W reels up, S lowers; hold Q to let go. R recenters the camera.
N opens the sourced notebook. H shows help. Esc opens settings/assists.
Try Most help for easier aiming/holding prey, and Reduced motion if wanted.

LIFE: Starvation warns before it ends a Standard life. The wasp warns
before arriving; stay alert and find cover. At the end, return to your
last rest or continue as an unrelated young spider elsewhere. The notebook
stays. Free play and Easy cannot kill your spider.

TELL NATHAN: Your device/build, time played, controls and sound, what felt
slow or confusing, and whether the wasp felt fair. Could you find home,
hunt, rest, moult and understand continuing? Did you stop to look around?
Was large text readable and the eye view comfortable? A screenshot helps.
No telemetry is collected by this game.

LIMITS: Staged Windows life-flow checks and release keyboard/mouse menus
passed; real controller hardware, speaker listening and a human whole-life
playthrough remain for this round. The wasp arrival hitch improved on this
laptop, but some frames still exceed the target. Embedded-browser pointer
lock failed; try mouse-look in your normal browser and report problems.
Web menu and eye shader render. Live HUD can crowd at maximum text size.
Eye view is a research-informed impression: UV is not simulated, prey is
still a fly-like prototype, and jump gravity is tuned for play.
Engine and third-party notices: GODOT-LICENSES.txt.
