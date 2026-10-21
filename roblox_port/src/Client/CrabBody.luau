--!strict
-- The crab spiders in the world (ROBLOX-119): each of Predator/CrabSpider's drawn at true size on its flower, a female goldenrod crab spider about 9 mm long: a broad
-- abdomen behind a small cephalothorax, two dark eyes on a pale ridge, the first two pairs of legs long and held open to either side (the honest tell), the back two short
-- and tucked under; the yellow one a shade paler and greener than the goldenrod, the white one cream with a faint red streak down either side of its abdomen; some days
-- it holds a caught hoverfly. When its legs close (a grab or a lunge, `strike`) the front legs swing in. Every part anchored, never collides, never seen by a ray (a
-- spider stands on the flower, not on the crab spider). Display only: nothing here feeds back to the sim. `parts` is pure (the previewer draws it too).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shapes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Habitat"):WaitForChild("Shapes"))

local CrabBody = {}
CrabBody.__index = CrabBody

CrabBody.COLORS = {
	yellow = { body = "e3d15e", legs = "d8c45a", ridge = "efe39a", stripe = "d8c45a" },
	white = { body = "efecd8", legs = "e6e2cc", ridge = "f6f3e6", stripe = "c0634e" },
}

export type Spec = { name: string, size: Vector3, frame: CFrame, color: string, ball: boolean, full: boolean? }

-- The parts of one crab spider in its own frame (its body's middle at the origin, ahead -z), the legs closed by `close` (0 open, 1 shut).
function CrabBody.parts(form: string, holding: boolean, close: number): { Spec }
	local C = CrabBody.COLORS[form] or CrabBody.COLORS.yellow
	local out: { Spec } = {}
	local function ell(name: string, at: Vector3, size: Vector3, color: string, full: boolean?)
		table.insert(out, { name = name, size = size, frame = CFrame.new(at), color = color, ball = true, full = full })
	end
	local function rod(name: string, a: Vector3, b: Vector3, d: number, color: string, full: boolean?)
		local len = (b - a).Magnitude
		table.insert(out, { name = name, size = Vector3.new(d, d, len), frame = CFrame.lookAt((a + b) / 2, b), color = color, ball = false, full = full })
	end
	ell("Abdomen", Vector3.new(0, 0.02, 0.22), Vector3.new(0.78, 0.42, 0.62), C.body)
	ell("Cephalothorax", Vector3.new(0, 0.05, -0.26), Vector3.new(0.5, 0.3, 0.44), C.body)
	ell("Ridge", Vector3.new(0, 0.2, -0.38), Vector3.new(0.36, 0.06, 0.1), C.ridge, true)
	for _, s in { -1, 1 } do
		ell(if s < 0 then "EyeL" else "EyeR", Vector3.new(0.09 * s, 0.22, -0.4), Vector3.new(0.06, 0.06, 0.06), "1a1410")
		ell(if s < 0 then "StripeL" else "StripeR", Vector3.new(0.36 * s, 0.06, 0.22), Vector3.new(0.06, 0.12, 0.48), C.stripe, true)
		-- legs I and II: long, held open sideways and a little forward, two segments each; closing swings their tips in under the head
		for i, spec in { { a = 35, l = 1.05 }, { a = 75, l = 0.95 } } do
			local open = math.rad(spec.a * (1 - close) + 5 * close)
			local hip = Vector3.new(0.2 * s, 0.02, -0.28 + (i - 1) * 0.08)
			local dir = Vector3.new(math.sin(open + math.rad(30) * close) * s, 0, -math.cos(open))
			local knee = hip + dir * (spec.l * 0.5) + Vector3.new(0, 0.18, 0)
			local tip = hip + dir * spec.l + Vector3.new(0, -0.08, 0)
			rod(`Leg{i}{if s < 0 then "L" else "R"}a`, hip, knee, 0.07, C.legs)
			rod(`Leg{i}{if s < 0 then "L" else "R"}b`, knee, tip, 0.06, C.legs)
		end
		-- legs III and IV: short, tucked under
		for i, z in { -0.18, -0.1 } do
			local hip = Vector3.new(0.2 * s, -0.02, z)
			rod(`Leg{i + 2}{if s < 0 then "L" else "R"}`, hip, hip + Vector3.new(0.32 * s, -0.16, 0.18 + i * 0.08), 0.05, C.legs)
		end
	end
	if holding then
		-- a caught hoverfly held under its head, its banded abdomen and its wings
		ell("PreyAbdomen", Vector3.new(0.05, 0.0, -0.78), Vector3.new(0.3, 0.24, 0.6), "d9b43a", true)
		ell("PreyBand", Vector3.new(0.05, 0.02, -0.74), Vector3.new(0.31, 0.25, 0.1), "1c1a16", true)
		ell("PreyThorax", Vector3.new(0.05, 0.04, -0.52), Vector3.new(0.26, 0.24, 0.24), "3a2e1e", true)
		ell("PreyWing", Vector3.new(0.3, 0.12, -0.7), Vector3.new(0.5, 0.02, 0.22), "dfe6ea", true)
	end
	return out
end

function CrabBody.new(parent: Instance, detail: string): any
	local folder = Instance.new("Folder")
	folder.Name = "CrabSpiders"
	folder.Parent = parent
	return setmetatable({ folder = folder, detail = detail, rigs = {} :: { any } }, CrabBody)
end

local function build(self: any, k: number, form: string, holding: boolean): any
	local model = Instance.new("Folder")
	model.Name = "Crab" .. k
	local parts: { BasePart? } = {}
	for i, spec in CrabBody.parts(form, holding, 0) do
		if spec.full and self.detail == "low" then parts[i] = nil; continue end
		local p = if spec.ball then Shapes.ellipsoid(model, spec.name, spec.size, CFrame.new(), Color3.fromHex(spec.color), "SmoothPlastic")
			else Shapes.block(model, spec.name, spec.size, CFrame.new(), Color3.fromHex(spec.color), "SmoothPlastic")
		parts[i] = p
	end
	model.Parent = self.folder
	return { model = model, parts = parts, form = form, holding = holding, close = -1, at = nil :: Vector3? }
end

-- Draws each crab spider of `crabs` (Predator/CrabSpider's) where it sits: built when its day's place or form changes, posed when its legs move.
function CrabBody.draw(self: any, crabs: any)
	local list = crabs.crabs
	for k, c in list do
		local rig = self.rigs[k]
		if rig == nil or rig.form ~= c.form or rig.holding ~= c.holding then
			if rig ~= nil then rig.model:Destroy() end
			rig = build(self, k, c.form, c.holding)
			self.rigs[k] = rig
		end
		local close = if c.strike >= 0 then math.clamp(c.strike / 0.12, 0, 1) else 0
		if rig.close ~= close or rig.at ~= c.pos then
			rig.close, rig.at = close, c.pos
			local frame = CFrame.lookAt(c.pos, c.pos + c.heading)
			local moved: { BasePart } = {}
			local frames: { CFrame } = {}
			for i, spec in CrabBody.parts(c.form, c.holding, close) do
				local part = rig.parts[i]
				if part ~= nil then
					table.insert(moved, part)
					table.insert(frames, frame * spec.frame)
				end
			end
			Workspace:BulkMoveTo(moved, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end
	for k = #list + 1, #self.rigs do
		local rig = self.rigs[k]
		if rig ~= nil then rig.model:Destroy(); self.rigs[k] = nil end
	end
end

return CrabBody
