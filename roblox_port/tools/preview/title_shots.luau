-- The first minute's camera frames (ROBLOX-109, Shared/Movement/TitleShots.views) as the previewer's views: one line each, name eye at fov, for scene.py --title.
local TitleShots = require("../src/Shared/Movement/TitleShots")
for _, view in TitleShots.views() do
	print(string.format("%s %.3f %.3f %.3f %.3f %.3f %.3f %.1f", view.name, view.eye.X, view.eye.Y, view.eye.Z, view.at.X, view.at.Y, view.at.Z, view.fov))
end
