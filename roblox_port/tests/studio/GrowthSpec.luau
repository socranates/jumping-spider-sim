--!strict
return function(check: (string, () -> ()) -> ())
 local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
 local Rig=require(Shared.Rig.SpiderRig)
 local Growth=require(Shared.Life.Growth)
 local Support=require(Shared.Movement.SupportMath)
 local Dance=require(Shared.Rig.PeacockDance)
 local folder=Instance.new("Folder");folder.Name="GrowthTestWorld";folder.Parent=workspace
 local surface=Instance.new("Part");surface.Size=Vector3.new(20,1,20);surface.Anchored=true;surface.Parent=folder
 for _,normal in {Vector3.yAxis,Vector3.xAxis,-Vector3.yAxis} do
  check("growth: planted feet and unchanged root on "..tostring(normal),function()
   local frame=Support.bodyCFrame(Vector3.new(300,0,0),normal,-Vector3.zAxis)
   surface.CFrame=frame*CFrame.new(0,-.5,0)
   for _,id in {"first_spider","maratus_volans_male"} do
    local rig=Rig.new(folder,folder,id,"full");rig.reducedMotion=true
    local body=frame*CFrame.new(0,.31,0)
    for _=1,10 do rig:update(body,1/60,true,false) end
    local size=rig.root.Size
    for stage=1,3 do
     local feet={};for i,l in rig._legs do feet[i]=l.foot;assert(l.planted,"foot not on surface") end
     rig:setGrowthStage(stage);rig:update(body,0,true,false)
     for i,l in rig._legs do assert((l.foot-feet[i]).Magnitude<1e-4,"growth dragged planted foot") end
     for _=1,25 do rig:update(body,1/60,true,false) end
     for _,l in rig._legs do assert(math.abs((l.foot-frame.Position):Dot(normal))<.015,"foot left surface") end
     assert((rig.root.Position-body.Position).Magnitude<1e-4 and rig.root.Size==size,"root changed")
    end
    rig:setSoftness(1);rig:setCondition(.1);rig:update(body,1,true,false)
    assert(rig.model:FindFirstChild("Cephalothorax").Color.R>.5,"not pale")
    rig:destroy()
   end
  end)
 end
 check("growth: adult peacock dance and eye visibility",function()
  surface.CFrame=CFrame.new(300,-.5,0)
  local r=Rig.new(folder,folder,"maratus_volans_male","full")
  r:setGrowthStage(3);r.dance=Dance.rawPose(5.2,false)
  r:update(CFrame.new(300,.31,0),1/60,true,false)
  assert(r._fan.front[1].part.Size.X>.4,"fan didn't grow")
  r:setEyeView(true)
  for _,p in r._fan.parts do assert(p.LocalTransparencyModifier==1,"fan in eyes") end
  r:destroy()
 end)
 check("growth: interrupted record resumes exactly once",function()
  local g=Growth.new();assert(g:eat(.9));assert(g:beginMoult());g:passHours(4,Vector3.zero)
  local r=Growth.new();assert(r:load(g:toRecord()))
  assert(r:passHours(8,Vector3.zero)=="moulted")
  assert(r.stage==1 and #r.exuviae==1 and r:softness()==1)
  assert(r:passHours(10,Vector3.zero)=="hardened" and #r.exuviae==1)
 end)
 folder:Destroy()
end
