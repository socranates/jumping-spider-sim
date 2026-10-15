--!strict
-- Drawn fly: compact thorax/abdomen, compound eyes, six legs and two translucent wings. Never queryable.
local B={};B.__index=B
function B.new(parent: Instance): any
 local folder=Instance.new('Folder');folder.Name='Flies';folder.Parent=parent
 return setmetatable({folder=folder,rigs={}},B)
end
local function part(parent: Instance,name: string,size: Vector3,color: Color3,shape: Enum.PartType?): Part
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.Color=color;p.Shape=shape or Enum.PartType.Ball
 p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Material=Enum.Material.SmoothPlastic;p.Parent=parent;return p
end
function B.draw(self: any,flies: {any},now: number)
 local present={};local parts:{BasePart}={};local frames:{CFrame}={}
 for _,f in flies do
  present[f.id]=true
  local r=self.rigs[f.id]
  if not r then
   local folder=Instance.new('Folder');folder.Name=f.id;folder.Parent=self.folder;r={folder=folder,parts={}};self.rigs[f.id]=r
   for i,size in {Vector3.new(.28,.25,.28),Vector3.new(.22,.2,.37),Vector3.new(.24,.22,.18)} do
    r.parts[i]=part(folder,'Body'..i,size,Color3.fromRGB(34,43,39))
   end
   for i=4,5 do r.parts[i]=part(folder,'CompoundEye',Vector3.new(.105,.14,.13),Color3.fromRGB(108,40,26)) end
   for i=6,7 do r.parts[i]=part(folder,'Wing',Vector3.new(.18,.018,.55),Color3.fromRGB(183,198,195));r.parts[i].Transparency=.42 end
   for i=8,13 do r.parts[i]=part(folder,'Leg',Vector3.new(.025,.025,.25),Color3.fromRGB(40,35,30),Enum.PartType.Cylinder) end
  end
  local cf=CFrame.lookAt(f.position,f.position+f.heading,f.normal)
  local flying=f:airborne() or f.state=='CAPTURED'
  local wing=if flying then math.sin(now*92)*.8+.4 else .12
  local locals={CFrame.new(0,0,0),CFrame.new(0,0,.23),CFrame.new(0,.015,-.18),CFrame.new(-.105,.04,-.22),CFrame.new(.105,.04,-.22),
   CFrame.new(-.13,.1,.15)*CFrame.Angles(0,-.3,-wing),CFrame.new(.13,.1,.15)*CFrame.Angles(0,.3,wing)}
  for i=1,6 do local side=if i%2==0 then 1 else -1;local z=math.floor((i-1)/2)*.14-.15
   table.insert(locals,CFrame.new(side*.17,-.09,z)*CFrame.Angles(0,0,side*.5))
  end
  for i,p in r.parts do table.insert(parts,p);table.insert(frames,cf*locals[i]) end
 end
 for id,r in self.rigs do if not present[id] then r.folder:Destroy();self.rigs[id]=nil end end
 if #parts>0 then workspace:BulkMoveTo(parts,frames,Enum.BulkMoveMode.FireCFrameChanged) end
end
return B
