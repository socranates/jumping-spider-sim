-- Persistent saves, the client's side (ROBLOX-39): the words, SaveClient on a fake clock and fake remotes, and the real SpiderClient on the
-- shim with a scripted server: it waits for the server's word before the start menu, applies the notebook, the adult life, the spider, the
-- toggles and the rests it is sent, sends up only what the player changed, says plainly when saving is off, and a rest the real client
-- captures passes the server's own check. Not engine evidence (no RemoteEvents, no DataStore): docs/HANDOFF-roblox-state.md lists what Studio checks.
-- Run with the other suites:  python3 tests/run.py path/to/luau state_client.luau
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
local Json = require("../src/Shared/Persistence/Json")
local SaveRules = require("../src/Shared/Data/SaveRules")
local SaveProgress = require("../src/Shared/Persistence/SaveProgress")
local SaveRest = require("../src/Shared/Persistence/SaveRest")
local SaveText = require("../src/Shared/UI/SaveText")
local SaveClient = require("../src/Client/SaveClient")

local passed, failed = 0, 0
local current = ""
local function check(ok: boolean, what: string): boolean
	if ok then passed += 1 else failed += 1; print(`FAIL [{current}] {what}`) end
	return ok
end
local function case(name: string, fn: () -> ())
	current = name
	local ok, err = xpcall(fn, debug.traceback)
	if not ok then failed += 1; print(`FAIL [{name}] raised: {tostring(err)}`) end
end
local function canon(v: any): string
	return (Json.canonical(v)) or "?"
end

-- ---------------------------------------------------------------------------------------------- the words
case("the words: saved, saving, trouble and off each say what is true, with the reason; a flicker is not announced", function()
	check(SaveText.menuLine("saved", nil) == SaveText.SAVED and string.find(SaveText.SAVED, "saved", 1, true) ~= nil, "saved")
	check(SaveText.menuLine("saving", nil) == "Saving...", "saving")
	check(string.find(SaveText.menuLine("saving", "write_failed"), "trouble", 1, true) ~= nil, "trouble")
	check(SaveText.menuLine(nil, nil) == SaveText.LOOKING, "not yet known")
	for _, reason in SaveRules.REASONS do
		if reason ~= "write_failed" then
			local line = SaveText.menuLine("session", reason)
			check(string.find(line, "Saving is off", 1, true) ~= nil and SaveText.WHY[reason] ~= nil and string.find(line, SaveText.WHY[reason], 1, true) ~= nil, `off: {reason}`)
		end
	end
	check(string.find(SaveText.menuLine("session", "something_new"), "Saving is off", 1, true) ~= nil, "an unknown reason still says it is off")
	check(string.find(SaveText.WHY.corrupt, "left exactly as it is", 1, true) ~= nil and string.find(SaveText.WHY.newer, "left exactly as it is", 1, true) ~= nil, "damaged and newer records say they were left alone")
	check(SaveText.toast(nil, nil, "session", "offline") ~= "" and string.find(SaveText.toast("saved", nil, "session", "other_session"), "Saving is off", 1, true) ~= nil, "going off is announced")
	check(SaveText.toast("session", "offline", "saved", nil) == SaveText.BACK, "coming back is announced")
	check(SaveText.toast("saved", nil, "saving", nil) == "" and SaveText.toast("saving", nil, "saved", nil) == "" and SaveText.toast(nil, nil, "saved", nil) == "", "saving and saved are not announced")
	check(SaveText.toast("saving", nil, "saving", "write_failed") == SaveText.TROUBLE and SaveText.toast("saving", "write_failed", "saving", "write_failed") == "", "trouble is announced once")
	for _, t in { SaveText.SAVED, SaveText.OFF, SaveText.TROUBLE, SaveText.LOOKING, SaveText.BACK } do
		check(not string.find(t, "[\128-\255]"), "plain ASCII words: " .. t)
	end
end)

-- ---------------------------------------------------------------------------------------------- SaveClient on a fake clock
local function fakeRemotes(): any
	local r: any = { fired = {} :: { any }, handlers = {} :: { (any) -> () } }
	r.server = { FireServer = function(_self: any, msg: any) table.insert(r.fired, Json.copy(msg)) end }
	r.client = { OnClientEvent = { Connect = function(_self: any, fn: (any) -> ()) table.insert(r.handlers, fn) end } }
	function r.deliver(msg: any) for _, h in r.handlers do h(msg) end end
	return r
