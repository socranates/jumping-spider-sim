# Chet acceptance: settings accepted and published v20 — Chet, 2026-10-18

Claude's settings bundle 9c63783 is integrated. Build **d89045d8f2212cda**: **47,547 CLI checks**, **111/111 Studio engine checks (zero skipped)** and **24/24 live-client checks** pass; strict analysis clean, **167/167** scripts compile. Native tests include real TextService measurements and isolated real DataStore operations. Chet also changed normal-game volume to 75% and enabled large text, stopped and restarted Play, and saw both choices restored from the cloud.

Published **v20** to the existing Windowsill place **120119801868085**, confirmed in Creator Dashboard's published-only history. No audience/security/monetization changes. Evidence: `docs/verification/roblox-settings-windows/RESULTS.md`; decision ROBLOX-53. Daughter's spider/game remain free; peacock remains free for testing, with Nathan's future ~US$0.99 cosmetic-pass target preserved.

Next chunk: release presentation (icon, thumbnail and accurate description of modes/saves) plus notebook science/source review. Start with Nathan's PlayStation/tablet feedback and repair usability issues first. Narrow-phone large-text landscape is usable by scrolling but cramped: a slider's label and buttons may not be visible together. Consider a more compact short-screen layout. Do not claim physical-device or F01 acceptance from emulator results. Nathan still needs a complete life and settings leave/rejoin on PlayStation and tablet, and must handle account identity/security/content/fee screens himself before a public release. Godot stays frozen; keep twitch and SimClock.

---

# Settings and device polish - 2026-10-18

Branch `claude/roblox-settings` from main 3b8a919 (v19 published). Decisions ROBLOX-49 to ROBLOX-52 in `DECISIONS.md`. Nothing here is published. Nothing has been seen in Studio or on a device: the CLI checks the rules, the layout geometry and the real client scripts on the shim; Studio measures real text. Physical PlayStation and tablet acceptance are still Nathan's.

## What was built

