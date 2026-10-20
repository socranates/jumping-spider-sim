# The Windowsill: the store page (ROBLOX-109)

What the experience's page on Roblox needs before publishing: the description, the icon, and three to five thumbnails. The words are a draft for Nathan
to change; the shots are camera positions in the world's own coordinates (studs; one stud is a centimetre; the sill's floor is y 0, the glass at z -12.6,
the outer sill's top y 0 out to the house's face at z -24, the bed's soil y -90), so each can be taken in Studio exactly. Nothing here has been taken in
Studio: the PNGs named below are the off-Roblox previewer's (`roblox_port/tools/preview/scene.py`), which shows shape and placement, not Roblox's
materials, light or depth of field.

## The description (923 characters)

> You are a young jumping spider on a windowsill. You have eight eyes, a line of silk, and one need: to eat today.
>
> The Windowsill is a quiet life sim that tries to be true to its animal. Stalk flies by sight, judge the leap, fix a safety line before you jump and hang from it when you miss. Rest in your silk-lined crack at night. Moult and grow, court a mate, and keep clear of the mud dauber wasp and the other spider that hunts the same sill.
>
> Past the glass is a garden built at a spider's scale, one stud to the centimetre: the stone sill outside, the brick wall with its moths, the bed far below with its woodlice and springtails, the bushes, the drainpipe to the gutter. A naturalist's notebook fills as you notice things, each page drawn from published research.
>
> Normal is hungry and does not forgive: a death loses the day. Free play has gentle rules. Settings cover the controls, the camera, text size and motion.

(Every claim is in the game now: the notebook's sources are `docs/NOTEBOOK_SOURCES.md`; "a death loses the day" is Normal's end card, ROBLOX-106; the regions
are ROBLOX-94 to ROBLOX-107. Roblox allows 1,000 characters.)

## The icon

**Concept**: the spider itself, close, at the mouth of its crack in the morning: three-quarter front and low, its two big front eyes catching the light, the
dark of the crack and two strands of its silk behind, the pale sill floor under it. No words (the name is beside the icon everywhere it is shown), no border;
it must read at 50 pixels as "a small dark animal with big eyes looking at you".

**Preview**: `store_icon` in the previewer (`python3 tools/preview/scene.py <luau> <godot> <out> --world --size 1024x1024 --views store_icon`): camera at
(-19.4, 0.8, 7.6) looking at (-22.0, 0.42, 6.0), field of view 32 degrees, the spider at the spawn (-22, 0, 6) facing +x. It is a credible composition but not
a finished icon (the previewer's light is flat and its materials are stand-ins). The render is `docs/store/icon_preview.png`; `docs/store/` also has the title card and two of the intro's captions mocked over the previewer's frames (`tools/preview/title_mock.py`). Take it in Studio from the same camera (below), at 1024 by 1024, at about
09:30, and grade it warm and a little darker round the edges.

## The thumbnails (1920 by 1080, in this order)

| # | What it shows | Camera (eye, looking at), field of view | When |
|---|---|---|---|
| 1 | **The spider at its crack**: the first moment of a life, the spider just out of the silk-lined crack | (-18.6, 0.9, 8.4) at (-22.4, 0.5, 5.6), 40 degrees (previewer view `store_spider`) | 09:00, a new life (the intro's last shot) |
| 2 | **The window from outside**: the garden's side of the glass, the window boxes, the sill beyond: the title card's frame | (10, 6.5, -45) at (0, 2.5, -14), 46 degrees (`title_drift_36`, `--title`) | 09:00 to 10:00 |
| 3 | **Through its eyes**: the spider-eye view (V) on a fly on the sill floor, the principal eyes' sharp strip | The game's eye view from the spawn (previewer `eye_side`: (-21.47, 0.39, 6.0) at (-12, 0.9, 3.2), 90 degrees) | 12:00, a fly on the floor |
| 4 | **Down the wall on silk**: hanging on the dragline against the brick under the outer sill, the bed far below | (6, -36, -31) at (2, -40, -24.31), 60 degrees (`descent`); the spider let down from the outer sill's front edge | 15:00 |
| 5 | **The bed at dusk**: low over the soil by the stone, the dock and its aphids, a moth at the wall | (-4, -84.5, -31) at (-12, -87.5, -42), 46 degrees (`bed_life`) | 19:30 (the moths fly from dusk) |

How to take one in Studio: open `TheWindowsill.rbxlx`, Play, begin a life (or Continue), play or rest to the hour, then in the command bar with the client
selected: `local c = workspace.CurrentCamera; c.CameraType = Enum.CameraType.Scriptable; c.FieldOfView = 40; c.CFrame = CFrame.lookAt(Vector3.new(-18.6, 0.9, 8.4), Vector3.new(-22.4, 0.5, 5.6))`
(the numbers of the row). The game puts its camera back the next frame while a life is running, so either take the screenshot from a paused frame (the life
menu open: the game does not render its camera while a screen is up, and the menu can be hidden with `game.Players.LocalPlayer.PlayerGui.SpiderLifeMenu.Enabled = false`)
or set the camera from a `RenderStepped` connection in the command bar. Hide the HUD for the shot (`...PlayerGui.SpiderHud.Enabled = false`, the same for
`SpiderPrompts` and `SpiderTouch`). Roblox's own screenshot (the menu's camera button, or F12 in Studio's toolbar setting) at 1920 by 1080.

Previews of each row: `--world --title --views store_spider,title_drift_36,eye_side,descent,bed_life` (the `eye_side` view is the previewer's stand-in for the
eye view's picture, without its optics).

## Not done here

- No screenshot was taken in Studio and nothing was uploaded. The icon and the thumbnails are Nathan's to take and choose; the rows are a plan.
- The description has not been checked against Roblox's text filter.
