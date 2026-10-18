--!strict
-- Godot windowsill.gd T09b: the pale east leaf tip falls on a committed jump.
-- Called on simulation ticks, never wall time. Its identity survives falling/restores.
local Breakaway={}
Breakaway.__index=Breakaway
Breakaway.RESET=8
Breakaway.FALL=0.7
function Breakaway.new(world: Instance, decor: Instance?): any
 local part=world:FindFirstChild("leaf_tip")
 local pieces={}
 local pilea=if decor then decor:FindFirstChild("Pilea") else nil
 local tip=if pilea then pilea:FindFirstChild("leaf_tip") else nil
 if tip then
  for _,p in tip:GetDescendants() do
   if p:IsA("BasePart") then table.insert(pieces,{part=p,frame=p.CFrame,transparency=p.Transparency}) end
  end
 end
 return setmetatable({pieces=pieces,transparency=if part and part:IsA("BasePart") then part.Transparency else 0,part=part,home=if part and part:IsA("BasePart") then part.CFrame else CFrame.identity,
  left=0,elapsed=0,last=nil},Breakaway)
end
function Breakaway.valid(record: any): boolean
 return record==nil or (type(record)=="table" and type(record.left)=="number" and record.left==record.left and record.left>=0 and record.left<=Breakaway.RESET)
end
function Breakaway.record(self: any): any return {left=self.left} end
function Breakaway.apply(self: any, record: any)
 self.left=if record then record.left else 0
 self.elapsed=if self.left>0 then Breakaway.FALL else 0
 self.last=nil
 self:draw(false)
end
function Breakaway.draw(self: any,reduced: boolean)
 local p=self.part
 if not p then return end
 local down=self.left>0
 p.CanCollide=not down;p.CanQuery=not down
 local u=if down then math.clamp(self.elapsed/Breakaway.FALL,0,1) else 0
 local moved=if reduced then self.home else self.home*CFrame.new(.4*u,-5*u*u,0)*CFrame.Angles(0,0,-1.2*u)
 p.CFrame=if #self.pieces>0 then self.home else moved
 p.Transparency=if down and (reduced or u>=1) then 1 else self.transparency
 for _,entry in self.pieces do
  if entry.part.Parent then
   entry.part.CFrame=moved*self.home:Inverse()*entry.frame
   entry.part.Transparency=if down and (reduced or u>=1) then 1 else entry.transparency
  end
 end
end
function Breakaway.step(self: any,dt: number,outcome: any,position: Vector3,reduced: boolean): boolean
 local fell=false
 local wasDown=self.left>0
 if outcome and outcome~=self.last then
  self.last=outcome
  local p=outcome.plan
  if self.left==0 and outcome.kind=="launched" and p and p.point and self.part then
   local localPoint=self.home:PointToObjectSpace(p.point)
   local half=self.part.Size*.5+Vector3.one*.02
   if math.abs(localPoint.X)<=half.X and math.abs(localPoint.Y)<=half.Y and math.abs(localPoint.Z)<=half.Z then
    self.left=Breakaway.RESET;self.elapsed=0;fell=true
   end
  end
 end
 if self.left>0 and not fell then
  self.elapsed+=dt;self.left=math.max(0,self.left-dt)
  if self.left==0 and self.part then
   local p=self.home:PointToObjectSpace(position);local half=self.part.Size*.5+Vector3.one*1.3
   if math.abs(p.X)<=half.X and math.abs(p.Y)<=half.Y and math.abs(p.Z)<=half.Z then self.left=.5 end
  end
 end
 if fell or wasDown then self:draw(reduced) end
 return fell
end
return Breakaway
