-- Temporary Studio-only normal-rules sample. Never publish as SilkPlayback.
-- Default game camera and live actors. Initial placement and synthetic keyboard
-- inputs make this reproducible; it is not a completed player hunt/escape.
return function(d)
 local RS=game:GetService("RunService")
 local function wait(s) local t=os.clock()+s;while os.clock()<t do RS.RenderStepped:Wait() end end
 local deadline=os.clock()+30
 while not d.session.started and os.clock()<deadline do
  if d.menu:isShowing() then d.menu:choose("New") end
  task.wait(.2)
 end
 if d.title:holding() then d.title:skip() end
 wait(2)
 d.fresh("normal",true)
 d.life.clock.hour=12
 workspace:SetAttribute("Cat",true)
 d.cat.enabled=true
 d.cam.mouse=false
 game:GetService("UserInputService").MouseBehavior=Enum.MouseBehavior.Default
 game:GetService("UserInputService").MouseIconEnabled=true
 d.place(Vector3.new(0,-69.69,200))
 wait(8)
 local from=d.motor.pos
 d.input:simulate("Forward",true,"ordinary-station-sample")
 wait(2)
 d.input:clear()
 print("[CHET_V49_ORDINARY_WALK]",from,d.motor.pos,d.motor.mode,d.life.lifeOver)
 wait(5)
 d.prof.start()
 local samples={}
 local elapsed=0
 while elapsed<10 do
  local dt=RS.RenderStepped:Wait()
  table.insert(samples,dt)
  elapsed+=dt
 end
 d.prof.stop()
 table.sort(samples)
 local slow=0
 for _,dt in samples do if dt>.05 then slow+=1 end end
 print("[CHET_V49_STATION_PERF]",d.detail,#samples,elapsed,
  "mean_ms",elapsed/#samples*1000,"p95_ms",samples[math.ceil(#samples*.95)]*1000,
  "worst_ms",samples[#samples]*1000,"over50ms",slow,"alive",not d.life.lifeOver,"mode",d.motor.mode)
 print("[CHET_V49_STATION_PROFILE]",d.prof.line())
 print("[CHET_V49_ORDINARY_END]",d.detail,d.motor.pos,d.cat.pose,d.cat.notices)
end
