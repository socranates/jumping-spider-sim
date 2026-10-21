# The Windowsill: the store page (ROBLOX-109)

What the experience's page on Roblox needs before publishing: the description, the icon, and three to five thumbnails. The words are a draft for Nathan
to change; the shots are camera positions in the world's own coordinates (studs; one stud is a centimetre; the sill's floor is y 0, the glass at z -12.6,
the outer sill's top y 0 out to the house's face at z -24, the bed's soil y -90), so each can be taken in Studio exactly. Nothing here has been taken in
Studio: the PNGs named below are the off-Roblox previewer's (`roblox_port/tools/preview/scene.py`), which shows shape and placement, not Roblox's
materials, light or depth of field.

## The description (ROBLOX-118: the preserve is the game; 856 characters)

> You are a young jumping spider, born on the windowsill of a ranger's hut in a small nature preserve in the middle of a city. You have eight eyes, a line of silk, and one need: to eat today.
>
> The Windowsill is a quiet life sim that tries to be true to its animal. Stalk flies by sight, judge the leap, fix a safety line before you jump and hang from it when you miss. Moult behind the glass until the ranger props the window open, then go out: down the logs to the garden's milkweed, coneflowers and gravel paths, built at a spider's scale, one stud to the centimetre. Keep clear of the mud dauber wasp, the other spider, and the ranger's cat: you will hear its bell first.
>
> A naturalist's notebook fills as you notice things, each page drawn from published research. Normal is hungry and does not forgive: a death loses the day. Free play has gentle rules.

(Every claim is in the game now: the hut, the nursery's window and the ranger are ROBLOX-116, the garden ROBLOX-116/117, the cat ROBLOX-118; the notebook's
sources are `docs/NOTEBOOK_SOURCES.md`; "a death loses the day" is Normal's end card, ROBLOX-106. Roblox allows 1,000 characters. The test garden's description,
before ROBLOX-118, spoke of a house, a brick wall and a bed: the published game is the preserve now.)

## The icon

**Concept**: the spider itself, close, at the mouth of its crack in the morning: three-quarter front and low, its two big front eyes catching the light, the
dark of the crack and two strands of its silk behind, the pale sill floor under it. No words (the name is beside the icon everywhere it is shown), no border;
it must read at 50 pixels as "a small dark animal with big eyes looking at you".

**Preview**: `store_icon` in the previewer (`python3 tools/preview/scene.py <luau> <godot> <out> --world --size 1024x1024 --views store_icon`): camera at
(-19.4, 0.8, 7.6) looking at (-22.0, 0.42, 6.0), field of view 32 degrees, the spider at the spawn (-22, 0, 6) facing +x. It is a credible composition but not
a finished icon (the previewer's light is flat and its materials are stand-ins). The render is `docs/store/icon_preview.png`; `docs/store/` also has the title card and two of the intro's captions mocked over the previewer's frames (`tools/preview/title_mock.py`). Take it in Studio from the same camera (below), at 1024 by 1024, at about
09:30, and grade it warm and a little darker round the edges.

## The thumbnails (1920 by 1080, in this order; ROBLOX-118: the preserve's)

| # | What it shows | Camera (eye, looking at), field of view | When |
|---|---|---|---|
| 1 | **The spider at its crack**: the first moment of a life, the spider just out of the silk-lined crack in the hut's sill | (-18.6, 0.9, 8.4) at (-22.4, 0.5, 5.6), 40 degrees (previewer view `store_spider`) | 09:00, a new life (the intro's last shot) |
| 2 | **The hut's window from inside**: the morning through the glass over the sill, the hut garden and the city beyond (the intro's first shot in the preserve) | (-6.5, 7.75, 29) at (-1.5, 12.5, -13.5), 58 degrees (`preserve_intro_glass`, `--preserve`) | 09:00 |
| 3 | **The cat at the window**: the ranger's cat on the back room's sill | (385, 12, 104) at (440, 16, 134), 52 degrees (`cat_window`, `--preserve --cats window`) | when its day puts it there (`Predator/Cat.plan`) |
| 4 | **The garden at the spider's eye**: in the mulch by the milkweed | the eye at (22.5, -73.9, -246.2) at (60, -72, -258), 75 degrees (`pb_eye_mulch`, `--preserve --looks-at 22,-74.29,-246`) | 07:00, the dew still on |
| 5 | **The hut from the garden**: the log hut and its back room under the green roof, the beds and the fence | (380, 60, -1250) at (0, 30, -16), 55 degrees (`preserve_drift_0`) | 10:00 |

How to take one in Studio: open `TheWindowsill.rbxlx` (the preserve is its default world since ROBLOX-118), Play, begin a life (or Continue), play or rest to the hour, then in the command bar with the client
selected: `local c = workspace.CurrentCamera; c.CameraType = Enum.CameraType.Scriptable; c.FieldOfView = 40; c.CFrame = CFrame.lookAt(Vector3.new(-18.6, 0.9, 8.4), Vector3.new(-22.4, 0.5, 5.6))`
(the numbers of the row). The game puts its camera back the next frame while a life is running, so either take the screenshot from a paused frame (the life
menu open: the game does not render its camera while a screen is up, and the menu can be hidden with `game.Players.LocalPlayer.PlayerGui.SpiderLifeMenu.Enabled = false`)
or set the camera from a `RenderStepped` connection in the command bar. Hide the HUD for the shot (`...PlayerGui.SpiderHud.Enabled = false`, the same for
`SpiderPrompts` and `SpiderTouch`). Roblox's own screenshot (the menu's camera button, or F12 in Studio's toolbar setting) at 1920 by 1080.

Previews of each row: `--preserve --cats window --views store_spider,preserve_intro_glass,cat_window,preserve_drift_0`, and `pb_eye_mulch` with `--looks-at` in the mulch.

## Not done here

- No screenshot was taken in Studio and nothing was uploaded. The icon and the thumbnails are Nathan's to take and choose; the rows are a plan.
- The description has not been checked against Roblox's text filter.
