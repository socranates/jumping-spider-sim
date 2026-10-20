--!strict
-- The splash (ROBLOX-109): the game's own loading screen, from ReplicatedFirst. Roblox's default loading screen is removed at once and in its place is
-- a dark field; as the world arrives it fades up on the garden in the morning seen from outside, drawing in toward the window (Shared/Movement/TitleShots.drift),
-- with the title and its one line (Shared/UI/TitleText) in the game's serif. When the client's title card is up (the client sets the Player attribute
-- TitleReady when the start menu opens) the splash fades away over it; the camera is the title card's from then (the same drift, from the same clock).
-- No "Loading..." bar: if the wait is long, a small dot pulses in a corner.
--
-- It can never hang the game. Each frame is one pass of a loop with nothing that waits for long; the words and the drift are looked for each frame for
-- SHARED_WAIT_S seconds (they replicate after ReplicatedFirst) and their absence only means a dark field without words; a game that does not say it has
-- loaded within LOADED_WAIT_S is shown anyway; and at READY_WAIT_S the splash goes whatever has happened, leaving the plain start menu (the client opens
-- it on its own, as it always has). The whole run is inside a pcall: an error anywhere takes the splash away and is written to Output once. The camera is
-- only ever written (CameraType Scriptable, as the client's own camera sets it), never handed back to Roblox's: the client's camera takes it over.
--
-- The decisions are pure (SplashScreen.step and SplashScreen.look, over a state and the facts of the frame); `run` draws them through a host (the
-- services, the frame wait, the clock, the module lookup) that tests/title.luau replaces with its own to drive every fallback without an engine.
local SplashScreen = {}

SplashScreen.GUI_NAME = "WindowsillSplash"
SplashScreen.READY_ATTRIBUTE = "TitleReady"
SplashScreen.SHARED_WAIT_S = 10 -- the words and the drift: looked for this long, then never again (a dark field without words)
SplashScreen.LOADED_WAIT_S = 30 -- game:IsLoaded(): after this long the world is shown as it is
SplashScreen.READY_WAIT_S = 45 -- the title card: after this long the splash goes, and the plain menu is what is left
SplashScreen.DOT_AFTER_S = 4 -- the waiting dot, only if the wait is this long
SplashScreen.WORDS_AT_S = 0.6 -- the title begins to come up this long after the start (or when the words arrive)
SplashScreen.TITLE_IN_S = 1.6
SplashScreen.REVEAL_S = 2.5 -- the world, from black to the veil's resting shade, once loaded
SplashScreen.VEIL_REST = 0.3 -- the veil's resting opacity over the world (the words stay legible on a bright morning)
SplashScreen.FADE_S = 1.2 -- the splash's going, over the title card

export type Facts = { loaded: boolean, ready: boolean, words: boolean }
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
-- then leaving over FADE_S; then done.
function SplashScreen.step(s: State, dt: number, facts: Facts): State
	s.t += math.max(dt, 0)
	if (facts.loaded or s.t >= SplashScreen.LOADED_WAIT_S) and s.loadedT == nil then s.loadedT = s.t end
	if facts.words and s.wordsT == nil then s.wordsT = s.t end
	if s.phase == "showing" then
		local why = if facts.ready then "ready" elseif s.t >= SplashScreen.READY_WAIT_S then "timeout" else nil
		if why ~= nil then
			s.leaveVeil, s.leaveTitle = resting(s)
			s.phase, s.why, s.leaveT = "leaving", why, s.t
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

-- The splash, from the start to its end. Returns why it ended: "ready" (the title card took over), "timeout" (READY_WAIT_S, the plain menu is left) or
-- "failed: <error>" (something raised; the splash is gone and the game goes on).
function SplashScreen.run(): string
	local h = SplashScreen.host
	local ui: any = nil
	local ok, result = pcall(function(): string
		pcall(function() h.service("ReplicatedFirst"):RemoveDefaultLoadingScreen() end)
		local player = h.service("Players").LocalPlayer
		ui = build(player:WaitForChild("PlayerGui", 10))
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
			local facts: Facts = { loaded = h.loaded() == true, ready = player:GetAttribute(SplashScreen.READY_ATTRIBUTE) == true, words = words ~= nil }
			SplashScreen.step(s, dt, facts)
			local look = SplashScreen.look(s, facts)
			ui.veil.BackgroundTransparency = 1 - look.veil
			ui.title.TextTransparency, ui.sub.TextTransparency = 1 - look.title, 1 - look.title
			ui.dot.BackgroundTransparency = 1 - look.dot
			local camera = workspace.CurrentCamera
			if look.drive and shots ~= nil and camera ~= nil then
				if not took then camera.CameraType = Enum.CameraType.Scriptable; took = true end
				local cf, fov = shots.drift(h.now())
				camera.CFrame, camera.FieldOfView = cf, fov
			end
		end
		return s.why
	end)
	if ui ~= nil then pcall(function() ui.gui:Destroy() end) end
	if not ok then
		pcall(h.warn, "[Windowsill] splash: " .. tostring(result) .. " (the splash is gone; the game goes on)")
		return "failed: " .. tostring(result)
	end
	return result
end

return SplashScreen
