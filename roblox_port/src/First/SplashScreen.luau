--!strict
-- The startup veil/title drift (ROBLOX-109). Healthy TitleReady fades into the
-- controller's title card. WorldStartupFailed, readiness timeout or a caught
-- startup error keeps a self-contained recovery explanation when PlayerGui exists.
-- Default Roblox loading is removed only after our own screen has been built.
-- The frame loop is bounded; the static failure screen uses readiness/destruction
-- listeners so delayed healthy startup can dismiss it without continued rendering.
-- Pure step/look decisions and the replaceable host are exercised by title.luau.
local SplashScreen = {}

SplashScreen.GUI_NAME = "WindowsillSplash"
SplashScreen.READY_ATTRIBUTE = "TitleReady"
SplashScreen.FAIL_ATTRIBUTE = "WorldStartupFailed"
-- Emergency text must also work before Shared/UI has replicated.
SplashScreen.FAILURE_TEXT = "The world hasn't finished loading.\nPlease rejoin."
SplashScreen.SHARED_WAIT_S = 10 -- the words and the drift: looked for this long, then never again (a dark field without words)
SplashScreen.LOADED_WAIT_S = 30 -- game:IsLoaded(): after this long the world is shown as it is
SplashScreen.READY_WAIT_S = 45 -- unready deadline: finish the render loop, retain static recovery UI
SplashScreen.DOT_AFTER_S = 4 -- the waiting dot, only if the wait is this long
SplashScreen.WORDS_AT_S = 0.6 -- the title begins to come up this long after the start (or when the words arrive)
SplashScreen.TITLE_IN_S = 1.6
SplashScreen.REVEAL_S = 2.5 -- the world, from black to the veil's resting shade, once loaded
SplashScreen.VEIL_REST = 0.3 -- the veil's resting opacity over the world (the words stay legible on a bright morning)
SplashScreen.FADE_S = 1.2 -- the splash's going, over the title card

export type Facts = { loaded: boolean, ready: boolean, words: boolean, failed: boolean? }
export type State = { t: number, phase: string, leaveT: number, loadedT: number?, wordsT: number?, why: string, leaveVeil: number, leaveTitle: number }
export type Look = { veil: number, title: number, dot: number, drive: boolean }

function SplashScreen.newState(): State
	return { t = 0, phase = "showing", leaveT = 0, loadedT = nil, wordsT = nil, why = "", leaveVeil = 1, leaveTitle = 0 }
end

