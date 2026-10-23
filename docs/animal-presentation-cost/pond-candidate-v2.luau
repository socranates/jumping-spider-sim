--!strict
-- The pond's bigger animals in the world (ROBLOX-122): the green frog of Predator/Frog on its seat, and the green darner (World/Pond.darner) patrolling over the water.
-- Both at true size (1 stud = 1 cm), every part anchored, never colliding, never seen by a ray (a spider stands on the stone or the pad, not on the frog), placed with
-- one BulkMoveTo each. Display only: nothing here feeds back to the sim. `frogParts` and `darnerParts` are pure (the previewer draws them too).
--   the frog ..... a green frog (Lithobates clamitans) about 7.8 cm from snout to vent, sitting low: its head green, its back olive-brown and mottled, the ridge down each
--                  side of its back, its big golden eyes up on top of its head, the eardrum behind each (a male's, twice the eye's width), a white throat that
--                  pumps as it breathes, its front legs propped and its long hind legs folded under it; when it strikes, its pink tongue out to the spider and
--                  back (Predator/Frog.tongue). Matte, but the eyes. (ROBLOX-128) It breathes as a frog does (J. Exp. Biol. 204:2647, the effects of tonic
--                  lung inflation on ventilation in the frog: the floor of the mouth moves up and down continuously between breaths, the glottis shut, and now
--                  and then a lung breath, a deeper pump that fills the lungs): the throat flutters, and every few seconds pumps deep and the flanks swell.
--                  The rates are the game's (a lung breath every 5.2 s, well under the paper's ceiling near 30 a minute).
--   the darner ... a male common green darner (Anax junius) about 7.5 cm long with a 10 cm wingspan: its big eyes, a green thorax, a long blue abdomen with a dark line
--                  along it, four clear wings held out flat, a blur as it flies.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shapes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Habitat"):WaitForChild("Shapes"))

local PondBodies = {}
PondBodies.__index = PondBodies

export type Spec = { name: string, size: Vector3, frame: CFrame, color: string, ball: boolean, full: boolean?, material: string?, transparency: number?, reflectance: number? }

local v = Vector3.new
local function ell(out: { Spec }, name: string, at: Vector3, size: Vector3, color: string, full: boolean?, turn: CFrame?): Spec
	local s: Spec = { name = name, size = size, frame = CFrame.new(at) * (turn or CFrame.identity), color = color, ball = true, full = full, material = "SmoothPlastic" }
	table.insert(out, s)
	return s
end
local function rod(out: { Spec }, name: string, a: Vector3, b: Vector3, d: number, color: string, full: boolean?): Spec
	local len = math.max((b - a).Magnitude, 1e-3)
	local s: Spec = { name = name, size = v(d, d, len), frame = CFrame.lookAt((a + b) / 2, b), color = color, ball = true, full = full, material = "SmoothPlastic" }
	table.insert(out, s)
	return s
end

PondBodies.BREATH = 5.2 -- (ROBLOX-128) seconds from one lung breath to the next
PondBodies.FROG = { head = "6f9a3a", back = "6a6a3a", mottle = "3e4a26", ridge = "8a8a52", belly = "e8e4d0", throat = "f0ecd8", eye = "a8782a", pupil = "141210",
	tympanum = "6a5a3a", leg = "5e6a34", band = "3a4426", tongue = "d88a8a" }
-- The frog's parts in its own frame (its seat under it at y 0, ahead -z), the throat pumped by `throat` (0..1), its tongue out `tongue` studs (0: in).
-- (ROBLOX-128) `swell` (0..1): the flanks filled by a lung breath.
local function frogSizes(throat: number, swell: number?): (Vector3, Vector3)
 local sw = 1 + 0.05 * (swell or 0)
 return v(4.6 * sw, 2.3 * sw, 5.6), v(2.7, 0.7 + 0.45 * throat, 2.3)
end
local function frogTongue(out: { Spec }, tongue: number)
 if tongue > 0.05 then rod(out, "Tongue", v(0, 0.9, -4.4), v(0, 0.9, -4.4 - tongue), 0.45, PondBodies.FROG.tongue) end
end

