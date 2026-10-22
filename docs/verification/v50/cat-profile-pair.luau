-- Temporary native benchmark, run with no CLI load. Restores the method on all exits.
-- Same final-source path, camera and scene: only pose rebuild cadence differs.
return function(d)
 local RS=game:GetService("RunService")
 local Map=require(game.ReplicatedStorage.Shared.World.WorldMap)
 local Body=require(game.Players.LocalPlayer.PlayerScripts.Client.CatBody)
 local original=Body.draw
 assert(d.fresh("free",false))
 d.life.clock.hour=12;d.cat.enabled=true
 d.place(assert(Map.region("deck_n2")).spawn.pos+Vector3.yAxis*.31)
 d.cam.mouse=false
 task.wait(7)
 assert((d.cat.pos-workspace.CurrentCamera.CFrame.Position).Magnitude>180,"paired cat sample must be distant")
 local function sample(label)
  task.wait(1)
  local frames={};local total=0
  d.prof.start()
  while total<5 do local dt=RS.RenderStepped:Wait();table.insert(frames,dt);total+=dt end
  d.prof.stop();table.sort(frames)
  print("[CHET_V50_CAT_PAIR]",d.detail,label,"frames",#frames,"mean_ms",total/#frames*1000,
   "p95_ms",frames[math.ceil(#frames*.95)]*1000,"worst_ms",frames[#frames]*1000)
  print("[CHET_V50_CAT_PAIR_LUA]",label,d.prof.line())
 end
 local ok,why=pcall(function()
  Body.draw=function(self,cat,now,dt,bell,purr,_cameraAt) return original(self,cat,now,dt,bell,purr,nil) end
  sample("every_render_1")
  Body.draw=original;sample("cached_far_pose")
  Body.draw=function(self,cat,now,dt,bell,purr,_cameraAt) return original(self,cat,now,dt,bell,purr,nil) end
  sample("every_render_2")
 end)
 Body.draw=original
 assert(ok,why)
 print("[CHET_V50_CAT_PAIR_END]",d.detail)
end
