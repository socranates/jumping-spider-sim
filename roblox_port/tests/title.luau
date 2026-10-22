-- The first minute (ROBLOX-109): the splash (First/SplashScreen) and every way it ends, the drift and the intro's shots (Movement/TitleShots), the words
-- (UI/TitleText), the two looks of CaughtPanel, the progress record's intro_seen, and through the real client in a place that is not the test place: the
-- title card over the drift with the music rising, the menu's choices and a controller's keys, the intro of a new life (its walk out of the crack, its
-- captions, its skip refused and taken, its ease into the game's camera, Reduced Motion's cuts, a screen over it), and that it is never shown twice.
-- Run with the other suites:  python3 tests/run.py path/to/luau title.luau
-- Not evidence of the engine: the typeface, the look on a screen, streaming, ReplicatedFirst's ordering and RenderStepped are Studio's to show.
local Layout = require("../src/Shared/Habitat/WindowsillLayout")
local WorldMap = require("../src/Shared/World/WorldMap")
local Region = require("../src/Shared/World/Region")
local TitleText = require("../src/Shared/UI/TitleText")
local TitleShots = require("../src/Shared/Movement/TitleShots")
local ControlText = require("../src/Shared/UI/ControlText")
local SaveProgress = require("../src/Shared/Persistence/SaveProgress")
local SplashScreen = require("../src/First/SplashScreen")
local CaughtPanel = require("../src/Client/CaughtPanel")
local SaveClient = require("../src/Client/SaveClient")
local SelfTest = require("../src/Client/SelfTest")
local passed, failed = 0, 0
local function check(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then passed += 1 else failed += 1; print("FAIL title: " .. name .. "\n    " .. tostring(err)) end
end
local function near(a: number, b: number, eps: number): boolean return math.abs(a - b) <= eps end

-- ---------------------------------------------------------------- the words
check("the words: the title, its line, the choices on the title card and in a life, a controller's line in its own names, the skip, the captions", function()
	assert(TitleText.TITLE == "The Windowsill" and TitleText.SUBTITLE == "A small life in a city's nature preserve.", "the title and its line")
	assert(TitleText.titleSize(1920) == 58 and TitleText.titleSize(360) == 36 and TitleText.titleSize(200) == 30, "the title's size by the screen's width")
	assert(TitleText.choice("Continue", false) == "Continue" and TitleText.choice("Continue", true) == "Continue from last rest", "Continue, short on the title card")
	assert(TitleText.choice("New", false) == "Begin a new life" and TitleText.choice("Free", false) == "Free play - gentle rules", "a new life and Free play")
	assert(TitleText.choice("Resume", true) == "Resume this spider", "Resume in a life")
	ControlText.setPadStyle("playstation")
	assert(TitleText.navHint("gamepad") == "D-pad: move    Cross: choose    Circle: back", TitleText.navHint("gamepad"))
	assert(TitleText.skipHint("gamepad") == "Cross: skip", TitleText.skipHint("gamepad"))
	ControlText.setPadStyle("xbox")
	assert(TitleText.navHint("gamepad") == "D-pad: move    A: choose    B: back" and TitleText.skipHint("gamepad") == "A: skip", "Xbox names")
	assert(TitleText.navHint("keyboard") == "" and TitleText.navHint("touch") == "", "no line for keys or touch")
	assert(TitleText.skipHint("keyboard") == "Space: skip" and TitleText.skipHint("touch") == "Tap to skip", "the skip's words")
	for _, gentle in { false, true } do
		local lines = TitleText.captions(gentle)
		assert(#lines == 3, "three captions")
		for _, line in lines do assert(#line <= 72, "a caption is short: " .. line) end
	end
	assert(TitleText.captions(false)[3] == "It has not eaten. It must eat today." and TitleText.captions(true)[3] ~= TitleText.captions(false)[3], "the day's need, by the rules")
end)

-- ---------------------------------------------------------------- the shots
local function insideAny(p: Vector3, boxes: { any }): string?
	for _, b in boxes do
		if p.X > b.lo.X and p.X < b.hi.X and p.Y > b.lo.Y and p.Y < b.hi.Y and p.Z > b.lo.Z and p.Z < b.hi.Z then return b.id or b.name or "a box" end
	end
	return nil
end
local allBoxes: { any } = {}
for _, region in WorldMap.regions() do for _, piece in Region.pieces(region) do table.insert(allBoxes, piece) end end

check("the drift: it starts over the lawn, arrives in front of the window at DRIFT_S and breathes there, never jumps and never enters a box of the world", function()
	local keys = TitleShots.DRIFT
	assert(#keys == 3 and keys[#keys].t == TitleShots.DRIFT_S, "three keys, the last at DRIFT_S")
	local cf0 = TitleShots.drift(0, "test_garden")
	assert((cf0.Position - keys[1].eye).Magnitude < 1e-6, "it starts at the first key")
	local cfA = TitleShots.drift(TitleShots.DRIFT_S, "test_garden")
	assert((cfA.Position - keys[3].eye).Magnitude < 1e-6, "it arrives at the last")
	local prev = cf0.Position
	local worst = 0
	local t = 0
	while t <= 240 do
		local cf, fov = TitleShots.drift(t, "test_garden")
		local p = cf.Position
		worst = math.max(worst, (p - prev).Magnitude)
		prev = p
		assert(fov >= 40 and fov <= 60, "a field of view in range")
		local inside = insideAny(p, allBoxes)
		assert(inside == nil, `the drift is inside {inside} at {t} s`)
		if t > TitleShots.DRIFT_S then
			assert((p - keys[3].eye).Magnitude <= 1.8, `the sway stays within a stud or two ({(p - keys[3].eye).Magnitude})`)
			assert((cf.LookVector - (keys[3].at - p).Unit).Magnitude < 1e-6, "and keeps looking at the window")
		end
		t += 0.05
	end
	assert(worst < 0.6, `never more than 0.6 studs in a twentieth of a second ({worst})`) -- (12 studs, 12 cm, a second at most: a slow drift over a garden of metres)
	assert((TitleShots.drift(-5, "test_garden").Position - keys[1].eye).Magnitude < 1e-6, "a time before the start is the start")
end)

check("the intro's timing: skippable after 2 s, shots one after another to the end, captions in order and apart, the last over the game, the walk", function()
	local I = TitleShots.INTRO
	assert(I.skipAfter == 2 and I.total == I.blend.t1 and I.captionsEnd > I.total, "skip at 2 s; the last caption outlives the intro")
	local last = 0
	for _, s in I.shots do assert(s.t0 == last and s.t1 > s.t0, "the shots follow one another"); last = s.t1 end
	assert(last >= I.blend.t0, "the last shot runs into the ease")
	local prevEnd = 0
	for i, c in I.captions do
		assert(c.t0 >= prevEnd and c.t1 - c.t0 >= 3, `caption {i} after the one before and long enough to read`)
		prevEnd = c.t1
	end
	assert(I.captions[1].t0 >= I.shots[1].t1, "nothing is said over the first shot")
	assert(I.walk.from >= I.shots[2].t1 and I.walk.untilX > Layout.RETREAT_MAX.X and I.start.pos.X < Layout.RETREAT_MAX.X and I.start.pos.X > Layout.RETREAT_MIN.X, "the spider starts inside the crack and walks out of it")
	local f0 = TitleShots.intro(0, false, nil)
	assert(f0.veil == 1 and f0.holding and not f0.done and f0.caption == nil and f0.blend == 0, "it begins from black, holding, silent")
	assert(TitleShots.intro(I.fadeIn, false, nil).veil == 0, "and fades in")
	assert(TitleShots.intro(5, false, nil).caption == 1 and TitleShots.intro(9, false, nil).caption == 2 and TitleShots.intro(13, false, nil).caption == 3, "the captions by the clock")
	local mid = TitleShots.intro(I.blend.t0 + 0.7, false, nil)
	assert(mid.blend > 0 and mid.blend < 1, "the ease into the game's camera")
	local fend = TitleShots.intro(I.total, false, nil)
	assert(not fend.holding and fend.blend == 1 and not fend.done, "at the end the controls are back; the last caption goes on")
	assert(TitleShots.intro(I.captionsEnd, false, nil).done, "then it is done")
	assert(TitleShots.intro(I.walk.from, false, nil).walking and not TitleShots.intro(I.walk.from - 0.1, false, nil).walking, "the walk's start")
end)

check("the intro's camera: each shot moves smoothly and stays out of the sill's boxes; it follows the spider out; Reduced Motion holds each shot still and cuts", function()
	local I = TitleShots.INTRO
	local prev: Vector3? = nil
	local prevShot = ""
	local t = 0
	while t < I.blend.t0 do
		local f = TitleShots.intro(t, false, nil)
		local p = f.cframe.Position
		if f.shot ~= prevShot then prev = nil; prevShot = f.shot end -- (a cut between shots)
		local inside = insideAny(p, Layout.PIECES)
		assert(inside == nil, `the camera is inside {inside} at {t} s`)
		if prev ~= nil then assert((p - prev).Magnitude < 0.35, `a jump at {t} s inside a shot ({(p - prev).Magnitude})`) end
		prev = p
		t += 1 / 60
	end
	local spider = Vector3.new(-22.3, 0.31, 6.0)
	local out = TitleShots.intro(9.0, false, spider)
	assert(out.shot == "out" and (out.cframe.LookVector - (spider + Vector3.new(0, 0.2, 0) - out.cframe.Position).Unit).Magnitude < 1e-6, "the out shot looks at the spider")
	for _, s in I.shots do
		local a = TitleShots.intro(s.t0 + 0.05, true, nil).cframe.Position
		local b = TitleShots.intro(s.t1 - 0.05, true, nil).cframe.Position
		assert((a - b).Magnitude < 1e-9, `Reduced Motion: {s.name} is held still`)
	end
	assert(TitleShots.intro(I.blend.t1 - 0.01, true, nil).blend == 0 and TitleShots.intro(I.blend.t1, true, nil).blend == 1, "and the ease into the game is a cut")
	local views = TitleShots.views()
	assert(#views == 6 and views[1].name == "title_drift_0" and views[6].name == "intro_out", "six frames for the previewer")
end)

-- ---------------------------------------------------------------- the splash
local Fake = {}
-- This local host implements disconnect/destroy notifications explicitly; the
-- broad CLI shim's signals intentionally do not model those engine semantics.
local function trackedSignal()
 local signal={handlers={}}
 function signal:Connect(fn)
  local entry={fn=fn,active=true};table.insert(self.handlers,entry)
  return {Disconnect=function() entry.active=false end}
 end
 function signal:Fire(...) for _,entry in table.clone(self.handlers) do if entry.active then entry.fn(...) end end end
 function signal:live() local n=0;for _,entry in self.handlers do if entry.active then n+=1 end end;return n end
 return signal
end
-- A host for SplashScreen.run: `frames` is how many frames have passed; `wordsAt`, `loadedAt`, `readyAt` the frames those happen at (nil: never).
local function host(o: any): any
	local playerGui = Instance.new("Folder")
	playerGui.Name = "PlayerGui"
	local player = Instance.new("Player")
	playerGui.Parent = player
 local readySignal=trackedSignal()
 if o.readyConnectRaises then readySignal.Connect=function() error("player subscription failed") end end
 rawset(player,"_attr_"..SplashScreen.READY_ATTRIBUTE,readySignal)
 local getSignal=player.GetAttributeChangedSignal
 rawset(player,"GetAttributeChangedSignal",function(self,name)
  if name==SplashScreen.READY_ATTRIBUTE then return readySignal end
  return getSignal(self,name)
 end)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 70
	local ws = { CurrentCamera = camera }
	local h = { frames = 0, removed = false, warned = {}, playerGui = playerGui, player = player, camera = camera, writes = 0, writesAfterReady = 0, guiSeen = false }
	h.service = function(name: string): any
		if o.breakService == name then error("no " .. name) end
		if name == "ReplicatedFirst" then return { RemoveDefaultLoadingScreen = function() h.removed = true end } end
		if name == "Players" then return { LocalPlayer = player } end
		if name == "Workspace" then return ws end
		return nil
	end
 h.readySignal=readySignal
 h.deferred={};h.destroyCalls=0
 h.flushDestroying=function() local q=h.deferred;h.deferred={};for _,fn in q do fn() end end
 h.frame = function(): number
  h.frames += 1
  local screen=playerGui:FindFirstChild(SplashScreen.GUI_NAME)
  if screen and not rawget(screen,"_startupSignals") then
   rawset(screen,"_startupSignals",true)
   local dying=trackedSignal();rawset(screen,"Destroying",dying);h.dyingSignal=dying
   local destroy=screen.Destroy
   rawset(screen,"Destroy",function(self)
    h.destroyCalls+=1
    if o.deferredDestroy then table.insert(h.deferred,function() dying:Fire() end) else dying:Fire() end
    destroy(self)
   end)
  end
  if o.failedAt and h.frames==o.failedAt then player:SetAttribute("WorldStartupFailed",true) end
		if o.readyAt ~= nil and h.frames == o.readyAt then player:SetAttribute(SplashScreen.READY_ATTRIBUTE, true) end
		if playerGui:FindFirstChild(SplashScreen.GUI_NAME) then h.guiSeen = true end
		if o.raiseAt ~= nil and h.frames == o.raiseAt then error("a fault in a frame") end
		assert(h.frames < 60 * 600, "the splash never ended")
		return 1 / 60
	end
	h.now = function(): number return h.frames / 60 end
	h.loaded = function(): boolean return o.loadedAt ~= nil and h.frames >= o.loadedAt end
	h.warn = function(text: string) table.insert(h.warned, text) end
	h.find = function(): (any, any)
		if o.findRaises then error("lookup failed") end
		if o.wordsAt ~= nil and h.frames >= o.wordsAt then return TitleText, TitleShots end
		return nil, nil
	end
	-- (the camera's writes, counted; after the title card is ready none should come from the splash)
	local cf = camera.CFrame
	setmetatable(ws, { __index = function() return nil end })
	local proxy = setmetatable({}, {
		__index = function(_, k) if k == "CFrame" then return cf end return (camera :: any)[k] end,
		__newindex = function(_, k, v)
			if o.cameraRaises then error("the camera refused") end
			if k == "CFrame" then
				cf = v; h.writes += 1
				if player:GetAttribute(SplashScreen.READY_ATTRIBUTE) == true then h.writesAfterReady += 1 end
			end
			(camera :: any)[k] = v
		end,
	})
	ws.CurrentCamera = proxy
	h.cf = function() return cf end
	return h
end
Fake.host = host

local realHost = SplashScreen.host
check("the splash: the default screen removed, the words up, the drift on the camera, gone over the title card when it is ready (and never touching the camera after)", function()
	local h = host({ wordsAt = 10, loadedAt = 60, readyAt = 600 })
	SplashScreen.host = h
	local why = SplashScreen.run()
	SplashScreen.host = realHost
	assert(why == "ready", why)
	assert(h.removed, "Roblox's loading screen was not removed")
	assert(h.guiSeen and h.playerGui:FindFirstChild(SplashScreen.GUI_NAME) == nil, "its screen was there, and is gone")
	assert(h.writes > 500 and h.writesAfterReady == 0, `the camera: {h.writes} writes, {h.writesAfterReady} after the title card was ready`)
	local want = TitleShots.drift(599 / 60)
	assert((h.cf().Position - want.Position).Magnitude < 1e-6, "the last write was the drift at the clock")
	assert(h.camera.CameraType == Enum.CameraType.Scriptable, "a scripted camera")
	assert(h.frames >= 600 + math.floor(SplashScreen.FADE_S * 60) and h.frames <= 600 + math.floor(SplashScreen.FADE_S * 60) + 3, `it faded over FADE_S ({h.frames} frames)`)
	assert(#h.warned == 0, "nothing warned")
end)

check("the splash's fallbacks: no words (a dark field, no camera), no title card (gone at READY_WAIT_S), a lookup that raises, a fault in a frame, no Players", function()
	local h = host({ loadedAt = 1, readyAt = 120 })
	SplashScreen.host = h
	assert(SplashScreen.run() == "ready" and h.writes == 0, "without the words or the drift: no camera, and it still ends")
	h = host({ wordsAt = 1, loadedAt = 1 })
	SplashScreen.host = h
	local why = SplashScreen.run()
	assert(why == "timeout" and h.frames >= SplashScreen.READY_WAIT_S * 60 and h.frames <= (SplashScreen.READY_WAIT_S + SplashScreen.FADE_S) * 60 + 3, `no title card: {why} after {h.frames} frames`)
	assert(h.playerGui:FindFirstChild(SplashScreen.GUI_NAME) ~= nil, "an unfinished client keeps a visible explanation")
	h = host({ findRaises = true, loadedAt = 1, readyAt = 90 })
	SplashScreen.host = h
	assert(SplashScreen.run() == "ready", "a lookup that raises is only no words")
	h = host({ wordsAt = 1, loadedAt = 1, readyAt = 900, raiseAt = 200 })
	SplashScreen.host = h
	why = SplashScreen.run()
	assert(string.find(why, "failed", 1, true) == 1 and h.frames == 200 and h.playerGui:FindFirstChild(SplashScreen.GUI_NAME) ~= nil and #h.warned == 1, `a fault: {why}, its screen gone, one warning`)
	h = host({ wordsAt = 1, loadedAt = 1, readyAt = 900, cameraRaises = true })
	SplashScreen.host = h
	why = SplashScreen.run()
	assert(string.find(why, "failed", 1, true) == 1 and h.playerGui:FindFirstChild(SplashScreen.GUI_NAME) ~= nil, "a camera that refuses retains an explanation")
	h = host({ breakService = "Players" })
	SplashScreen.host = h
	why = SplashScreen.run()
	assert(string.find(why, "failed", 1, true) == 1 and h.frames == 0 and not h.removed, "no Players: failed at once without removing the default loading screen")
	SplashScreen.host = realHost
end)

check("a startup world failure is visible before the ordinary splash timeout",function()
 local h=host({wordsAt=1,loadedAt=1,failedAt=15});SplashScreen.host=h
 local why=SplashScreen.run();SplashScreen.host=realHost
 assert(why=="world" and h.frames<60*SplashScreen.READY_WAIT_S,"explicit failed world does not masquerade as a ready title")
 local ui=h.playerGui:FindFirstChild(SplashScreen.GUI_NAME)
 assert(ui and string.find(ui:FindFirstChild("Subtitle").Text,"rejoin",1,true),"failure explains recovery")
 assert(ui:FindFirstChild("Veil").BackgroundTransparency<.5,"unready world is covered")
 ui:Destroy()
end)
check("timeout without Shared words retains a self-contained error then clears on late readiness",function()
 local h=host({loadedAt=1});SplashScreen.host=h
 assert(SplashScreen.run()=="timeout","startup is bounded even if Shared never arrives");SplashScreen.host=realHost
 local ui=h.playerGui:FindFirstChild(SplashScreen.GUI_NAME)
 assert(ui and ui:FindFirstChild("Subtitle").Text~="","missing text modules cannot erase failure explanation")
 local cameraWrites=h.writes
 h.player:SetAttribute(SplashScreen.READY_ATTRIBUTE,true)
 assert(h.playerGui:FindFirstChild(SplashScreen.GUI_NAME)==nil,"a delayed healthy client dismisses the stale error")
 assert(h.readySignal:live()==0 and h.dyingSignal:live()==0,"late readiness releases all temporary listeners")
 h.player:SetAttribute(SplashScreen.READY_ATTRIBUTE,false);h.player:SetAttribute(SplashScreen.READY_ATTRIBUTE,true)
 assert(h.writes==cameraWrites,"closed splash does not resume camera writes")
end)
check("external failure-screen destruction disconnects its player listener",function()
 local h=host({wordsAt=1,loadedAt=1});SplashScreen.host=h;SplashScreen.run();SplashScreen.host=realHost
 local ui=h.playerGui:FindFirstChild(SplashScreen.GUI_NAME);assert(ui,"failure screen remains owned by PlayerGui")
 ui:Destroy()
 assert(h.readySignal:live()==0 and h.dyingSignal:live()==0,"destroying the error screen retains no active listener")
end)

check("deferred destruction and a queued ready signal cannot retain or destroy the error screen twice",function()
 for _,readyFirst in {false,true} do
  local h=host({wordsAt=1,loadedAt=1,deferredDestroy=true});SplashScreen.host=h
  SplashScreen.run();SplashScreen.host=realHost
  local ui=h.playerGui:FindFirstChild(SplashScreen.GUI_NAME);assert(ui,"unready screen retained")
  ui:Destroy()
  if readyFirst then h.player:SetAttribute(SplashScreen.READY_ATTRIBUTE,true) end
  h.flushDestroying()
  assert(h.destroyCalls==1,"ready after external destroy does not destroy again")
  assert(h.readySignal:live()==0 and h.dyingSignal:live()==0,"deferred cleanup releases both listeners")
 end
end)

check("a failed readiness subscription cleans its owner connection and reports the fallback failure",function()
 local h=host({wordsAt=1,loadedAt=1,readyConnectRaises=true});SplashScreen.host=h
 SplashScreen.run();SplashScreen.host=realHost
 assert(h.playerGui:FindFirstChild(SplashScreen.GUI_NAME)==nil,"unusable recovery UI is disposed")
 assert(h.readySignal:live()==0 and h.dyingSignal:live()==0,"partially installed recovery retains no listener")
 assert(#h.warned==1 and string.find(h.warned[1],"subscription failed",1,true),"recovery error is not swallowed")
end)

check("the splash's look: black until the world has loaded, then the veil's rest; the title comes up; the dot only on a long wait; the going fades both", function()
	local s = SplashScreen.newState()
	local waiting = { loaded = false, ready = false, words = true }
	for _ = 1, 60 do SplashScreen.step(s, 1 / 60, waiting) end
	local l = SplashScreen.look(s, waiting)
	assert(l.veil == 1 and l.dot == 0 and l.title > 0 and l.drive, "a second in: black, words coming, no dot")
	for _ = 1, 4 * 60 do SplashScreen.step(s, 1 / 60, waiting) end
	l = SplashScreen.look(s, waiting)
	assert(l.veil == 1 and l.dot > 0 and l.title == 1, "five seconds in, still loading: the dot")
	local loaded = { loaded = true, ready = false, words = true }
	for _ = 1, math.ceil(SplashScreen.REVEAL_S * 60) + 1 do SplashScreen.step(s, 1 / 60, loaded) end
	l = SplashScreen.look(s, loaded)
	assert(near(l.veil, SplashScreen.VEIL_REST, 1e-9), `loaded: the veil at its rest ({l.veil})`)
	local ready = { loaded = true, ready = true, words = true }
	SplashScreen.step(s, 1 / 60, ready)
	l = SplashScreen.look(s, ready)
	assert(s.phase == "leaving" and s.why == "ready" and l.dot == 0 and not l.drive, "ready: leaving, no dot, the camera is the title card's")
	local lastVeil, lastTitle = l.veil, l.title
	for _ = 1, math.ceil(SplashScreen.FADE_S * 60) + 1 do
		SplashScreen.step(s, 1 / 60, ready)
		l = SplashScreen.look(s, ready)
		assert(l.veil <= lastVeil + 1e-12 and l.title <= lastTitle + 1e-12, "the going only fades")
		lastVeil, lastTitle = l.veil, l.title
	end
	assert(s.phase == "done" and l.veil == 0 and l.title == 0, "and ends clear")
	local late = SplashScreen.newState()
	for _ = 1, math.ceil(SplashScreen.LOADED_WAIT_S * 60) + 2 do SplashScreen.step(late, 1 / 60, waiting) end
	assert(late.loadedT ~= nil, "a game that never says it has loaded is shown anyway at LOADED_WAIT_S")
end)

-- ---------------------------------------------------------------- the two looks
check("CaughtPanel's looks: the title card (light veil, the title sized to the screen, the summary and the controller's line under the choices, B for back) and the card", function()
	local gui = Instance.new("Folder")
	local chosen: { string } = {}
	local p = CaughtPanel.new(gui, function(id: string) table.insert(chosen, id) end, "LookTest")
	p:setLook("title")
	p:showChoices("The Windowsill", "A small life on a windowsill.", "Saving is off.", { { id = "New", text = "Begin a new life" }, { id = "Free", text = "Free play - gentle rules" } }, true, nil)
	p:setHint(TitleText.navHint("gamepad"))
	assert(p.line.TextSize == TitleText.titleSize(1280) and p.line.FontFace.Family == TitleText.FAMILY and p.line.FontFace.Weight == Enum.FontWeight.Light, "the title: its size and face")
	assert(p.sub.FontFace.Style == Enum.FontStyle.Italic and p.summary.LayoutOrder > 3 + 2 and p.summary.TextSize == 14, "the line in italic; the summary small, under the choices")
	assert(p.hint.Visible and p.hint.Text ~= "" and p.hint.LayoutOrder > p.summary.LayoutOrder, "a controller's line under it")
	assert(p.shade.Enabled and p.dim.BackgroundTransparency == 0, "the veil: the gradient over a ground")
	local b = p.gui:FindFirstChild("Dim"):FindFirstChild("Box"):FindFirstChild("New")
	assert(b ~= nil and b.FontFace.Family == TitleText.FAMILY and b.BackgroundTransparency > 0, "the choices in the face, on a dark ground")
	local fn = ClientStubs.actions[p.action]
	fn("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.ButtonB })
	assert(#chosen == 0 and p:isShowing(), "B does nothing where there is no back")
	p:showChoices("Begin a new life?", "", "", { { id = "New", text = "Begin the new life" }, { id = "CancelNew", text = "Keep this life" } }, true, "CancelNew")
	fn("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.ButtonB })
	assert(chosen[1] == "CancelNew", "B chooses the back choice")
	p:hide()
	p:setLook("card")
	p:showChoices("The spider starved.", "It went too long without food.", "summary", { { id = "Back", text = "Back" } }, false)
	assert(not p.shade.Enabled and p.dim.BackgroundTransparency == 1 and p.line.TextSize == 28 and p.summary.LayoutOrder == 3, "the card: dims up from clear, its sizes, the summary before the choices")
	assert(p.line.FontFace.Family == TitleText.FAMILY and p.line.FontFace.Weight == Enum.FontWeight.Regular, "in the same face")
	p:setTextScale(1.5)
	assert(p.line.TextSize == 42, "large text")
	p:hide()
end)

check("the progress record's intro_seen: optional, true or absent, kept by a merge, said by the snapshot; a record without it is not seen", function()
	local base = SaveProgress.default()
	assert(base.intro_seen == nil, "absent by default")
	local raw = { notebook = { opened = {}, eye_seconds = 0 }, finished_main = false, intro_seen = true }
	local problems, clean = SaveProgress.sanitize(raw)
	assert(#problems == 0 and clean ~= nil and clean.intro_seen == true, "kept when true")
	raw.intro_seen = false
	problems, clean = SaveProgress.sanitize(raw)
	assert(#problems == 0 and clean ~= nil and clean.intro_seen == nil, "absent when false")
	raw.intro_seen = "yes"
	problems, clean = SaveProgress.sanitize(raw)
	assert(#problems == 1 and clean == nil, "refused when not a boolean")
	local seen = SaveProgress.snapshot({ opened = {} }, false, nil, {}, true)
	local unseen = SaveProgress.snapshot({ opened = {} }, false, nil, {})
	assert(seen.intro_seen == true and unseen.intro_seen == nil, "the snapshot says it")
	assert(SaveProgress.merge(unseen, seen, 2, 1).intro_seen == true and SaveProgress.merge(seen, unseen, 1, 2).intro_seen == true, "a merge keeps it, whichever is newer")
	assert(not SaveProgress.same(seen, unseen) and SaveProgress.same(seen, SaveProgress.snapshot({ opened = {} }, false, nil, {}, true)), "and a change in it is a change")
end)

-- ---------------------------------------------------------------- the real client, not the test place
local transportNow = 0
local originalNew = SaveClient.new
SaveClient.new = function(cfg: any): any
	local testConfig = table.clone(cfg)
	testConfig.now = function() return transportNow end
	return originalNew(testConfig)
end
local pieces = {}
for _, p in Layout.PIECES do table.insert(pieces, { name = p.id, lo = p.lo, hi = p.hi, profile = p.profile }) end
BoxWorld.folder("Windowsill", pieces)
local hook = ClientStubs.scriptFolder:FindFirstChild("SilkPlayback")
if hook then hook:Destroy() end -- not the test place: the start menu opens by itself and the title card has the camera
local ctx: any = nil
SelfTest.start = function(hooks: any): boolean ctx = hooks; return true end -- (the hooks, by the self-test's door; nothing of the self-test runs)
workspace:SetAttribute("SelfTest", true)
local loaded, loadError = pcall(function() require("../src/Client/SpiderClient.client") end)
if not loaded then print("LOAD ERROR", loadError) end
local frame = ClientStubs.renderSteps.SpiderSim
local player = game:GetService("Players").LocalPlayer
local gui = player:FindFirstChild("PlayerGui")
local camera = workspace.CurrentCamera
local function frames(n: number) for _ = 1, n do frame(1 / 60) end end
local function find(screen: string, name: string): any
	local g = gui:FindFirstChild(screen)
	if not g then return nil end
	for _, d in g:GetDescendants() do if d.Name == name then return d end end
	return nil
end

check("the title card: the client sets TitleReady when its start menu opens, the menu in the title look, the camera on the drift, the music rising under it", function()
	assert(loaded and ctx ~= nil, "the client did not load: " .. tostring(loadError))
	frames(30)
	assert(not ctx.menu:isShowing() and player:GetAttribute("TitleReady") ~= true, "the menu waits a moment for a server")
	local snd = ctx.soundscape
	assert(snd.title == true and snd.rise < 0.1, `the music is asked under the title, from silence ({snd.rise})`)
	transportNow = 1.7
	frames(30)
	assert(ctx.menu:isShowing() and player:GetAttribute("TitleReady") == true, "the start menu is open and the splash told")
	assert(ctx.menu.look == "title" and find("SpiderLifeMenu", "Line").Text == "The Windowsill", "the title card")
	local ids = {}
	for _, c in ctx.menu.choices do table.insert(ids, c.id) end
	assert(table.concat(ids, ",") == "New,Free,Settings", "the choices: " .. table.concat(ids, ","))
	assert(find("SpiderLifeMenu", "New").Text == "Begin a new life", "in the title card's words")
	local before = os.clock()
	frames(1)
	local after = os.clock()
	local p = camera.CFrame.Position
	local a, b = TitleShots.drift(before, "test_garden").Position, TitleShots.drift(after, "test_garden").Position
	assert((p - a).Magnitude <= (b - a).Magnitude + 0.01, "the camera is on the drift at the game's clock")
	assert(snd.rise > 0 and snd.rise < 1 and snd.music ~= nil and snd.music.Playing, `the music plays under the menu, rising ({snd.rise})`)
	ctx.setDevice("gamepad")
	ctx.openMenu()
	assert(find("SpiderLifeMenu", "Hint").Visible and string.find(find("SpiderLifeMenu", "Hint").Text, "choose", 1, true) ~= nil, "a controller's line")
	local fn = ClientStubs.actions["WindowsillChoiceSpiderLifeMenu"]
	fn("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.DPadDown })
	assert(ctx.menu.selected == 2, "the D-pad moves")
	fn("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.ButtonB })
	assert(ctx.menu:isShowing() and not ctx.session.started, "B on the title card goes nowhere")
	ctx.setDevice("keyboard")
end)

check("the intro of a new life: chosen from the title card, the spider in the crack, the controls and the camera the intro's, the skip refused, then taken", function()
	assert(ctx.menu:choose("New"), "Begin a new life")
	local title = ctx.title
	assert(ctx.session.started and title:holding() and title.seen, "the intro holds, and is seen")
	local start = TitleShots.INTRO.start.pos
	assert((ctx.motor.pos - start).Magnitude < 0.1, `the spider in the crack ({ctx.motor.pos})`)
	assert(not ctx.hud.safe.Enabled, "the HUD is hidden")
	assert(gui:FindFirstChild("WindowsillIntro").Enabled, "the intro's screen")
	frames(60)
	local skip = ClientStubs.actions[title.ACTION or "WindowsillIntroSkip"]
	assert(skip ~= nil, "the skip is bound")
	skip("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.Space })
	assert(title:holding(), "refused at one second")
	local at = camera.CFrame.Position
	local f = TitleShots.intro(title.intro.t, false, ctx.motor.pos)
	assert((at - f.cframe.Position).Magnitude < 0.05, "the camera is the intro's")
	frames(66)
	assert(find("WindowsillIntro", "Skip").TextTransparency < 1 and find("WindowsillIntro", "Skip").Text == "Space: skip", "the skip's words, once it can")
	skip("", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.Space })
	assert(not title:holding() and not title:playing(), "taken after two seconds")
	assert(ctx.motor.pos.X >= TitleShots.INTRO.walk.untilX - 0.01, "the spider is put where its walk ends")
	assert(ctx.hud.safe.Enabled and ClientStubs.actions["WindowsillIntroSkip"] == nil, "the HUD is back and the skip unbound")
	assert(find("WindowsillIntro", "Veil").BackgroundTransparency < 0.01, "the game comes up from black")
	frames(40)
	assert(not gui:FindFirstChild("WindowsillIntro").Enabled, "and the intro's screen is gone")
	assert(ctx.soundscape.title == false, "the title card's music is over (the game's own plays)")
end)

check("never twice in a save: another new life from the life menu has no intro", function()
	ctx.openMenu()
	assert(ctx.menu.look == "card" and ctx.menu.choices[1].id == "Resume", "in a life the menu is the card, Resume first")
	assert(ctx.menu:choose("New") and ctx.menu:isShowing(), "the confirmation")
	assert(ctx.menu:choose("New"), "the new life")
	frames(3)
	assert(ctx.session.started and not ctx.title:playing(), "no intro")
end)

check("the intro played through: the walk out of the crack, the captions in turn, the ease into the game's camera, the controls back, the last caption over the game", function()
	local title = ctx.title
	assert(title:beginIntro(true, false), "begun again (forced, as the self-test does)")
	local seen = {}
	local caption = find("WindowsillIntro", "Caption")
	local released = -1
	for i = 1, math.ceil(TitleShots.INTRO.captionsEnd * 60) + 5 do
		frame(1 / 60)
		if caption.TextTransparency < 0.5 then seen[caption.Text] = true end
		if released < 0 and not title:holding() then released = i end
	end
	local lines = TitleText.captions(false)
	for _, line in lines do assert(seen[line], "caption not shown: " .. line) end
	assert(ctx.motor.pos.X >= TitleShots.INTRO.walk.untilX and ctx.motor.mode == "attached", `the spider walked out ({ctx.motor.pos})`)
	assert(math.abs(released / 60 - TitleShots.INTRO.total) < 0.05, `the controls came back at the end ({released / 60} s)`)
	assert(not title:playing() and not gui:FindFirstChild("WindowsillIntro").Enabled, "then it is over")
	local d = (camera.CFrame.Position - ctx.motor.pos).Magnitude
	assert(d < 8 and d > 0.5, `the game's camera behind the spider ({d})`)
end)

check("the intro under Reduced Motion holds each shot still; a screen opened over it pauses it; Resume ends it", function()
	local title = ctx.title
	player:SetAttribute("ReducedMotion", true)
	assert(title:beginIntro(true, false), "begun")
	frames(30)
	local a = camera.CFrame.Position
	frames(120)
	assert((camera.CFrame.Position - a).Magnitude < 1e-6, "held still")
	frames(90)
	assert((camera.CFrame.Position - a).Magnitude > 1, "cut to the next shot")
	player:SetAttribute("ReducedMotion", nil)
	local t = title.intro.t
	ctx.openMenu()
	frames(60)
	assert(title.intro.t == t and ctx.menu:isShowing(), "paused under the menu")
	assert(ctx.menu:choose("Resume"), "Resume")
	frames(2)
	assert(not title:playing() and ctx.hud.safe.Enabled, "the intro is over, the game is the player's")
end)

check("Continue from the title card begins the life: the drift lets the camera go, and the life menu offers Resume", function()
	assert(ctx.fresh("main", false, nil), "a life")
	ctx.place(Vector3.new(-25.5, 0.31, 6))
	frames(4)
	local feed = ClientStubs.actions["SpiderFeed"]
	feed("SpiderFeed", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.E, UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.zero })
	frames(1)
	feed("SpiderFeed", Enum.UserInputState.End, { KeyCode = Enum.KeyCode.E, UserInputType = Enum.UserInputType.Keyboard, Position = Vector3.zero })
	frames(2)
	assert(ctx.currentStore():loadBest().ok, "a rest kept")
	ctx.session.started = false -- (as at the start of a visit with a saved rest)
	ctx.openMenu()
	assert(ctx.menu.look == "title" and ctx.menu.choices[1].id == "Continue" and ctx.menu.choices[1].text == "Continue", "the title card offers Continue first")
	frames(2)
	assert((camera.CFrame.Position - ctx.motor.pos).Magnitude > 20, "the drift has the camera")
	assert(ctx.menu:choose("Continue"), "Continue")
	frames(30)
	assert(ctx.session.started and not ctx.menu:isShowing() and not ctx.title:playing(), "the life runs, with no intro")
	assert((camera.CFrame.Position - ctx.motor.pos).Magnitude < 8, "the game's camera")
	assert(ctx.soundscape.title == false, "the title's music is over")
	ctx.openMenu()
	assert(ctx.menu.look == "card" and ctx.menu.choices[1].id == "Resume", "the life menu, with Resume")
	assert(ctx.menu:choose("Resume"))
	frames(2)
end)

check("the death card in the game's face", function()
	ctx.endLife("starved")
	frames(5)
	local panel = ctx.caughtPanel
	assert(panel:isShowing() and panel.look == "card" and panel.line.FontFace.Family == TitleText.FAMILY, "the card")
	assert(panel.line.Text == "The spider starved.", "its words unchanged")
end)

print(`TITLE passed={passed} failed={failed}`)
if failed > 0 then error("title failed") end