function PondBodies.frogParts(throat: number, tongue: number, swell: number?): { Spec }
	local C = PondBodies.FROG
	local out: { Spec } = {}
	local pitch = CFrame.Angles(math.rad(-9), 0, 0) -- (it sits low, its front a little up on its short arms)
	local bodySize, throatSize = frogSizes(throat, swell)
	ell(out, "Body", v(0, 1.05, 0.5), bodySize, C.back, false, pitch)
	ell(out, "Belly", v(0, 0.6, 0.6), v(4.2, 1.2, 5.2), C.belly, true, pitch)
	ell(out, "Head", v(0, 1.4, -2.7), v(3.8, 1.8, 3.0), C.head)
	ell(out, "Snout", v(0, 1.15, -3.8), v(2.6, 1.1, 1.4), C.head)
	ell(out, "Throat", v(0, 0.75, -3.0), throatSize, C.throat, true)
	for _, s in { -1, 1 } do
		local w = if s < 0 then "L" else "R"
		ell(out, "Eye" .. w, v(0.98 * s, 2.15, -2.85), v(0.8, 0.72, 0.8), C.eye)
		ell(out, "Pupil" .. w, v(1.24 * s, 2.22, -3.0), v(0.36, 0.22, 0.4), C.pupil, true)
		ell(out, "Tympanum" .. w, v(1.85 * s, 1.6, -1.9), v(0.15, 1.5, 1.5), C.tympanum, true)
		rod(out, "Ridge" .. w, v(1.25 * s, 2.0, -1.6), v(1.55 * s, 1.7, 2.9), 0.35, C.ridge, true)
		ell(out, "Mottle" .. w, v(0.9 * s, 2.05, 1.2), v(1.0, 0.25, 1.4), C.mottle, true)
		-- the front legs propped short under the chest
		rod(out, "Arm" .. w, v(1.5 * s, 0.75, -2.0), v(1.95 * s, 0.3, -2.6), 0.55, C.leg)
		rod(out, "Forearm" .. w, v(1.95 * s, 0.3, -2.6), v(1.7 * s, 0.1, -3.4), 0.42, C.leg)
		ell(out, "Hand" .. w, v(1.7 * s, 0.08, -3.6), v(1.0, 0.16, 0.9), C.leg, true)
		-- the hind legs folded tight along the flank: the thigh forward, the shank back beside it, the long foot forward again under it to the hand
		rod(out, "Thigh" .. w, v(1.7 * s, 0.85, 2.7), v(2.75 * s, 0.65, 0.2), 1.2, C.leg)
		rod(out, "Shank" .. w, v(2.75 * s, 0.65, 0.2), v(2.35 * s, 0.4, 3.1), 0.9, C.leg)
		rod(out, "Foot" .. w, v(2.35 * s, 0.3, 3.1), v(3.0 * s, 0.12, -0.9), 0.55, C.leg)
		rod(out, "Band" .. w, v(2.2 * s, 0.78, 1.45), v(2.3 * s, 0.5, 1.6), 1.25, C.band, true)
		rod(out, "Toes" .. w, v(3.0 * s, 0.12, -0.9), v(3.5 * s, 0.08, -1.9), 0.3, C.leg, true)
	end
	ell(out, "Mottle", v(0, 2.05, 1.9), v(1.4, 0.25, 1.2), C.mottle, true)
	frogTongue(out, tongue)
	for _, s in out do if string.sub(s.name, 1, 3) == "Eye" then s.reflectance = 0.15 end end
	return out
end

PondBodies.DARNER = { eye = "6a8a4a", thorax = "5a9a3a", abdomen = "3a7ac8", line = "1e2a3a", wing = "e6ecee", leg = "2a2a24" }
-- The darner's parts in its own frame (ahead -z), its wings blurred (`blur`).
function PondBodies.darnerParts(blur: boolean): { Spec }
	local C = PondBodies.DARNER
	local out: { Spec } = {}
	ell(out, "Eyes", v(0, 0.05, -2.4), v(1.0, 0.75, 0.8), C.eye)
	ell(out, "Thorax", v(0, 0, -1.6), v(0.85, 0.95, 1.3), C.thorax)
	ell(out, "Abdomen", v(0, 0, 1.2), v(0.42, 0.42, 4.6), C.abdomen)
	rod(out, "Line", v(0, 0.2, -0.6), v(0, 0.2, 3.2), 0.1, C.line, true)
	for _, s in { -1, 1 } do
		for i, z in { -1.8, -1.2 } do
			local w = ell(out, `Wing{i}{if s < 0 then "L" else "R"}`, v(2.6 * s, 0.25, z + (i - 1) * 0.2), v(4.8, 0.03, if i == 1 then 1.0 else 1.25), C.wing, false)
			w.material, w.transparency, w.reflectance = "Glass", if blur then 0.82 else 0.6, 0.1
		end
		rod(out, "Leg" .. s, v(0.2 * s, -0.4, -1.8), v(0.35 * s, -0.8, -2.1), 0.06, C.leg, true)
	end
	return out
