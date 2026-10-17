--!strict
-- At most three pale, empty skins in the retreat. Presentation only, never queried by movement or senses.
local OldSkins={}
OldSkins.__index=OldSkins
function OldSkins.new(parent: Instance): any
 local folder=Instance.new("Folder");folder.Name="OldSkins";folder.Parent=parent
 return setmetatable({folder=folder,key=""},OldSkins)
end
function OldSkins.draw(self: any,positions: {Vector3})
 local key=""
 for _,p in positions do key..=string.format("%.5f,%.5f,%.5f;",p.X,p.Y,p.Z) end
 if key==self.key then return end
 self.key=key;self.folder:ClearAllChildren()
 for i,p in positions do
  local center=p+Vector3.new((i-2)*0.23,-0.25,0.06*(i-1))
  local function piece(name: string,size: Vector3,cf: CFrame)
   local part=Instance.new("Part");part.Name=name;part.Size=size;part.CFrame=cf
   part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false;part.CastShadow=false
   part.Color=Color3.new(.78,.71,.57);part.Material=Enum.Material.SmoothPlastic;part.Transparency=.38
   part.Parent=self.folder
   return part
  end
  local shell=piece("EmptySkin",Vector3.new(.21,.08,.30),CFrame.new(center))
  local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Sphere;mesh.Parent=shell
  for j=1,8 do
   local side=if j<=4 then -1 else 1
   local z=((j-1)%4-1.5)*.065
   local a=center+Vector3.new(side*.06,0,z)
   local b=center+Vector3.new(side*.22,.015,z*1.5)
   piece("ShedLeg",Vector3.new(.018,.018,(b-a).Magnitude),CFrame.lookAt((a+b)*.5,b))
  end
 end
end
return OldSkins
