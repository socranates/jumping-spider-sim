-- Temporary native fixture: actual player camera, geometry and motor at known tight places.
return function(d)
 local Shared=game.ReplicatedStorage.Shared
 local Map=require(Shared.World.WorldMap)
 local Region=require(Shared.World.Region)
 local Sites=require(Shared.World.LivedInSites)
 local Meadow=require(Shared.World.Meadow)
 assert(d.fresh("free",false))
 d.life.clock.hour=12
 d.cam.mouse=false
 local params=OverlapParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={d.world.root}
 local function inspect(name,at,up,heading,seconds)
  d.place(at,up);d.motor:place(at,up,heading);d.cam:snap()
  local region=Map.at(at)
  local deadline=os.clock()+4
  while region and not d.world:regionReady(region.id) and os.clock()<deadline do d.place(at,up);task.wait(.1) end
  assert(region==nil or d.world:regionReady(region.id),name.." not streamed")
  d.motor:place(at,up,heading);d.cam:snap()
  task.wait(1)
  assert(d.motor.mode=="attached" and (d.motor.pos-at).Magnitude<.3,name.." fixture did not hold its surface")
  local camera=workspace.CurrentCamera
  local inside={}
  for _,p in workspace:GetPartBoundsInBox(CFrame.new(camera.CFrame.Position),Vector3.one*.04,params) do
   if p.CanQuery and p.CanCollide then table.insert(inside,p.Name) end
  end
  print("[CHET_V50_TIGHT]",d.detail,name,"mode",d.motor.mode,"camera",camera.CFrame.Position,"spider",d.motor.pos,
   "inside",#inside,table.concat(inside,","))
  assert(#inside==0,name.." camera interior")
  task.wait(seconds or 3)
 end
 for _,id in {"hut_floor_a","hut_shelf"} do
  local r=assert(Map.region(id));inspect(id,r.spawn.pos+Vector3.yAxis*.31,Vector3.yAxis,r.spawn.heading,3)
 end
 for id,site in Sites.CANS do
  inspect(site.id.."_inside",site.at+Vector3.new(8,.61,0),Vector3.yAxis,Vector3.xAxis,4)
  d.input:simulate("Forward",true);task.wait(3);d.input:simulate("Forward",false)
  local p=workspace.CurrentCamera.CFrame.Position
  print("[CHET_V50_CAN_WALK]",d.detail,id,"at",d.motor.pos,"mode",d.motor.mode,"camera",p)
 end
 inspect("crack",Vector3.new(-25.5,.31,6),Vector3.yAxis,Vector3.zAxis,4)
 inspect("under_bench",Vector3.new(-70,Meadow.SLAB.top+.31,-770),Vector3.yAxis,Vector3.zAxis,4)
 local r=assert(Map.region("garden_c3"))
 for _,piece in Region.pieces(r) do
  if string.find(piece.id,"leaf",1,true) then
   local at=Vector3.new((piece.lo.X+piece.hi.X)/2,piece.hi.Y+.31,(piece.lo.Z+piece.hi.Z)/2)
   inspect("milkweed_leaf",at,Vector3.yAxis,Vector3.zAxis,10)
   print("[CHET_V50_MILKWEED]",d.detail,piece.id,"attached",d.motor.mode=="attached")
   break
  end
 end
 local at=Vector3.new(0,.31,-21.4)
 d.place(at);d.motor:place(at,Vector3.yAxis,-Vector3.zAxis);d.cam:snap()
 task.wait(.3)
 d.input:simulate("Drop",true)
 local deadline=os.clock()+15
 while not d.motor:onLine() and os.clock()<deadline do task.wait(.1) end
 assert(d.motor:onLine(),"fixture did not reach the line from the supported sill edge")
 task.wait(3);d.input:simulate("Drop",false)
 local camera=workspace.CurrentCamera
 local hits=workspace:GetPartBoundsInBox(CFrame.new(camera.CFrame.Position),Vector3.one*.04,params)
 print("[CHET_V50_LINE_VIEW]",d.detail,d.motor.mode,d.motor.silk.mode,"camera_overlaps",#hits)
 assert(#hits==0,"line camera interior")
 task.wait(4)
 print("[CHET_V50_TIGHT_END]",d.detail)
end
