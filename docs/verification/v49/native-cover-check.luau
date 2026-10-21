-- Command bar, Client context, after station-playback's REVIEW_END.
assert(game:GetService("RunService"):IsClient())
local d=assert(_G.ChetStation)
task.spawn(function()
 local RS=game:GetService("RunService")
 local stop
 for _,segment in d.Cat.plan(d.cat.seed,1) do
  if segment.kind=="groom" and segment.spot=="rug" then stop=segment;break end
 end
 assert(stop,"rug stop missing")
 d.input:clear();d.Cat.load(d.cat,d.Cat.defaultRecord())
 local hour=(stop.t0+stop.t1)/2
 d.life.clock.day=1;d.life.clock.hour=hour
 d.cat:step(1/60,1,hour,nil)
 workspace:SetAttribute("Cat",true)
 local target=d.Cat.chest(d.cat)+d.cat.heading*70
 target=Vector3.new(target.X,d.cat.surface+.31,target.Z) -- on the rug, not inside its 1-cm thickness
 d.place(target)
 local blocker=Instance.new("Part")
 blocker.Name="ChetTemporaryOccluder";blocker.Anchored=true
 blocker.CanCollide=true;blocker.CanQuery=true;blocker.Size=Vector3.new(8,80,8)
 blocker.Position=(d.Cat.head(d.cat)+target)/2;blocker.Parent=d.world.root
 d.input:simulate("Forward",true,"cover-review")
 for _=1,90 do RS.RenderStepped:Wait() end
 local blockedNotices=d.cat.notices
 blocker:Destroy()
 for _=1,45 do RS.RenderStepped:Wait() end
 d.input:clear()
 print("[CHET_V49_NATIVE_COVER]",blockedNotices,d.cat.notices,d.cat.swats,d.motor.pos)
 assert(blockedNotices==0,"cat detected motion through the opaque prop")
 assert(d.cat.notices>0,"removing cover did not restore sight of actual walking")
 workspace:SetAttribute("Cat",false)
 print("[CHET_V49_NATIVE_COVER_END]")
end)
