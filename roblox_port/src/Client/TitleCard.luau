--!strict
-- The title card's camera and the intro of a new life (ROBLOX-109). The words are UI/TitleText's, the shots Movement/TitleShots'; this module draws them.
--
-- The title card: until a life has begun this visit, while a screen has the game (the start menu, a screen opened from it, the start's wait), the camera is TitleShots.drift at the game's clock (the splash, First/SplashScreen, drew the same
-- drift until the start menu opened, so the hand-over cannot jump) while the start menu, CaughtPanel's "title" look, is over it.
-- The intro: when a new life is begun from the start menu and this save has never seen it (`seen`, kept in the progress record as intro_seen), the
-- spider is put just inside the crack facing out and the intro plays: the morning through the glass, the sill floor to the crack, the spider walking out
-- (the motor's own walk: `wish` is the direction the client feeds it), three captions, then the view eases into the game's own camera and the controls are
-- the player's (the last caption stays a few seconds over the game). While it holds, the controls are blocked and the client's camera is not rendered.
-- The skip: after TitleShots.INTRO.skipAfter seconds, the jump key, Enter, A / Cross or a tap; the spider is put where its walk ends and the game's camera
-- comes up from a short dip to black. Reduced Motion: TitleShots holds each shot still and cuts. A screen over the game (the life menu) pauses it.
local CAS = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TitleText = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("TitleText"))
local TitleShots = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Movement"):WaitForChild("TitleShots"))

local TitleCard = {}
TitleCard.__index = TitleCard
TitleCard.ACTION = "WindowsillIntroSkip"
TitleCard.SKIP_FADE_S = 0.45 -- the dip after a skip: from black to the game over this long
TitleCard.GUI_NAME = "WindowsillIntro"

export type Config = {
	playerGui: Instance,
	camera: Camera,
	enabled: boolean, -- the title card's drift (not in the test place, which has no start menu)
	clock: () -> number, -- the game's clock (`time()`), the drift's
	reduced: () -> boolean,
	device: () -> string,
	spider: () -> Vector3,
	place: (Vector3, Vector3) -> (), -- put the spider here, facing this way (the client's place: the motor, the drawn up, the camera's snap)
	gameCamera: (number) -> CFrame, -- the game's own camera this frame (the client renders it and hands back where it put the camera)
	onBegin: () -> (),
	onEnd: () -> (),
}

local function lerpView(a: CFrame, b: CFrame, k: number): CFrame
	if k <= 0 then return a end
	if k >= 1 then return b end
	local p = a.Position:Lerp(b.Position, k)
	local look = a.LookVector:Lerp(b.LookVector, k)
	if look.Magnitude < 1e-6 then return b end
	return CFrame.lookAt(p, p + look.Unit)
end

function TitleCard.new(cfg: Config): any
	local gui = Instance.new("ScreenGui")
	gui.Name = TitleCard.GUI_NAME
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 45 -- (under the menus, CaughtPanel's 50: a screen opened during the intro is over it)
	gui.Enabled = false
	gui.Parent = cfg.playerGui
	local veil = Instance.new("Frame")
	veil.Name = "Veil"
	veil.Size = UDim2.fromScale(1, 1)
	veil.BorderSizePixel = 0
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = 1
	veil.Parent = gui
	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.BackgroundTransparency = 1
	caption.AnchorPoint = Vector2.new(0.5, 1)
	caption.Position = UDim2.new(0.5, 0, 1, -64)
	caption.Size = UDim2.new(0.86, 0, 0, 60)
	caption.TextWrapped = true
	caption.TextSize = 22
	caption.TextColor3 = TitleText.INK
	caption.TextStrokeColor3 = TitleText.GROUND
	caption.TextStrokeTransparency = 0.6
	caption.TextTransparency = 1
	caption.Text = ""
	caption.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(760, 200)
	limit.Parent = caption
	local skip = Instance.new("TextLabel")
	skip.Name = "Skip"
	skip.BackgroundTransparency = 1
	skip.AnchorPoint = Vector2.new(1, 1)
	skip.Position = UDim2.new(1, -24, 1, -20)
	skip.Size = UDim2.fromOffset(220, 24)
	skip.TextXAlignment = Enum.TextXAlignment.Right
	skip.TextSize = 15
	skip.TextColor3 = TitleText.SOFT
	skip.TextTransparency = 1
	skip.Text = ""
	skip.Parent = gui
	-- (a tap anywhere skips, on touch; it only takes taps while the intro has the screen)
	local tap = Instance.new("TextButton")
	tap.Name = "Tap"
	tap.BackgroundTransparency = 1
	tap.Text = ""
	tap.Size = UDim2.fromScale(1, 1)
	tap.ZIndex = 0
	tap.Visible = false
	tap.Parent = gui
	pcall(function()
		caption.FontFace = Font.new(TitleText.FAMILY, Enum.FontWeight.Regular, Enum.FontStyle.Italic)
		skip.FontFace = Font.new(TitleText.FAMILY, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	end)
	local self = setmetatable({
		cfg = cfg, gui = gui, veil = veil, caption = caption, skipLabel = skip, tap = tap,
		seen = false, intro = nil :: any, fade = 0, bound = false, lines = TitleText.captions(false),
	}, TitleCard)
	tap.Activated:Connect(function() self:skip() end)
	return self
end

-- Whether the intro is running at all (holding, or its last caption over the game).
function TitleCard.playing(self: any): boolean
	return self.intro ~= nil
end

-- Whether the intro has the camera and the controls now.
function TitleCard.holding(self: any): boolean
	local i = self.intro
	return i ~= nil and not i.released
end

function TitleCard._bind(self: any, on: boolean)
	if on and not self.bound then
		self.bound = true
		CAS:BindActionAtPriority(TitleCard.ACTION, function(_, state, _input)
			if state == Enum.UserInputState.Begin then self:skip() end
			return Enum.ContextActionResult.Sink
		end, false, 3500, Enum.KeyCode.Space, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.E, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB)
	elseif not on and self.bound then
		self.bound = false
		CAS:UnbindAction(TitleCard.ACTION)
	end
end

-- Begins the intro of a new life, unless this save has seen it (`force`: the self-test's, whatever was seen). The spider goes just inside the crack.
-- Marks it seen at once: a skipped intro has been seen. Returns whether it began.
function TitleCard.beginIntro(self: any, force: boolean?, gentle: boolean?): boolean
	if self.seen and not force then return false end
	self:stop()
	self.seen = true
	self.lines = TitleText.captions(gentle == true)
	local start = TitleShots.INTRO.start
	self.cfg.place(start.pos, start.heading)
	self.intro = { t = 0, released = false }
	self.fade = 0
	self.gui.Enabled = true
	self.tap.Visible = true
	self:_bind(true)
	self.cfg.onBegin()
	self:_draw(TitleShots.intro(0, self.cfg.reduced(), self.cfg.spider()))
	return true
end

-- Ends the intro at once, with nothing more (a new life, a return to a rest, the life menu's Resume: whoever calls it puts the screen back).
function TitleCard.stop(self: any)
	self.intro = nil
	self.fade = 0
	self.gui.Enabled = false
	self.tap.Visible = false
	self:_bind(false)
end

-- The controls are the player's again (the intro's end, or a skip): once.
function TitleCard._release(self: any)
	local i = self.intro
	if i == nil or i.released then return end
	i.released = true
	self.tap.Visible = false
	self:_bind(false)
	self.skipLabel.TextTransparency = 1
	self.cfg.onEnd()
end

-- The skip: refused before INTRO.skipAfter seconds and once the controls are back. The spider is put where its walk ends if it is not out yet;
-- the captions go with it; the game's camera comes up from black.
function TitleCard.skip(self: any): boolean
	local i = self.intro
	if i == nil or i.released or i.t < TitleShots.INTRO.skipAfter then return false end
	local walk = TitleShots.INTRO.walk
	local start = TitleShots.INTRO.start
	if self.cfg.spider().X < walk.untilX then
		self.cfg.place(Vector3.new(walk.untilX, start.pos.Y, start.pos.Z), start.heading)
	end
	self:_release()
	self.intro = nil
	self.fade = TitleCard.SKIP_FADE_S
	self.caption.TextTransparency = 1
	self.veil.BackgroundTransparency = 0
	return true
end

-- The direction to walk this tick while the intro holds (out of the crack, until past the walk's end), else nil.
function TitleCard.wish(self: any, pos: Vector3): Vector3?
	local i = self.intro
	if i == nil or i.released then return nil end
	local walk = TitleShots.INTRO.walk
	if i.t >= walk.from and i.t < walk.latest and pos.X < walk.untilX then return TitleShots.INTRO.start.heading end
	return nil
end

function TitleCard._draw(self: any, f: TitleShots.Frame)
	self.veil.BackgroundTransparency = 1 - f.veil
	local n = f.caption
	if n ~= nil then
		self.caption.Text = self.lines[n] or ""
		self.caption.TextTransparency = 1 - f.captionAlpha
		self.caption.TextStrokeTransparency = 1 - 0.4 * f.captionAlpha
	else
		self.caption.TextTransparency = 1
		self.caption.TextStrokeTransparency = 1
	end
	local i = self.intro
	local skippable = i ~= nil and not i.released and i.t >= TitleShots.INTRO.skipAfter
	self.skipLabel.Text = TitleText.skipHint(self.cfg.device() :: any)
	self.skipLabel.TextTransparency = if skippable then 0.3 else 1
end

-- Each rendered frame, after the client's camera settings and before its camera would be rendered. `started`: a life has begun this visit; `paused`: a
-- screen has the game (the intro waits). Returns true when this module placed the camera this frame (the client then does not render its own).
function TitleCard.frame(self: any, dt: number, started: boolean, paused: boolean): boolean
	local camera = self.cfg.camera
	local i = self.intro
	if i ~= nil then
		if not paused then i.t += dt end
		local f = TitleShots.intro(i.t, self.cfg.reduced(), self.cfg.spider())
		local wrote = false
		if not i.released then
			if f.holding then
				local fov = f.fov
				local view = f.cframe
				if f.blend > 0 then
					local gameFov = camera.FieldOfView
					view = lerpView(f.cframe, self.cfg.gameCamera(dt), f.blend)
					fov = f.fov + (gameFov - f.fov) * f.blend
				end
				camera.CFrame = view
				camera.FieldOfView = fov
				wrote = true
			else
				self:_release()
			end
		end
		self:_draw(f)
		if f.done then self:stop() end
		return wrote
	end
	if self.fade > 0 then
		self.fade = math.max(0, self.fade - dt)
		self.veil.BackgroundTransparency = 1 - self.fade / TitleCard.SKIP_FADE_S
		if self.fade <= 0 then self.gui.Enabled = false end
	end
	if self.cfg.enabled and not started and paused then -- (the start menu, a screen opened from it, or the start's wait for the save: never a life's frame)
		local cf, fov = TitleShots.drift(self.cfg.clock(), workspace:GetAttribute("World")) -- (ROBLOX-115: the world's own drift)
		camera.CFrame = cf
		camera.FieldOfView = fov
		return true
	end
	return false
end

return TitleCard