end
local function newClient(opts: { [string]: any }?): any
	local o: any = opts or {}
	local c: any = { t = 0, remotes = nil, loaded = {}, rests = {}, statuses = {}, builds = 0 }
	c.client = SaveClient.new({
		rules = SaveRules, now = function(): number return c.t end,
		findRemotes = function(): any if c.remotes then return { server = c.remotes.server, client = c.remotes.client } end return nil end,
		onLoaded = function(m: any) table.insert(c.loaded, m); if o.raise then error("the game's handler broke") end end,
		onRest = function(mode: string, rec: any) table.insert(c.rests, { mode, rec }) end,
		onStatus = function(s: string, r: string?) table.insert(c.statuses, s .. ":" .. tostring(r)) end,
		build = function(): any c.builds += 1; return { n = c.builds } end,
	})
	function c.advance(seconds: number, step: number?)
		local dt = step or 0.1
		for _ = 1, math.floor(seconds / dt + 0.5) do
			c.t += dt
			c.client:update()
		end
	end
	return c
end

case("SaveClient: with no remotes the wait is short, then it is offline; remotes that show up later are used", function()
	local c = newClient()
	check(c.client:waiting() and select(1, c.client:status()) == nil, "at first: waiting, nothing to say")
	c.advance(1.0)
	check(c.client:waiting(), "still waiting at 1 s")
	c.advance(0.6)
	check(not c.client:waiting(), "not waiting after the remotes' wait")
	local st, why = c.client:status()
	check(st == "session" and why == "offline", "offline")
	c.remotes = fakeRemotes()
	c.advance(0.2)
	check(#c.remotes.fired == 1 and c.remotes.fired[1].kind == "hello" and c.remotes.fired[1].v == SaveRules.PROTOCOL, "the late remotes get a hello")
	c.remotes.deliver({ kind = "loaded", status = "saved", progress = SaveProgress.default(), rests = {} })
	check(c.client:connected() and select(1, c.client:status()) == "saved" and #c.loaded == 1, "and a reply makes it connected")
end)

case("SaveClient: hello is repeated until answered, a bounded number of times; waiting for a reply ends", function()
	local c = newClient()
	c.remotes = fakeRemotes()
	c.advance(1)
	check(#c.remotes.fired == 1, "one hello")
	c.advance(1.4)
	check(#c.remotes.fired == 1, "not again within 2.5 s")
	c.advance(0.3)
	check(#c.remotes.fired == 2, "again after 2.5 s")
	check(c.client:waiting(), "waiting for the first reply")
	c.advance(10)
	check(not c.client:waiting(), "the wait for a reply ends")
	check(#c.remotes.fired <= SaveRules.CLIENT_HELLO_TRIES, `at most {SaveRules.CLIENT_HELLO_TRIES} hellos ({#c.remotes.fired})`)
	check(select(1, c.client:status()) == "session" and select(2, c.client:status()) == "offline", "no reply: session only")
	c.remotes.deliver({ kind = "loaded", status = "saved", progress = SaveProgress.default(), rests = {} })
	check(select(1, c.client:status()) == "saved" and not c.client:waiting(), "a late reply still counts")
end)

case("SaveClient: progress is coalesced to one message per gap, built only when sent; rests go separately, one per mode per gap, newest wins", function()
	local c = newClient()
	c.remotes = fakeRemotes()
	c.advance(0.2)
	c.remotes.deliver({ kind = "loaded", status = "saved", progress = SaveProgress.default(), rests = {} })
	c.remotes.fired = {}
	c.client:markDirty()
	c.client:markDirty()
	c.advance(0.2)
	local sent = 0
	for _, m in c.remotes.fired do if m.kind == "progress" then sent += 1 end end
	check(sent == 1 and c.builds == 1, "marked twice, built and sent once")
	c.client:markDirty()
	c.advance(1.0)
	check(c.builds == 1, "inside the gap: not sent yet")
	c.advance(1.2)
	check(c.builds == 2, "after the gap: sent")
	c.client:markDirty()
	c.advance(0.1)
	check(c.builds == 2, "and the gap restarts")
	local before = #c.remotes.fired
	c.client:sendRest("main", { first = true })
	c.client:sendRest("main", { second = true })
	c.client:sendRest("free", { free = true })
	c.advance(0.3)
	local rests: { any } = {}
	for i = before + 1, #c.remotes.fired do if c.remotes.fired[i].kind == "rest" then table.insert(rests, c.remotes.fired[i]) end end
	check(#rests == 2, `one per mode ({#rests})`)
	local main: any = nil
	for _, m in rests do if m.mode == "main" then main = m end end
	check(main ~= nil and main.record.second == true and main.record.first == nil, "the newest main rest")
	c.client:sendRest("main", { third = true })
	c.advance(1.0)
	local n = 0
	for _, m in c.remotes.fired do if m.kind == "rest" and m.record.third then n += 1 end end
	check(n == 0, "a second main rest waits for its gap")
	c.advance(4.0)
	n = 0
	for _, m in c.remotes.fired do if m.kind == "rest" and m.record.third then n += 1 end end
	check(n == 1, "and goes after it")
end)

case("SaveClient: messages from the server that are junk, or that break the game's handler, never raise or stop it", function()
	local c = newClient({ raise = true })
	c.remotes = fakeRemotes()
	c.advance(0.2)
	for _, junk in { "x", 5, true, {}, { kind = 7 }, { kind = "nope" }, { kind = "rest" }, { kind = "rest", mode = 5 } } do
		local ok = pcall(c.remotes.deliver, junk)
		check(ok, "junk handled: " .. tostring(junk))
	end
	local ok = pcall(c.remotes.deliver, { kind = "loaded", status = "saved", progress = {}, rests = {} })
	check(ok, "a handler that raises does not raise out of the event")
	c.advance(0.1)
	check(true, "and the client still runs")
end)

-- ---------------------------------------------------------------------------------------------- the real client, a scripted server
local pieces = {}
for _, p in Layout.PIECES do table.insert(pieces, { name = p.id, lo = p.lo, hi = p.hi, profile = p.profile }) end
BoxWorld.folder("Windowsill", pieces)
workspace:SetAttribute("SaveWait", true)
local R = fakeRemotes()
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = SaveRules.REMOTES_NAME
local toServer = Instance.new("Folder")
toServer.Name = "ToServer"
rawset(toServer, "FireServer", R.server.FireServer)
toServer.Parent = remotesFolder
local toClient = Instance.new("Folder")
toClient.Name = "ToClient"
rawset(toClient, "OnClientEvent", R.client.OnClientEvent)
toClient.Parent = remotesFolder
remotesFolder.Parent = game:GetService("ReplicatedStorage")
local loadedOk, loadError = pcall(function() require("../src/Client/SpiderClient.client") end)
if not loadedOk then print("LOAD ERROR", loadError) end
local frame = ClientStubs.renderSteps.SpiderSim
local gui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
local lp: any = game:GetService("Players").LocalPlayer
local function frames(n: number) for _ = 1, n do frame(1 / 60) end end
local function find(screen: string, name: string): any
	local g = gui:FindFirstChild(screen)
	if not g then return nil end
	for _, d in g:GetDescendants() do if d.Name == name then return d end end
	return nil
end
local function firedOf(kind: string): { any }
	local out: { any } = {}
	for _, m in R.fired do if m.kind == kind then table.insert(out, m) end end
	return out
end
local function realWait(seconds: number)
	local t0 = os.clock()
	while os.clock() - t0 < seconds do end
end

-- a real rest from the same kind of world the client runs
local Motor = require("../src/Shared/Movement/SpiderMotor")
local Species = require("../src/Shared/Data/Species")
local Surfaces = require("../src/Shared/Data/Surfaces")
local PreyDirector = require("../src/Shared/Prey/PreyDirector")
local Sensor = require("../src/Shared/Perception/Sensor")
local ObservationMemory = require("../src/Shared/Perception/ObservationMemory")
local NeedsModel = require("../src/Shared/Life/NeedsModel")
local LifeLoop = require("../src/Shared/Life/LifeLoop")
local Checkpoint = require("../src/Shared/Persistence/Checkpoint")
local function storedRest(mode: string): any
	local motor = Motor.new({ world = workspace:FindFirstChild("Windowsill"), surfaces = Surfaces, profile = Species.phidippus_audax_prototype, spawn = Layout.SPAWN,
		heading = Layout.SPAWN_HEADING, boundsMin = Layout.PLAY_BOUNDS_MIN, boundsMax = Layout.PLAY_BOUNDS_MAX })
	local prey = PreyDirector.engine(workspace:FindFirstChild("Windowsill"), Species.fly_like_prototype, 914, 4)
	local memory = ObservationMemory.new()
	local sensor = Sensor.new(memory)
	sensor:configureFrom(Species.phidippus_audax_prototype.perception)
	local needs = NeedsModel.new(true, mode == "free")
	prey.feeding.needs = needs
	local life = LifeLoop.new(needs, function() return { ok = true, message = "" } end)
	if mode == "free" then life.mode, life.rules = "free", "gentle" end
	motor:place(Vector3.new(-25.5, Layout.SPAWN.Y, 6.0), Vector3.yAxis, Vector3.new(1, 0, 0))
	local w: any = { motor = motor, prey = prey, sensor = sensor, memory = memory, needs = needs, life = life }
	return assert(Checkpoint.capture(w, 0))
end

case("the real client waits for the server before the start menu: the world holds, hello goes up, then the saved state is applied", function()
	check(loadedOk, "SpiderClient loaded")
	local driver: any = ClientStubs.driver
	check(driver ~= nil, "the test hook is there")
	frames(20)
	local hellos = firedOf("hello")
	check(#hellos >= 1 and hellos[1].v == SaveRules.PROTOCOL, "hello went up on the first frames")
	check(driver.prey.tick == 0, `the world holds while it waits (tick {driver.prey.tick})`)
	check(not driver.menu:isShowing(), "and no menu yet")
	local rest = storedRest("main")
	local freeRest = storedRest("free")
	check(#SaveRest.check("main", rest) == 0 and #SaveRest.check("free", freeRest) == 0, "the scripted rests are good ones")
	local progress = SaveProgress.snapshot({ opened = { "bold_jumper", "venom", "a_page_a_newer_build_found" }, eye_seconds = 40 }, true, "maratus_volans_male", { LargeText = true, NotebookNotes = false })
	R.deliver({ kind = "loaded", v = 1, status = "saved", progress = progress, rests = { main = rest, free = freeRest } })
	frames(30)
	check(driver.prey.tick > 0, "the world runs once the server has spoken")
	check(driver.notebook:isOpen("bold_jumper") and driver.notebook:isOpen("venom") and not driver.notebook:isOpen("a_page_a_newer_build_found"), "the notebook has the pages it knows")
	check(driver.notebook.eyeSeconds == 40, "and the eye seconds")
	check(driver.session.finishedMain == true, "Easy is unlocked")
	check(driver.appearance() == "maratus_volans_male" and lp:GetAttribute("Appearance") == "maratus_volans_male", "the chosen spider is on")
	check(lp:GetAttribute("LargeText") == true and lp:GetAttribute("NotebookNotes") == false, "the toggles are set")
	check(driver.currentStore():loadBest().ok, "the main rest is in the store")
	driver.openMenu()
	local menuGui = gui:FindFirstChild("SpiderLifeMenu")
	check(menuGui ~= nil and find("SpiderLifeMenu", "Continue") ~= nil and find("SpiderLifeMenu", "Easy") ~= nil, "the menu offers Continue and Easy")
	check(find("SpiderLifeMenu", "Summary") ~= nil and string.find(find("SpiderLifeMenu", "Summary").Text, SaveText.SAVED, 1, true) ~= nil, "and says the notebook and rests are saved")
	driver.menu:hide()
end)

local jumpPage: string? = nil
case("the real client sends up what the player did, and only that: pages, the adult life, then a changed toggle", function()
	local driver: any = ClientStubs.driver
	frames(5)
	R.fired = {}
	driver.notebook:notice("jump")
	jumpPage = driver.notebook:newest()
	frames(3)
	local progress = firedOf("progress")
	check(#progress == 1, `one progress message ({#progress})`)
	local m = progress[1]
	if m then
		check(table.find(m.progress.notebook.opened, "bold_jumper") ~= nil and jumpPage ~= nil and table.find(m.progress.notebook.opened, jumpPage) ~= nil, "it carries the old pages and the new one")
		check(m.progress.finished_main == true, "and the adult life")
		check(m.progress.appearance == nil, "the spider is not sent: the player did not change it this visit")
		check(next(m.progress.settings) == nil, "no toggle is sent: the player did not change one this visit")
		local problems = SaveProgress.sanitize(m.progress)
		check(#problems == 0, "and the server would accept it")
	end
	realWait(SaveRules.CLIENT_PROGRESS_GAP + 0.1)
	lp:SetAttribute("ReducedMotion", true)
	frames(3)
	progress = firedOf("progress")
	check(#progress == 2 and progress[2].progress.settings.ReducedMotion == true and progress[2].progress.settings.LargeText == nil, "a toggle the player changed is sent, and only that one")
end)

case("a rest the real client captures goes up as a rest the server would accept, in its mode", function()
	local driver: any = ClientStubs.driver
	frames(60)
	R.fired = {}
	local r = driver.life.save()
	check(r.ok, "the checkpoint was kept: " .. tostring(r.message))
	realWait(SaveRules.CLIENT_PROGRESS_GAP * 2 + 0.1)
	frames(3)
	local rests = firedOf("rest")
	check(#rests == 1 and rests[1].mode == "main", "one main rest went up")
	if rests[1] then
		local problems = SaveRest.check("main", rests[1].record)
		check(#problems == 0, "and the server's check accepts what the real client captured: " .. table.concat(problems, "; "))
		check(canon(rests[1].record) == canon(driver.currentStore():loadBest().record), "it is the very checkpoint the client kept")
	end
end)

case("the real client says plainly when saving is off, and when it is back; the menu line follows", function()
	local driver: any = ClientStubs.driver
	R.deliver({ kind = "status", status = "session", reason = "other_session" })
	frames(3)
	local toast = find("SpiderPrompts", "Toast")
	check(toast ~= nil and string.find(toast.Text, "Saving is off", 1, true) ~= nil and string.find(toast.Text, "open somewhere else", 1, true) ~= nil, "a toast says it: " .. tostring(toast and toast.Text))
	driver.openMenu()
	local body = find("SpiderLifeMenu", "Summary")
	check(body ~= nil and string.find(body.Text, "Saving is off for this visit", 1, true) ~= nil, "the menu says so too")
	R.deliver({ kind = "status", status = "saving" })
	frames(3)
	check(string.find(find("SpiderPrompts", "Toast").Text, "Saving is back on", 1, true) ~= nil, "and when it is back")
	check(string.find(find("SpiderLifeMenu", "Summary").Text, "Saving...", 1, true) ~= nil, "the open menu's line was refreshed")
	R.deliver({ kind = "status", status = "saved" })
	frames(3)
	check(string.find(find("SpiderLifeMenu", "Summary").Text, SaveText.SAVED, 1, true) ~= nil, "saved")
	driver.menu:hide()
end)

case("the real client uses a later copy of the saved state, but never over what the player chose this visit", function()
	local driver: any = ClientStubs.driver
	-- the player chose a toggle: a later reply must not undo it
	lp:SetAttribute("LargeText", false)
	frames(3)
	R.deliver({ kind = "loaded", v = 1, status = "saved", progress = SaveProgress.snapshot({ opened = { "eight_eyes" }, eye_seconds = 1 }, false, "first_spider", { LargeText = true, SoundMuted = true }), rests = {} })
	frames(3)
	check(lp:GetAttribute("LargeText") == false, "the toggle the player changed is kept")
	check(lp:GetAttribute("SoundMuted") == true, "one they did not touch is taken from the save")
	check(driver.notebook:isOpen("eight_eyes") and driver.notebook:isOpen("bold_jumper") and jumpPage ~= nil and driver.notebook:isOpen(jumpPage), "pages only ever add")
	check(driver.session.finishedMain == true, "an adult life stays")
	check(driver.appearance() == "first_spider", "the spider the save names is used when the player has not chosen one")
	R.deliver({ kind = "loaded", v = 1, status = "saved", progress = SaveProgress.snapshot({ opened = { "eight_eyes" }, eye_seconds = 1 }, false, "myrmarachne_formicaria_female", {}), rests = {} })
	frames(3)
	check(driver.appearance() == "myrmarachne_formicaria_female" and lp:GetAttribute("Appearance") == "myrmarachne_formicaria_female" and workspace:FindFirstChild("Spider"):GetAttribute("AppearanceId") == "myrmarachne_formicaria_female", "a save that names the ant-mimicking spider puts it on")
	R.deliver({ kind = "loaded", v = 1, status = "saved", progress = SaveProgress.snapshot({ opened = { "eight_eyes" }, eye_seconds = 1 }, false, "first_spider", {}), rests = {} })
	frames(3)
	check(driver.appearance() == "first_spider", "and a later save that names the first spider puts that back")
	-- junk from the server changes nothing
	local pages = #driver.notebook.opened
	for _, junk in { "x", { kind = "loaded", progress = "nope", rests = 5 }, { kind = "loaded", progress = { notebook = { opened = { "../x" } } } }, { kind = "rest", mode = "main", record = { not_a_rest = true } } } do
		local ok = pcall(R.deliver, junk)
		check(ok, "junk from the server does not raise")
	end
	frames(3)
	check(#driver.notebook.opened == pages, "and changes nothing")
	-- a rest sent late is only taken when the visit has none and has not begun
	local before = driver.currentStore():loadBest().ok
	R.deliver({ kind = "rest", mode = "main", record = storedRest("main") })
	frames(1)
	check(before and driver.currentStore():loadBest().ok, "a visit that already has a rest keeps it")
end)

case("settings (ROBLOX-49): saved numbers and choices are applied as Player attributes; the player's own change this visit wins and is what goes up", function()
	R.fired = {}
	local settingsOf = SaveProgress.snapshot({ opened = { "eight_eyes" }, eye_seconds = 1 }, false, nil, { MasterVolume = 0.3, Captions = "large", FieldOfView = 70, InvertY = true })
	realWait(SaveRules.CLIENT_PROGRESS_GAP + 0.1)
	lp:SetAttribute("MasterVolume", 0.7) -- the player moved the slider before the late reply
	frames(3)
	R.deliver({ kind = "loaded", v = 1, status = "saved", progress = settingsOf, rests = {} })
	frames(3)
	check(lp:GetAttribute("MasterVolume") == 0.7, "a slider the player moved is kept")
	check(lp:GetAttribute("Captions") == "large" and lp:GetAttribute("FieldOfView") == 70 and lp:GetAttribute("InvertY") == true, "the others come from the save, with their own types")
	local bad = Json.copy(settingsOf)
	bad.settings = { Captions = "tiny", LookSensitivityMouse = 400, NotASetting = 1 }
	R.deliver({ kind = "loaded", v = 1, status = "saved", progress = bad, rests = {} })
	frames(3)
	check(lp:GetAttribute("Captions") == "large" and lp:GetAttribute("NotASetting") == nil, "an unknown option or id from the server is not applied")
	check(lp:GetAttribute("LookSensitivityMouse") == 3.0, "a number out of its range is clamped, not trusted")
	realWait(SaveRules.CLIENT_PROGRESS_GAP + 0.1)
	lp:SetAttribute("CameraDistance", 6.2)
	frames(3)
	local progress = firedOf("progress")
	local last = progress[#progress]
	check(last ~= nil and last.progress.settings.MasterVolume == 0.7 and last.progress.settings.CameraDistance == 6.2, "what the player changed goes up, as numbers")
	check(last ~= nil and #SaveProgress.sanitize(last.progress) == 0, "and the server would accept it")
	lp:SetAttribute("Captions", "tiny") -- junk written into the attribute by something else is never sent
	realWait(SaveRules.CLIENT_PROGRESS_GAP + 0.1)
	lp:SetAttribute("InvertX", true)
	frames(3)
	progress = firedOf("progress")
	last = progress[#progress]
	check(last ~= nil and last.progress.settings.Captions == nil and last.progress.settings.InvertX == true, "an unclean value is left out of what is sent")
end)

print(`STATE_CLIENT passed={passed} failed={failed}`)
