--!strict
-- Thin drawer for the pure memory view. Reuses widgets rather than creating Instances every frame.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local View = require(Shared.UI.PerceptionView)
local Hud = {}
Hud.__index = Hud
function Hud.new(parent: Instance): any
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.IgnoreGuiInset, gui.ResetOnSpawn = "PerceptionHud", true, false
	gui.DisplayOrder = 4
	gui.Parent = parent
	return setmetatable({gui=gui, pool={}, used=0}, Hud)
end
function Hud.label(self: any, text: string, at: Vector2, alpha: number, rotation: number?, size: number?)
	self.used += 1
	local p = self.pool[self.used]
	if not p then
		p = Instance.new("TextLabel")
		p.BackgroundTransparency, p.AnchorPoint = 1, Vector2.new(0.5,0.5)
		p.Size = UDim2.fromOffset(240,28)
		p.TextColor3, p.TextStrokeColor3 = Color3.new(1,1,1), Color3.new(0,0,0)
		p.Parent = self.gui
		table.insert(self.pool,p)
	end
	p.Visible, p.Text, p.Position = true, text, UDim2.fromOffset(at.X,at.Y)
	p.TextTransparency, p.TextStrokeTransparency = 1-alpha, 1-alpha*0.9
	p.Rotation, p.TextSize = rotation or 0, size or 18
end
function Hud.draw(self: any, memory: any, camera: Camera, cast: any, focusing: boolean, showMark: boolean?)
	self.used = 0
	local viewport = camera.ViewportSize
	local adapter = {
		project = function(at: Vector3, size: number)
			local p = camera:WorldToViewportPoint(at)
			local q = camera:WorldToViewportPoint(at+camera.CFrame.RightVector*math.max(size,0.2)*0.5)
			return Vector2.new(p.X,p.Y), p.Z > 0 and p.X > -40 and p.Y > -40 and p.X < viewport.X+40 and p.Y < viewport.Y+40,
				math.clamp((Vector2.new(p.X,p.Y)-Vector2.new(q.X,q.Y)).Magnitude,10,36)
		end,
		edge = function(dir: Vector3)
			local d = camera.CFrame:VectorToObjectSpace(dir)
			local v = Vector2.new(d.X,-d.Y)
			if v.Magnitude < 0.03 then v = Vector2.new(0,-1) end
			v = v.Unit
			local half = viewport*0.5-Vector2.new(34,34)
			local t = math.min(half.X/math.max(math.abs(v.X),1e-6),half.Y/math.max(math.abs(v.Y),1e-6))
			return {pos=viewport*0.5+v*t, dir=v}
		end,
		covered = function(at: Vector3, slack: number)
			local eye = camera.CFrame.Position
			local hit = cast(eye,at)
			return hit ~= nil and (hit-eye).Magnitude < (at-eye).Magnitude-slack
		end,
	}
	local view = View.build(memory,adapter,showMark)
	for _, e in view.edges do self:label("›",e.pos,e.alpha,math.deg(math.atan2(e.dir.Y,e.dir.X)),32) end
	for _, r in view.rings do
		-- Twenty-eight small tangents form a ring; last-seen rings become broken with age.
		for i=0,27 do
			if r.kind == "mark" and i%2 == 1 and r.dash < 0.95 then continue end
			local a = i*math.pi/14
			self:label("—",r.pos+Vector2.new(math.cos(a),math.sin(a))*r.radius,r.alpha,math.deg(a)+90,8)
		end
	end
	for _, l in view.labels do self:label(l.text,l.pos-Vector2.new(0,l.offset+10),l.alpha) end
	if focusing then
		for i=0,3 do
			local a=i*math.pi/2
			self:label("—",viewport*0.5+Vector2.new(math.cos(a),math.sin(a))*11,0.8,math.deg(a),12)
		end
	end
	for i=self.used+1,#self.pool do self.pool[i].Visible=false end
	self.view = view
end
return Hud
