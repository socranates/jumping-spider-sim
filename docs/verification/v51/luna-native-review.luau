-- Local-place-only fixture. Never install this in the cloud place or publish it.
return function(d)
 assert(game.PlaceId==0,"local review only")
 local RS=game:GetService("RunService")
 local Shared=game.ReplicatedStorage.Shared
 local Environment=require(Shared.World.Environment)
 local Spec=require(Shared.Data.RareSightings).luna
 local until_=os.clock()+30
 while not d.session.started and not d.menu:isShowing() and os.clock()<until_ do task.wait(.2) end
 task.wait(3) -- allow the server's initial progress response before test identities
 assert(d.fresh("free",false))
 if d.title:holding() then d.title:stop() end
 d.cam.mouse=false
 local function check(ok,text) assert(ok,text);print("[CHET_V51_RARE_PASS]",d.detail,text) end
 local serial,plan
 for n=1,200 do
  local p=d.rareDirector.plan(914,n,1)
  if p then
   local w=Environment.sample(p.day,p.hour,914)
   if w.temperature>=Spec.minTemperature and w.rain<=Spec.maxRain then serial=n;plan=p;break end
  end
 end
 assert(serial and plan)
 d.rareHistory.serial=serial-1;d.rareDirector.beginLife(d.rareHistory,d.life)
 d.life.rareBorn=1;d.life.clock.day=plan.day;d.life.clock.hour=plan.hour-.025
 d.place(Spec.at+Vector3.new(0,1,1));task.wait(.5)
 check(d.rareBody.model==nil,"absent before scheduled arrival")
 -- A fixed review camera, not production camera behavior.
 RS:BindToRenderStep("ChetLunaReview",999,function()
  workspace.CurrentCamera.CFrame=CFrame.lookAt(Spec.at+Vector3.new(10,12,-14),Spec.at)
 end)
 task.wait(12)
 check(d.rareBody.model~=nil and d.rareBody.serial==serial,"scheduled animal drawn")
 check(#d.rareBody.parts==24 and #d.rareBody.supports:GetChildren()==2,"26-part total budget")
 check(d.rareHistory.claimed.luna_moth==serial,"arrival claim saved outside rest")
 check(d.notebook:isOpen("rare_luna_moth"),"visible unobstructed encounter opens notebook")
 local supports=d.rareBody.supports
 for _,part in supports:GetChildren() do check(part.CanQuery and part.CanCollide,"settled wing is queryable support") end
 d.place(Spec.at+Vector3.new(-2.05,.39,.3));task.wait(2)
 check(d.motor.mode=="attached" and d.motor.pos.Y>Spec.at.Y+.25,"motor settles on wing without falling through")
 local floorY=d.motor.pos.Y
 d.input:simulate("Forward",true);task.wait(.25);d.input:simulate("Forward",false);task.wait(.5)
 check(d.motor.mode=="attached" and math.abs(d.motor.pos.Y-floorY)<.25,"short walk stays on wing")
 print("[CHET_V51_RARE_VIEW]",d.detail,"wing",d.motor.pos,"native screenshot window")
 local times={};local elapsed=0
 while elapsed<3 do local dt=RS.RenderStepped:Wait();table.insert(times,dt);elapsed+=dt end
 table.sort(times)
 print("[CHET_V51_RARE_FRAME]",d.detail,"frames",#times,"mean_ms",elapsed/#times*1000,"p95_ms",times[math.ceil(#times*.95)]*1000)
 task.wait(12)
 d.life.clock.day=plan.day+1;d.life.clock.hour=6.1;task.wait(1)
 check(d.rareBody.model~=nil and d.rareBody.leaving==0,"dawn waits for rider")
 d.place(Spec.at+Vector3.new(15,.31,0));task.wait(4)
 check(d.rareBody.model==nil,"departure cleans animal and supports")
 check(d.notebook:isOpen("rare_luna_moth"),"departure retains notebook")
 check(d.fresh("free",false) and d.life.rareSerial==serial+1,"new life gets new identity")
 RS:UnbindFromRenderStep("ChetLunaReview")
 print("[CHET_V51_RARE_END]",d.detail,"pass")
end