end

function PondBodies.new(parent: Instance, detail: string): any
	local folder = Instance.new("Folder")
	folder.Name = "PondAnimals"
	folder.Parent = parent
	return setmetatable({ folder = folder, detail = detail, frog = nil :: any, darner = nil :: any }, PondBodies)
end

local function build(self: any, name: string, specs: { Spec }): any
	local model = Instance.new("Folder")
	model.Name = name
	local parts: { BasePart? } = {}
	for i, spec in specs do
		if spec.full and self.detail == "low" then parts[i] = nil; continue end
		local p = Shapes.ellipsoid(model, spec.name, spec.size, CFrame.new(), Color3.fromHex(spec.color), spec.material or "SmoothPlastic")
		if spec.transparency ~= nil then p.Transparency = spec.transparency end
		if spec.reflectance ~= nil then p.Reflectance = spec.reflectance end
		parts[i] = p
	end
	model.Parent = self.folder
	return { model = model, parts = parts, count = #specs, moved = {}, frames = {} }
end

local AWAY = CFrame.new(0, -600, 0)
local HIDDEN: { Spec } = table.freeze({})
local function place(rig: any, specs: { Spec }, frame: CFrame)
	local moved: { BasePart } = rig.moved
	local frames: { CFrame } = rig.frames
	table.clear(moved)
	table.clear(frames)
	for i = 1, rig.count do
		local part = rig.parts[i]
		local spec = specs[i]
		if part ~= nil then
			-- (ROBLOX-128) a part whose size the pose changes takes it: the throat's pump, the flanks' swell and the tongue's reach were built once and never
			-- resized before, so the throat never moved and the tongue was drawn a centimetre long halfway out
			if spec ~= nil and part.Size ~= spec.size then part.Size = spec.size end
			table.insert(moved, part)
			table.insert(frames, if spec ~= nil then frame * spec.frame else AWAY)
		end
	end
	if #moved > 0 then Workspace:BulkMoveTo(moved, frames, Enum.BulkMoveMode.FireCFrameChanged) end
end

-- Draws the frog (Predator/Frog's: on its seat, facing its heading, breathing; its tongue while it strikes, to `target`) and the darner (`darnerAt`, its heading;
-- nil: away), `now` the clock for the throat's pumping.
function PondBodies.draw(self: any, frog: any, target: Vector3?, darnerAt: Vector3?, darnerHeading: Vector3?, now: number)
	if frog ~= nil and frog.here then
		local tip = frog:tongue(target)
		local tongue = if tip ~= nil then (tip - frog:mouth()).Magnitude else 0
		-- (ROBLOX-128) the throat's flutter between breaths, and a lung breath every BREATH seconds: a deep pump, the flanks swelling and settling
		local inBreath = (now % PondBodies.BREATH) / 0.9
		local breath = if inBreath < 1 then math.sin(inBreath * math.pi) else 0
		local throat = 0.3 + 0.2 * math.sin(now * 2 * math.pi * 1.7) * (1 - breath) + 0.7 * breath
		if self.frog == nil then
   local recipe = PondBodies.frogParts(0.5, 1)
   self.frog = build(self, "GreenFrog", recipe)
   self.frog.recipe = recipe
   for _, spec in recipe do
    if spec.name == "Body" then self.frog.bodySpec = spec elseif spec.name == "Throat" then self.frog.throatSpec = spec end
   end
   assert(self.frog.bodySpec and self.frog.throatSpec and recipe[self.frog.count].name == "Tongue", "frog recipe layout")
  end
  local specs = self.frog.recipe
  self.frog.bodySpec.size, self.frog.throatSpec.size = frogSizes(throat, breath)
  specs[self.frog.count] = nil
  frogTongue(specs, tongue)
		local h = frog.heading
		local frame = CFrame.lookAt(frog.pos, frog.pos + Vector3.new(h.X, 0, h.Z))
		place(self.frog, specs, frame)
	elseif self.frog ~= nil then
		place(self.frog, HIDDEN, CFrame.identity)
	end
	if darnerAt ~= nil then
		if self.darner == nil then
			local specs = PondBodies.darnerParts(true)
			self.darner = build(self, "GreenDarner", specs)
			self.darner.recipe = specs
		end
		local specs = self.darner.recipe
		local h = darnerHeading or Vector3.xAxis
		place(self.darner, specs, CFrame.lookAt(darnerAt, darnerAt + h))
	elseif self.darner ~= nil then
		place(self.darner, HIDDEN, CFrame.identity)
	end
end

return PondBodies
