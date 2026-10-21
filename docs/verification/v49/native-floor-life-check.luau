-- Append inside the Studio-only review function after its route checks.
-- Do not create directors manually: arriving nearby must activate them normally.
do
 local RS=game:GetService("RunService")
 local Shared=game.ReplicatedStorage.Shared
 local Map=require(Shared.World.WorldMap)
 local Hut=require(Shared.World.Hut)
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={d.world.root}
 local shown
 workspace:SetAttribute("Cat",false);workspace:SetAttribute("Wasp",false)
 d.life.clock.hour=12
 for _,id in {"hut_floor_e","room_floor_b","room_floor_d"} do
  local spec
  for _,kind in Hut.bestiary(Map.region(id)) do if kind.profile=="fly_like_prototype" then spec=kind end end
  assert(spec,id.." missing floor fly spec")
  local first=spec.perches[1].position
  local standing
  for _,offset in {Vector3.new(6,0,0),Vector3.new(-6,0,0),Vector3.new(0,0,6),Vector3.new(0,0,-6)} do
   local p=first+offset
   local hit=workspace:Raycast(p+Vector3.new(0,3,0),Vector3.new(0,-6,0),params)
   if hit and hit.Normal.Y>.99 and math.abs(hit.Position.Y-Hut.FLOOR)<.01 then standing=hit.Position+Vector3.new(0,.31,0);break end
  end
  assert(standing,id.." missing clear supported approach")
  d.place(standing)
  local deadline=os.clock()+3;while os.clock()<deadline do RS.RenderStepped:Wait() end
  local entry=d.world.prey.garden[id]
  local director=entry and entry.kinds and entry.kinds.housefly
  assert(director and #director.flies==1,id.." did not activate its floor fly through normal proximity")
  local fly=director.flies[1]
  local rig=d.flyBodies.rigs[fly.id]
  assert(rig and rig.drawn and #rig.parts>0,id.." has a population but no drawn fly")
  print("[CHET_V49_FLOOR_FLY]",d.detail,id,#director.flies,fly.id,fly.state,fly.position,#rig.parts)
  shown=fly
 end
 RS:BindToRenderStep("ChetFloorFlyCamera",Enum.RenderPriority.Camera.Value+21,function()
  if not shown then return end
  local at=shown.position
  local offset=Vector3.new(3,2,3)
  local cam=workspace.CurrentCamera;cam.CFrame=CFrame.lookAt(at+offset,at);cam.Focus=CFrame.new(at);cam.FieldOfView=45
  local dof=game.Lighting:FindFirstChild("MacroDOF");if dof then dof.FocusDistance=offset.Magnitude;dof.InFocusRadius=4 end
 end)
 print("[CHET_V49_FLOOR_LIFE_END]",d.detail)
end