local function smooth(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

-- What the splash would show now, before any going (the veil's opacity over the world, the title's opacity).
local function resting(s: State): (number, number)
	local veil = 1
	if s.loadedT ~= nil then veil = 1 - (1 - SplashScreen.VEIL_REST) * smooth((s.t - s.loadedT) / SplashScreen.REVEAL_S) end
	local title = 0
	if s.wordsT ~= nil then title = smooth((s.t - math.max(s.wordsT, SplashScreen.WORDS_AT_S)) / SplashScreen.TITLE_IN_S) end
	return veil, title
end

-- One frame: `dt` seconds have passed and these are the facts. Showing until the title card is ready (why "ready") or READY_WAIT_S has passed ("timeout");
-- healthy readiness fades over FADE_S; failure/timeout finishes the loop and retains a static explanation.
function SplashScreen.step(s: State, dt: number, facts: Facts): State
	s.t += math.max(dt, 0)
 if facts.failed and not facts.ready then s.phase,s.why="done","world";return s end
	if (facts.loaded or s.t >= SplashScreen.LOADED_WAIT_S) and s.loadedT == nil then s.loadedT = s.t end
	if facts.words and s.wordsT == nil then s.wordsT = s.t end
	if s.phase == "showing" then
		local why = if facts.ready then "ready" elseif s.t >= SplashScreen.READY_WAIT_S then "timeout" else nil
		if why ~= nil then
			s.leaveVeil, s.leaveTitle = resting(s)
   s.phase, s.why, s.leaveT = if why=="ready" then "leaving" else "done", why, s.t
		end
	elseif s.phase == "leaving" and s.t - s.leaveT >= SplashScreen.FADE_S then
		s.phase = "done"
	end
	return s
end

-- What to draw this frame: the veil's and the title's opacity (0 to 1), the waiting dot's (0 when it is not there; it pulses), and whether the
-- splash moves the camera (until the title card has it).
function SplashScreen.look(s: State, facts: Facts): Look
	local veil, title = resting(s)
	if s.phase ~= "showing" then
		local k = 1 - smooth((s.t - s.leaveT) / SplashScreen.FADE_S)
		veil, title = s.leaveVeil * k, s.leaveTitle * k
	end
	local waiting = s.phase == "showing" and s.t >= SplashScreen.DOT_AFTER_S and not (facts.loaded and facts.ready)
	local dot = if waiting then 0.35 + 0.35 * (0.5 + 0.5 * math.sin(s.t * 2.4)) else 0
	return { veil = veil, title = title, dot = dot, drive = s.phase ~= "done" and not facts.ready }
end

-- The engine's side, replaced whole by the tests. `find` returns the words (UI/TitleText) and the drift (Movement/TitleShots) once they have replicated,
-- else nils; it must not wait.
SplashScreen.host = {
	service = function(name: string): any return game:GetService(name) end,
	frame = function(): number return (game:GetService("RunService") :: any).RenderStepped:Wait() end,
	now = function(): number return time() end,
	loaded = function(): boolean return game:IsLoaded() end,
	world = function(): string? return workspace:GetAttribute("World") end, -- (ROBLOX-115: the Workspace attribute the server writes, World/Worlds; nil until it has)
	warn = function(text: string) warn(text) end,
	find = function(): (any, any)
		local shared = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
		local ui = shared and shared:FindFirstChild("UI")
		local movement = shared and shared:FindFirstChild("Movement")
		local text = ui and ui:FindFirstChild("TitleText")
		local shots = movement and movement:FindFirstChild("TitleShots")
		if text == nil or shots == nil or not text:IsA("ModuleScript") or not shots:IsA("ModuleScript") then return nil, nil end
		return (require :: any)(text), (require :: any)(shots)
	end,
} :: any

local function label(parent: Instance, name: string): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.TextTransparency = 1
	l.TextWrapped = true
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Text = ""
	l.Parent = parent
	return l
end

-- The splash's screen: a black veil over everything, the title and its line a little above the middle, the dot in the bottom-right corner.
local function build(playerGui: Instance): any
	local gui = Instance.new("ScreenGui")
	gui.Name = SplashScreen.GUI_NAME
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100 -- (over the title card, CaughtPanel's 50, which it fades away over)
	gui.Parent = playerGui
	local veil = Instance.new("Frame")
	veil.Name = "Veil"
	veil.Size = UDim2.fromScale(1, 1)
	veil.BorderSizePixel = 0
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = 0
	veil.Parent = gui
	local title = label(gui, "Title")
	title.Position = UDim2.fromScale(0.5, 0.42)
	title.Size = UDim2.new(0.9, 0, 0, 72)
	local sub = label(gui, "Subtitle")
	sub.Position = UDim2.new(0.5, 0, 0.42, 58)
	sub.Size = UDim2.new(0.9, 0, 0, 30)
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(1, 1)
	dot.Position = UDim2.new(1, -28, 1, -28)
	dot.Size = UDim2.fromOffset(9, 9)
	dot.BorderSizePixel = 0
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.BackgroundTransparency = 1
	dot.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = dot
	return { gui = gui, veil = veil, title = title, sub = sub, dot = dot }
end

-- The words, in the game's serif, once they have arrived.
local function dress(ui: any, words: any)
	ui.title.Text, ui.sub.Text = words.TITLE, words.SUBTITLE
	ui.title.TextColor3, ui.sub.TextColor3 = words.INK, words.SOFT
	local size = ui.gui.AbsoluteSize
	ui.title.TextSize = words.titleSize(if size then size.X else 1280)
	ui.sub.TextSize = 20
	pcall(function()
		ui.title.FontFace = Font.new(words.FAMILY, Enum.FontWeight.Light, Enum.FontStyle.Normal)
		ui.sub.FontFace = Font.new(words.FAMILY, Enum.FontWeight.Regular, Enum.FontStyle.Italic)
	end)
end

-- An unready controller cannot be revealed as a playable empty world. Keep one
-- static explanation, with bounded work and listeners released on ready/destroy.
local function keepFailure(ui: any,player: any)
 ui.veil.BackgroundTransparency=0
 if ui.title.Text=="" then ui.title.Text="The Windowsill" end
 ui.title.TextColor3=Color3.new(1,1,1);ui.title.TextTransparency=0;ui.title.TextSize=32
 ui.sub.Text=SplashScreen.FAILURE_TEXT;ui.sub.TextColor3=Color3.new(1,1,1)
 ui.sub.TextTransparency=0;ui.sub.TextSize=if player:GetAttribute("LargeText")==true then 24 else 20
 ui.sub.Size=UDim2.new(.9,0,0,96);ui.dot.BackgroundTransparency=1
 local readyConnection: any=nil
 local destroyConnection: any=nil
 local function disconnect()
  if readyConnection then readyConnection:Disconnect();readyConnection=nil end
  if destroyConnection then destroyConnection:Disconnect();destroyConnection=nil end
 end
 local function ready()
  if player:GetAttribute(SplashScreen.READY_ATTRIBUTE)==true then
   disconnect();if ui.gui.Parent~=nil then ui.gui:Destroy() end
  end
 end
 -- Install owner cleanup first, so a failed player subscription cannot leak.
 destroyConnection=ui.gui.Destroying:Connect(disconnect)
 readyConnection=player:GetAttributeChangedSignal(SplashScreen.READY_ATTRIBUTE):Connect(ready)
 ready() -- cover readiness between the final frame and listener installation
end

-- Returns ready, timeout, world, or failed:<diagnostic>. Only healthy readiness
-- removes the veil immediately; other paths retain recovery UI when it can be drawn.
function SplashScreen.run(): string
	local h = SplashScreen.host
	local ui: any = nil
 local player: any=nil
	local ok, result = pcall(function(): string
  player=h.service("Players").LocalPlayer
  local playerGui=player:WaitForChild("PlayerGui",10)
  assert(playerGui~=nil and playerGui.Name=="PlayerGui","PlayerGui did not arrive")
  ui=build(playerGui)
  pcall(function() h.service("ReplicatedFirst"):RemoveDefaultLoadingScreen() end)
		local workspace = h.service("Workspace")
		local words, shots = nil, nil
		local took = false
		local s = SplashScreen.newState()
		while s.phase ~= "done" do
			local dt = h.frame()
			if words == nil and s.t < SplashScreen.SHARED_WAIT_S then
				local okFind, text, drift = pcall(h.find)
				if okFind and text ~= nil and drift ~= nil then
					words, shots = text, drift
					dress(ui, words)
				end
			end
			local facts: Facts = { loaded = h.loaded() == true, ready = player:GetAttribute(SplashScreen.READY_ATTRIBUTE) == true, words = words ~= nil, failed = player:GetAttribute(SplashScreen.FAIL_ATTRIBUTE)==true }
			SplashScreen.step(s, dt, facts)
			local look = SplashScreen.look(s, facts)
			ui.veil.BackgroundTransparency = 1 - look.veil
			ui.title.TextTransparency, ui.sub.TextTransparency = 1 - look.title, 1 - look.title
			ui.dot.BackgroundTransparency = 1 - look.dot
			local camera = workspace.CurrentCamera
			if look.drive and shots ~= nil and camera ~= nil then
				if not took then camera.CameraType = Enum.CameraType.Scriptable; took = true end
				local cf, fov = shots.drift(h.now(), if h.world ~= nil then h.world() else nil) -- (ROBLOX-115: the world the server runs, World/Worlds)
				camera.CFrame, camera.FieldOfView = cf, fov
			end
		end
		return s.why
	end)
 if ui~=nil then
  local retained=false
  if player~=nil and (not ok or result~="ready") then
   local problem: any=nil
   retained,problem=pcall(keepFailure,ui,player)
   if not retained then pcall(h.warn,"[Windowsill] startup explanation failed: "..tostring(problem)) end
  end
  if not retained then pcall(function() ui.gui:Destroy() end) end
 end
	if not ok then
		pcall(h.warn, "[Windowsill] splash: " .. tostring(result) .. " (startup explanation retained when available)")
		return "failed: " .. tostring(result)
	end
	return result
end

return SplashScreen
