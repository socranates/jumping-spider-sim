-- Persistent saves with no server at all (ROBLOX-39): the real client in a place that is not the test place, with no remotes. It is the game
-- it was before saves existed: after a moment's wait for a server that is not there the start menu opens, offers a new life and Free
-- play (no Continue, no Easy), and says plainly that saving is off and why. Run with the other suites:  python3 tests/run.py path/to/luau state_offline.luau
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
local SaveText = require("../src/Shared/UI/SaveText")
local SaveClient = require("../src/Client/SaveClient")
-- Render work in the shim is CPU-dependent. Control only the save transport's wall
-- clock so thirty expensive frames cannot accidentally expire its real-time deadline.
local transportNow = 0
local originalNew = SaveClient.new
SaveClient.new = function(cfg: any): any
	local testConfig = table.clone(cfg)
	testConfig.now = function() return transportNow end
	return originalNew(testConfig)
end
local passed, failed = 0, 0
local function check(ok: boolean, what: string)
	if ok then passed += 1 else failed += 1; print("FAIL [offline] " .. what) end
end
local pieces = {}
for _, p in Layout.PIECES do table.insert(pieces, { name = p.id, lo = p.lo, hi = p.hi, profile = p.profile }) end
BoxWorld.folder("Windowsill", pieces)
local hook = ClientStubs.scriptFolder:FindFirstChild("SilkPlayback")
if hook then hook:Destroy() end -- not the test place: the menu opens by itself
local loaded, loadError = pcall(function() require("../src/Client/SpiderClient.client") end)
if not loaded then print("LOAD ERROR", loadError) end
local frame = ClientStubs.renderSteps.SpiderSim
local gui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
local function find(screen: string, name: string): any
	local g = gui:FindFirstChild(screen)
	if not g then return nil end
	for _, d in g:GetDescendants() do if d.Name == name then return d end end
	return nil
end
local function menuShowing(): boolean
	local g = gui:FindFirstChild("SpiderLifeMenu")
	return g ~= nil and g.Enabled == true
end
check(loaded, "the client loads with no remotes")
for _ = 1, 30 do frame(1 / 60) end
check(not menuShowing(), "the menu waits a moment for a server (the world holds)")
transportNow = 1.7
for _ = 1, 30 do frame(1 / 60) end
check(menuShowing(), "then the start menu opens")
local summary = find("SpiderLifeMenu", "Summary")
check(summary ~= nil and string.find(summary.Text, "Saving is off for this visit", 1, true) ~= nil, "and says saving is off")
check(summary ~= nil and string.find(summary.Text, SaveText.WHY.offline, 1, true) ~= nil, "and why")
check(find("SpiderLifeMenu", "New") ~= nil and find("SpiderLifeMenu", "Free") ~= nil, "a new life and Free play are offered")
check(find("SpiderLifeMenu", "Continue") == nil and find("SpiderLifeMenu", "Easy") == nil, "no Continue and no Easy: nothing was saved")
local toast = find("SpiderPrompts", "Toast")
check(toast ~= nil and string.find(toast.Text, "Saving is off", 1, true) ~= nil, "a toast said it too")
print(`STATE_OFFLINE passed={passed} failed={failed}`)