- **The table and the rules** (pure, CLI-tested): `Shared/Data/SettingsSpec.luau` (22 settings, four sections, the panel's words), `Shared/UI/SettingsModel.luau` (clean, step, fraction, value text, migrate hook), `Shared/UI/SettingsNav.luau` (which row is chosen; Up/Down, sections), `Shared/UI/SettingsText.luau` (the lines for each device, metrics and row layout at any screen size and text size).
- **Saved**: `Shared/Persistence/SaveProgress.luau` schema 2 (`settings`, `settings_version`; migration from the seven `prefs` toggles); the server cleans every value by id, type and range. `SaveRules.PREF_KEYS` is gone (the table is the list).
- **The panel**: `Client/SettingsPanel.luau`; opened with O, or Menu then Settings; modal (the world waits); keyboard, controller and touch; Reset takes two presses.
- **Live consumers**: sound volumes and captions (`Soundscape`, `SpiderHud`), look speeds, inversion, field of view, distance, the framing switch and the level horizon (`SpiderCamera`, `CameraMath.viewUp`), the grey eye view (`SpiderEyes`), control hints and the older toggles (`SpiderClient`). Each reads its Player attribute every frame, so a change shows at once.
- **Touch**: `HudLayout.topLayout` (Menu and Notebook, 48 px, laid out with the status lines); Focus one row up on phones under 400 px wide and Change 6 px up, so no touch buttons meet.
- **Studio**: `tests/studio/SettingsSpec.luau` (registered in the Runner as "Settings spec completes").

## The 22 settings (defaults)

| Section | Setting | Default | Range / options |
|---|---|---|---|
| Sound | Mute all sound (`SoundMuted`) | off | |
| | Volume (`MasterVolume`) | 100% | 0 to 100%, steps of 5 |
| | Room sounds and birds (`AmbienceVolume`) | 100% | same |
| | Flies and the wasp (`CreatureVolume`) | 100% | same |
| | Captions for sounds and vibrations (`Captions`) | Normal | Off, Normal, Large |
| Camera | Mouse look speed (`LookSensitivityMouse`) | 1x | 0.2 to 3x, steps of 0.05 |
| | Stick look speed (`LookSensitivityStick`) | 1x | same |
| | Touch drag look speed (`LookSensitivityTouch`) | 1x | same |
| | Invert look up and down (`InvertY`) / left and right (`InvertX`) | off | |
| | Camera distance (`CameraDistance`) | 5.0 studs | 4 to 7, steps of 0.1 |
| | Field of view (`FieldOfView`) | 65 degrees | 50 to 90 (the spider-eye view keeps 90) |
| | Frame the line after a catch (`FrameLine`) | on | |
| Comfort and accessibility | Reduced motion (`ReducedMotion`) | off | |
| | Large text (`LargeText`) | off | 1.5x |
| | Focus toggles (`FocusToggle`) | off | |
| | Struggling prey: hold on automatically (`AutomaticGrip`) | off | |
| | Show the last-seen mark (`ShowLastSeen`) | on | |
| | Spider-eye view: level horizon (`EyeLevelHorizon`) | off | |
| | Spider-eye view: grey instead of green (`EyeGrey`) | off | |
| Help and hints | Show control hints (`ControlHints`) | on | the controls card and the walking reminder; prompts that say what a button does right now stay |
| | Say when a new notebook page opens (`NotebookNotes`) | on | |

## Evidence (CLI, Windows VM luau)

SETTINGS 923 (new), STATE 432, STATE_CLIENT 102, STATE_OFFLINE 8, SUMMARY 189, NOTEBOOK 813, all failed=0; every other suite unchanged (CHECKPOINT 156, CONTINUING 87, EYES 231, FLIES 187, GAZE 67, GROWTH 433, HUD 69, LIFE 20,846, LOOK 102, PEACOCK 80, PERCEPTION 4,669, PERCEPTION_CLIENT 1, PRESENTATION 11, PREY 1,549, SENSOR 507, WASP 15,815, WORLD 230, BOXWORLD 15, CLIENT 23). Total 47,545. `check.sh types` 0 diagnostics; compile 172/172. NOTEBOOK went from 889 to 813 because the 5-size loop that checked the Notebook button's place (and clearance from the touch buttons) at 36 px moved into tests/run.luau as the 13-size matrix for Menu, Notebook and every touch button (SUMMARY 185 to 189) and a check that the real buttons sit where the layout puts them. Places rebuilt (`tools/build.py`), evidence stamped in `BuildInfo.luau`.

What SETTINGS covers: the table (unique ids, ranges on a step grid, defaults inside, who reads which), clean/step/value text, the nav (wrap, sections), the lines for each device and PlayStation names, the layout matrix at 10 screen sizes and both text sizes (every control inside its row, apart from the others, at least 44 px), the panel's keys, stick, hold-to-run, mouse, tap and drag, Reset's two presses and close behaviour, the camera maths for the level horizon, the sound mix, and the **real client**: defaults read, O and the menu open and close it, the world waits, volumes reach the sound, field of view/distance/framing/level horizon/grey/captions/hints reach their parts, look speed and inversion through the stick, a panel change sets the attribute the game reads, Reset, and the Menu, Notebook and every touch button at 8 screen sizes. STATE covers the migration and server-side cleaning.

## Chet's Studio checklist

1. Run the Runner on `TheWindowsillTests.rbxlx`. New: "Settings spec completes" with four checks - the table survives the engine's JSON and the saved envelope unchanged; every label, note, value, the controls line and the Reset/Back words fit their places at nine screen sizes and both text sizes with **real** TextService measurements (this is the check most likely to fail: the CLI only approximates text widths; if one fails, the message names the setting, the screen and the size - please paste it); the Menu and Notebook words fit their buttons; the panel is built with real property names (22 rows, 4 headers, every control at least 44 px tall).
2. Previous specs unchanged. Please report the new engine total (it was 106 + the earlier suites; the settings add 4).
3. Play the default project, open O, change a few settings, leave and rejoin (API access on, test store): the settings are back. Turn API access off: the panel says "Saving is off for this visit, so these settings last only until you leave."
4. Do not publish until Nathan has looked at the PlayStation and tablet items below.

## What Nathan should check

**PlayStation (a complete life):**
- Press the Touchpad (the menu), choose **Settings**. The line under the list should say Cross: switch, L1 and R1: sections, Circle: back.
- Left stick or D-pad moves between settings and changes sliders; hold left or right to run a slider. The right stick scrolls. L1/R1 jump between sections. Circle goes back to the menu.
- Turn Volume down, turn Captions to Large, turn Invert up and down on: they should take effect at once when you go back to the game.
- Is the panel's text readable on the TV from where you sit? Is the Reset button's two-press question clear?
- Leave and rejoin: your settings should still be set.

**Phone and lower-end tablet:**
- Menu and Notebook buttons: easy to hit with a thumb, not under any other button or text, in both ways up. Open Menu, then Settings.
- Tap a switch; tap - and + on a slider; drag a bar. Scroll the list by dragging.
- Look speed: touch drag look speed should change how far a drag turns the view.
- Turn Large text on: rows stack (control under the label) and nothing is cut off.
- Narrow phone in portrait: the Focus button should sit above the left thumb's arrows, not on top of them.
- Frame rate is not measured here (no performance pass was made).

## Deliberately simplified or unverified

- The CLI measures text with a rough width estimate; real widths are checked in Studio only. The panel's heights come from `TextService` at run time, so a wrong estimate here does not break the panel, only the tests' margin.
- No remapping, no per-device storage, no screen-reader work, no graphics-quality setting (ROBLOX-52). Godot's stalk and jump-aim toggles, jump arc, strike assist, headphones, rumble and slow-motion speed are not settings because the port has no such part.
- The level horizon and the grey eye view are tested as maths and as the values given to the camera and the colour grade; how they look is Nathan's eye.
- Camera distance: after a change in the panel the wheel zooms from the new distance (a setting-changed distance starts the camera there).
- Changing the field of view during the spider-eye view takes effect when you leave it.
- Settings are one set per player (not per device).
- The panel keeps no history: Reset puts every setting back to its default, and cannot be undone.
- Windows review: a saved settings version newer than this build knows makes the visit read-only. Preserve the whole stored record rather than dropping unknown choices and writing a downgraded version.

## Commits

cce2a5d (table and model), e913508 (saved schema 2), 99f1de0 (panel and live consumers), 61c8cf0 (touch polish), plus the Studio spec, docs and rebuilt places commit.
