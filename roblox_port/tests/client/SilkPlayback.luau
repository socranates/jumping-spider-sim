--!strict
-- Included only in tests.project.json. Drives the real player controller, not a duplicate motor.
local RunService=game:GetService("RunService")
local HttpService=game:GetService("HttpService")
return function(driver: any)
	local rows={}
 driver.prey.enabled=false
	local function untilState(predicate,seconds)
		local deadline=os.clock()+seconds
		repeat RunService.Heartbeat:Wait(); if predicate(driver.get()) then return true end until os.clock()>=deadline
		return false
	end
	local function check(name,fn)
		local ok,err=pcall(fn)
		local row={name=name,passed=ok,detail=if ok then "" else tostring(err)}
		table.insert(rows,row)
		print("PORT_CLIENT_ROW "..HttpService:JSONEncode({evidence_id=workspace:GetAttribute("PortEvidence"),result=row}))
	end
	check("player walks to edge and hangs",function()
		driver.place(Vector3.new(-1,4.51,0))
		driver.drop()
		assert(driver.get().walking,"did not start edge walk")
		assert(untilState(function(s) return s.line=="locked" and s.taut and s.position.Y<3.9 end,12),"no hanging state")
	end)
	check("held lower reaches sill floor",function()
		driver.input:set("Drop",true)
		assert(untilState(function(s) return s.mode=="attached" and s.position.Y<0.4 end,15),"did not land on sill")
		driver.input:set("Drop",false)
	end)
	check("player reels back to leaf",function()
		driver.place(Vector3.new(-1,4.51,0)); driver.drop()
		assert(untilState(function(s) return s.line=="locked" and s.taut end,12),"no line")
		driver.input:set("Forward",true)
		assert(untilState(function(s) return s.mode=="attached" and s.position.Y>3.5 end,12),"no leaf recovery")
		driver.input:set("Forward",false)
	end)
	-- ROBLOX-08 controls through the real client: the same path a key, button or finger takes (SpiderInput.simulate).
	local function wait(seconds: number)
		local t=os.clock()+seconds
		repeat RunService.Heartbeat:Wait() until os.clock()>=t
	end
	check("a tap of Jump hops forward",function()
		driver.place(Vector3.new(-22,0.31,6)); wait(0.2)
		local start=driver.get().position
		driver.input:simulate("Jump",true); RunService.Heartbeat:Wait(); driver.input:simulate("Jump",false)
		assert(untilState(function(s) return s.mode=="air" end,1),"no hop")
		assert(untilState(function(s) return s.mode=="attached" end,3),"did not land")
		local moved=(driver.get().position-start).Magnitude
		assert(moved>1.2 and moved<1.8,`hopped {moved}`)
	end)
	check("Q during an aim cancels it and the release does not leap",function()
		driver.place(Vector3.new(-22,0.31,6)); wait(0.2)
		local start=driver.get().position
		driver.input:simulate("Jump",true); wait(0.4)
		assert(driver.jump:isAiming(),"no aim after a 0.4 s hold")
		driver.input:simulate("Cancel",true); wait(0.05); driver.input:simulate("Cancel",false); wait(0.05)
		driver.input:simulate("Jump",false); wait(0.4)
		assert(driver.get().mode=="attached" and (driver.get().position-start).Magnitude<0.05,"leapt after a cancel")
		assert(driver.jump.last and driver.jump.last.kind=="cancelled","no cancel recorded")
	end)
	check("a key and a finger hold Cancel together; only a deliberate hold lets go of the line",function()
		driver.place(Vector3.new(-1,4.51,0)); driver.drop()
		assert(untilState(function(s) return s.line=="locked" and s.taut end,12),"no hang")
		wait(0.6)
		driver.input:simulate("Cancel",true,"touch")
		driver.input:simulate("Cancel",true,Enum.KeyCode.Q)
		wait(0.25)
		driver.input:simulate("Cancel",false,"touch")
		assert(driver.input.held.Cancel==true and driver.get().line=="locked","releasing the finger dropped the key's hold")
		assert(untilState(function(s) return s.line=="none" end,1.5),"a held Q did not let go")
		driver.input:simulate("Cancel",false,Enum.KeyCode.Q)
		assert(untilState(function(s) return s.mode=="attached" end,6),"did not land after letting go")
	end)
	check("on the line the prompts name each device's controls, wrap and stay on screen; the camera never rolls",function()
		driver.place(Vector3.new(-1,4.51,0)); driver.drop()
		assert(untilState(function(s) return s.line=="locked" and s.taut end,12),"no hang")
		local gui=game:GetService("Players").LocalPlayer.PlayerGui:WaitForChild("SpiderPrompts") :: ScreenGui
		local panel=gui:WaitForChild("PromptPanel") :: Frame
		local expected: {[string]: string}={keyboard="hold Q: let go",gamepad="hold B: let go",touch="hold Let go: let go"}
		for device,word in expected do
			driver.setDevice(device); wait(0.15)
			local hint=panel:FindFirstChild("PromptHint") :: TextLabel
			assert(hint.Visible and string.find(hint.Text,word,1,true),`{device}: "{hint.Text}"`)
			assert(hint.TextFits,`{device}: the hint does not fit`)
			local a,b,screen=panel.AbsolutePosition,panel.AbsoluteSize,workspace.CurrentCamera.ViewportSize
			assert(a.X>=0 and a.Y>=0 and a.X+b.X<=screen.X+1 and a.Y+b.Y<=screen.Y+1,`{device}: panel off screen ({a}, {b} in {screen})`)
		end
		driver.setDevice("keyboard")
		local overlap=OverlapParams.new(); overlap.FilterType=Enum.RaycastFilterType.Include; overlap.FilterDescendantsInstances={driver.sill}
		local deadline=os.clock()+1.5
		driver.input:simulate("Forward",true)
		repeat
			RunService.Heartbeat:Wait()
			local cf=workspace.CurrentCamera.CFrame
			assert(math.abs(cf.RightVector.Y)<1e-4,"the camera rolled")
			assert(#workspace:GetPartBoundsInRadius(cf.Position,0.05,overlap)==0,"the camera is inside the sill")
		until os.clock()>deadline
		driver.input:simulate("Forward",false)
	end)
	check("Focus toggle respects cancel ownership and ends off surface",function()
		local player=game:GetService("Players").LocalPlayer
		driver.place(Vector3.new(-22,0.31,6)); wait(0.2)
		player:SetAttribute("FocusToggle",true)
		driver.input:simulate("Focus",true); driver.input:simulate("Focus",false); wait(0.1)
		assert(driver.focusState.latched,"toggle did not latch")
		driver.input:simulate("Jump",true); wait(0.3)
		driver.input:simulate("Cancel",true); driver.input:simulate("Cancel",false); wait(0.1)
		assert(driver.focusState.latched,"aim cancel also cleared Focus")
		driver.input:simulate("Jump",false); wait(0.1)
		driver.input:simulate("Cancel",true); driver.input:simulate("Cancel",false); wait(0.1)
		assert(not driver.focusState.latched,"idle cancel did not clear Focus")
		driver.input:simulate("Focus",true); driver.input:simulate("Focus",false)
		driver.input:simulate("Jump",true); RunService.Heartbeat:Wait(); driver.input:simulate("Jump",false)
		assert(untilState(function(s) return s.mode=="air" end,1))
		assert(not driver.focusState.latched,"Focus remained latched in air")
		player:SetAttribute("FocusToggle",false)
	end)
	check("live client sensor and drawer classify the labeled stage marker",function()
		assert(driver.stage,"test stage missing")
		driver.input:clear(); driver.sensor:reset(); driver.memory:clear()
		driver.stage.target.frozen=true
		driver.stage.target.position=Vector3.new(-28,2.8,-10)
		driver.stage.target.velocity=Vector3.zero
		driver.place(Vector3.new(-26,2.31,-3.5))
		local d=driver.stage.target.position-driver.motor.pos
		driver.motor.heading=Vector3.new(d.X,0,d.Z).Unit
		driver.camera:snap()
		assert(untilState(function() local c=driver.memory:getContact(driver.sensor:trackIdFor("test_target")); return c and c.category=="fly_like_prey" end,4),"no classified client contact")
		wait(0.2)
		local v=driver.perceptionHud.view
		assert(v and #v.labels>0 and v.labels[1].text=="fly-like prey","drawer has no classification")
		driver.stage.target.frozen=false
	end)
 check("live hunt catches at the swept contact, grips and eats without locking movement",function()
  driver.prey.enabled=true
  driver.place(Vector3.new(-21,0.31,6));wait(.2)
  local f=driver.prey.flies[1];f.enabled=false
  f.position=driver.motor.pos+driver.motor.heading*.9;f.prevPosition=f.position;f.state='PERCHED';f.velocity=Vector3.zero
  driver.input:simulate("Jump",true);RunService.Heartbeat:Wait();driver.input:simulate("Jump",false)
  assert(untilState(function()return driver.prey.feeding.struggling end,3),"no capture from real hop")
  local feed=driver.prey.feeding;local grip=feed.grip
  driver.input:simulate("Jump",true);wait(.1);driver.input:simulate("Jump",false)
  assert(feed.grip>grip-.08,"tap did not add grip")
  game:GetService("Players").LocalPlayer:SetAttribute("AutomaticGrip",true)
  assert(untilState(function()return not feed.struggling end,15),"automatic grip never subdues")
  assert(feed.held==f,"automatic grip lost fly")
  assert(untilState(function()return f.state=='CONSUMED' end,6),"did not finish meal")
  assert(feed.taken>=.349 and feed.granted<=feed.taken+1e-9,"nutrition accounting") -- the reserve records what it rose by (ROBLOX-24)
  game:GetService("Players").LocalPlayer:SetAttribute("AutomaticGrip",false)
 end)
 check("LIFE: E in the crack rests and keeps a checkpoint; an evening rest sleeps to morning; the light and the eyes follow",function()
  local life=driver.life
  driver.input:clear();driver.place(Vector3.new(-25.5,0.31,6));wait(.3)
  life.clock.hour=12
  driver.input:simulate("Feed",true);RunService.Heartbeat:Wait();driver.input:simulate("Feed",false);wait(.2)
  assert(life.resting,"E did not rest in the crack")
  assert(driver.checkpoints:loadBest().ok,"no checkpoint kept: "..life.notice)
  driver.input:simulate("Feed",true);RunService.Heartbeat:Wait();driver.input:simulate("Feed",false);wait(.2)
  assert(not life.resting,"E again did not end the rest")
  local Lighting=game:GetService("Lighting");local dayClock=Lighting.ClockTime;local dayBrightness=Lighting.Brightness
  life.clock.hour=19.5
  driver.input:simulate("Feed",true);RunService.Heartbeat:Wait();driver.input:simulate("Feed",false)
  local darkest,reach=1e9,1;local day=life.clock.day
  local deadline=os.clock()+20
  repeat RunService.Heartbeat:Wait();darkest=math.min(darkest,Lighting.Brightness);reach=math.min(reach,driver.sensor.core.rangeScale)
  until (life.clock.day==day+1 and not life.asleep) or os.clock()>deadline
  assert(life.clock.day==day+1 and math.abs(life.clock.hour-7)<.05,`no morning (day {life.clock.day}, {life.clock.hour})`)
  assert(darkest<dayBrightness*.5 and reach<=.31,`night was not dark or near-sighted (brightness {darkest}, reach {reach})`)
  print("PORT_LIFE_NIGHT "..HttpService:JSONEncode({evidence_id=workspace:GetAttribute("PortEvidence"),day_clock=dayClock,darkest_brightness=darkest,least_reach=reach}))
 end)
 check("LIFE: Backspace returns to the checkpoint; the world goes back with the spider",function()
  local life=driver.life;assert(driver.checkpoints:loadBest().ok,"no checkpoint") -- the morning's (the last rest's) checkpoint
  driver.input:simulate("Forward",true);wait(1.5);driver.input:simulate("Forward",false);wait(.3)
  assert(not life.resting,"still resting after walking")
  driver.input:simulate("Reset",true);RunService.Heartbeat:Wait();driver.input:simulate("Reset",false);wait(.3)
  assert(life.resting and driver.lifeSpider().inRetreat,"not back resting in the crack")
  assert(string.find(life.notice,"checkpoint recovery",1,true),life.notice)
  driver.input:simulate("Feed",true);RunService.Heartbeat:Wait();driver.input:simulate("Feed",false);wait(.2)
  life.clock.hour=12
 end)
 check("A029 live sensor cost with three and six moving flies",function()
  local prey=driver.prey;prey.enabled=true
  driver.place(Vector3.new(-18,0.31,6));driver.motor.heading=Vector3.xAxis;driver.camera:snap()
  if driver.stage then driver.stage.target.enabled=false;driver.stage.marker.Transparency=1 end
  local samples={}
  for _,count in {3,6} do
   while #prey.flies<count do
    local added=false
    for _,p in prey.graph.perches do if p.valid and p.occupant=='' and p.reserved=='' then prey:spawn(p);added=true;break end end
    assert(added,"not enough free perches for six-fly measurement")
   end
   while #prey.flies>count do local f=table.remove(prey.flies);f.flight:release();if f.perch.occupant==f.id then f.perch.occupant='' end end
   prey.population.target=count
   wait(.5);driver.sensor:resetCost();local ticks=driver.sensor.cpuTicks;local rays=driver.sensor.raysTotal;local checks=driver.sensor.checksTotal
   local frames={};local deadline=os.clock()+8
   repeat local dt=RunService.Heartbeat:Wait();table.insert(frames,dt*1000) until os.clock()>=deadline
   table.sort(frames);local n=driver.sensor.cpuTicks-ticks
   table.insert(samples,{flies=count,ticks=n,candidates_per_tick=(driver.sensor.checksTotal-checks)/math.max(1,n),rays_per_tick=(driver.sensor.raysTotal-rays)/math.max(1,n),
    sensor_p50_us=driver.sensor:costPercentile(.5),sensor_p95_us=driver.sensor:costPercentile(.95),frame_p50_ms=frames[math.ceil(#frames*.5)],frame_p95_ms=frames[math.ceil(#frames*.95)]})
   assert(n>120,"too few measured ticks")
  end
  print("PORT_PREY_COST "..HttpService:JSONEncode({evidence_id=workspace:GetAttribute("PortEvidence"),samples=samples,source="live client; no screenshots during timing"}))
 end)
 check("WASP: live arrival hum loads, search stays safe in crack, and audio ends with visit",function()
  driver.input:clear();driver.place(Vector3.new(-25.5,0.31,6));wait(.3)
  local wasp=driver.wasp;wasp:clearVisit()
  assert(wasp:force(driver.life.clock.day,"floor_middle"),"could not force visit")
  RunService.Heartbeat:Wait()
  local root=workspace:FindFirstChild("WindowsillAudio")
  local hum=root and root:FindFirstChild("wasp",true)
  assert(hum and hum:IsA("Sound"),"wasp sound missing")
  -- The sound is updated by BindToRenderStep; one Heartbeat can run before it.
  -- Give that real callback a bounded chance, still well inside the 8-second warning.
  local onset=os.clock()+1
  while not hum.Playing and os.clock()<onset do RunService.Heartbeat:Wait() end
  assert(hum.Playing,"arrival hum not playing within one second")
  local deadline=os.clock()+20
  repeat RunService.Heartbeat:Wait() until hum.IsLoaded or os.clock()>deadline
  assert(hum.IsLoaded and hum.TimeLength>0,"wasp recording not loaded: permissions/moderation/network")
  local frames={};deadline=os.clock()+8
  repeat local dt=RunService.Heartbeat:Wait();table.insert(frames,dt*1000) until os.clock()>deadline
  table.sort(frames)
  assert(not driver.motor.seized,"spider caught inside safe crack")
  print("PORT_WASP_COST "..HttpService:JSONEncode({evidence_id=workspace:GetAttribute("PortEvidence"),
   samples=#frames,frame_p50_ms=frames[math.ceil(#frames*.5)],frame_p95_ms=frames[math.ceil(#frames*.95)],
   phase=wasp.phase,audio_loaded=hum.IsLoaded,source="live wasp visit; no screenshots during timing"}))
  wasp:clearVisit();RunService.Heartbeat:Wait();RunService.Heartbeat:Wait()
  assert(not hum.Playing,"hum continued after visit")
 end)
 driver.wasp:clearVisit() -- also clean up after an assertion failure
 check("PEACOCK: change while resting, dance without moving physics, walk to stop, and return to first spider",function()
  local function press(action)
   driver.input:simulate(action,true);RunService.Heartbeat:Wait();driver.input:simulate(action,false);wait(.15)
  end
  driver.input:clear();driver.place(Vector3.new(-25.5,.31,6));wait(.4)
  driver.life.clock.hour=12
  if not driver.life.resting then press("Feed") end
  assert(driver.life.resting and not driver.life.asleep,"not resting awake")
  press("Choose")
  assert(driver.appearance()=="maratus_volans_male","choice did not select peacock")
  press("Feed")
  driver.place(Vector3.new(-18,.31,6));wait(.5)
  local before=driver.motor.pos
  press("Display");wait(5)
  assert(driver.dance().active and driver.rig().dance.fanOpen>.9,"dance fan did not open")
  assert((driver.motor.pos-before).Magnitude<.02,"dance changed physics position")
  wait(9) -- let Nathan see one full loop
  driver.input:simulate("Forward",true);wait(.3);driver.input:simulate("Forward",false);wait(.3)
  assert(not driver.dance().active and driver.rig().dance==nil,"walking did not stop/fade the pose")
  driver.place(Vector3.new(-25.5,.31,6));wait(.4)
  if not driver.life.resting then press("Feed") end
  press("Choose")
  assert(driver.appearance()=="first_spider","first spider was not restored")
  if driver.life.resting then press("Feed") end
 end)

 check("REST entrance: walk under the roof from outside and press rest",function()
  assert(driver.fresh("main",false,nil))
  driver.motor:place(Vector3.new(-22,.31,6),Vector3.yAxis,-Vector3.xAxis);driver.camera:snap();wait(.3)
  driver.input:simulate("Forward",true)
  local elapsed=0
  while elapsed<4 and driver.motor.pos.X>-24 do elapsed+=RunService.Heartbeat:Wait() end
  driver.input:simulate("Forward",false);wait(.3)
  assert(driver.lifeSpider().inRetreat,"walk did not reach retreat: "..tostring(driver.motor.pos))
  driver.input:simulate("Feed",true);wait(.1);driver.input:simulate("Feed",false);wait(.2)
  assert(driver.life.resting and driver.currentStore():loadBest().ok,"rest/checkpoint did not work after walking in")
 end)
 check("LIFE end: starvation, last rest, then unrelated new spider",function()
  driver.needs.starvingStreakH=48;wait(.2)
  assert(driver.caughtPanel:isShowing() and driver.session.ended,"starvation did not end")
  local hour=driver.life.clock.hour;wait(5)
  assert(driver.life.clock.hour==hour,"world not paused")
  assert(driver.caughtPanel:choose("Back"));wait(.2)
  assert(not driver.session.ended and driver.needs.starvingStreakH<48,"rest did not revive")
  driver.endLife("wasp");wait(5)
  assert(driver.caughtPanel:choose("Another"));wait(.3)
  assert(not driver.session.ended and driver.life.clock.day==1 and not driver.currentStore():loadBest().ok)
  assert(string.find(driver.life.notice,"not related",1,true),"no unrelated line")
 end)
 check("LIFE menu: large text, controller focus, gentle free play",function()
  driver.openMenu();driver.menu:setTextScale(1.5);wait(.2)
  local selected=driver.menu.selected;driver.menu:select(1)
  assert(driver.menu.selected~=selected,"focus did not move")
  for _,b in driver.menu.buttons do assert(b.TextFits,"large menu text clipped: "..b.Text) end
  assert(driver.menu:choose("Free"));wait(.3)
  assert(driver.needs.gentle and driver.wasp.gentle and driver.session.mode=="free")
  driver.endLife("wasp");assert(not driver.caughtPanel:isShowing(),"gentle ended")
  driver.needs:addHours(400,false);wait(.7);assert(driver.needs.energy>=.1-1e-9)
  assert(driver.fresh("main",false,nil))
 end)
 check("GROWTH: three safe moults, old skins, Easy and checkpoint recovery",function()
  assert(driver.fresh("main",false,nil));driver.place(Vector3.new(-25.5,.31,6));wait(.3)
  driver.life.clock.hour=12
  local samples={}
  local conn=RunService.Heartbeat:Connect(function(dt) table.insert(samples,dt) end)
  local function press(key)
   driver.input:simulate(key,true);wait(.08);driver.input:simulate(key,false);wait(.12)
  end
  for stage=1,3 do
   if driver.life.resting then press("Feed") end
   -- A staged meal credit; the production loop must read the ledger, not a test-only growth hook.
   driver.needs.energy=0
   assert(driver.needs:grantEnergy(.9,"growth_test_"..stage)>=.9-1e-9)
   wait(.1);assert(driver.life.growth.ready,"food did not ready a moult")
   press("Feed");assert(driver.life.growth:isMoulting(),"moult didn't start")
   local before=driver.motor.pos
   driver.input:simulate("Forward",true);press("Jump");press("Drop");wait(.2);driver.input:simulate("Forward",false)
   assert((driver.motor.pos-before).Magnitude<.02,"moulting spider escaped crack")
   assert(driver.rig().model:FindFirstChild("Cephalothorax").Color.R>.5,"not pale")
   local t=0
   while driver.life.growth.stage<stage and t<12 do t+=RunService.Heartbeat:Wait() end
   assert(driver.life.growth.stage==stage and #driver.life.growth.exuviae==stage,"moult did not complete once")
   assert(driver.currentStore():loadBest().ok,"grown checkpoint not kept")
   assert(driver.rig().model:GetAttribute("GrowthStage")==stage,"rig not grown")
   driver.returnToCheckpoint();wait(.15)
   assert(driver.life.growth.stage==stage and driver.life.growth:isSoft(),"checkpoint lost growth or softness")
  end
  conn:Disconnect();table.sort(samples)
  print("PORT_GROWTH_FRAME "..HttpService:JSONEncode({count=#samples,p50=samples[math.max(1,math.floor(#samples*.5))]*1000,p95=samples[math.max(1,math.floor(#samples*.95))]*1000,max=samples[#samples]*1000}))
  assert(driver.session.finishedMain,"adult did not open Easy")
  driver.openMenu();assert(driver.menu:choose("Easy"));wait(.2)
  assert(driver.menu:isShowing() and not driver.needs.gentle,"new-life confirmation skipped")
  assert(driver.menu:choose("Easy"));wait(.2)
  assert(driver.needs.gentle and driver.life.growth.stage==0,"Easy not a new gentle life")
  assert(driver.fresh("main",false,nil))
 end)
 check("NOTEBOOK: opens in the real client, the world waits, only found pages show, text fits, and it closes",function()
  local gui=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
  driver.notebook:notice("jump")
  local elapsed=driver.life.elapsed
  driver.openNotebook("game");wait(.3)
  local sg=gui:FindFirstChild("SpiderNotebook")
  assert(sg and sg:IsA("ScreenGui") and sg.Enabled,"notebook not shown")
  assert(driver.notebookPanel:isShowing(),"panel not open")
  assert(driver.life.elapsed==elapsed,"world ran under the notebook")
  local found=#driver.notebook:list()
  assert(found>=1,"no found page")
  for _,d in sg:GetDescendants() do
   if d:IsA("TextLabel") and d.Visible and d.Text~="" and d.AbsoluteSize.X>0 then
    assert(d.TextBounds.X<=d.AbsoluteSize.X+1,"notebook text spills: "..d.Name)
   end
  end
  driver.notebookPanel:close();wait(.2)
  assert(not sg.Enabled,"notebook did not close")
 end)
 check("NOTEBOOK: earned discoveries survive recovery and new lives",function()
  local b=driver.notebook
  assert(b:isOpen("dragline") and b:isOpen("retreat") and b:isOpen("peacock_dance"),"play didn't open jump/rest/dance pages")
  assert(b:isOpen("new_skin") and b:isOpen("grown_up"),"moult events not wired")
  local before=table.concat(b.opened,",")
  driver.returnToCheckpoint();wait(.1)
  assert(table.concat(b.opened,",")==before,"checkpoint erased discoveries")
  assert(driver.fresh("free",false,nil));wait(.1)
  assert(table.concat(b.opened,",")==before,"mode/new life erased discoveries")
  assert(driver.fresh("main",false,nil))
 end)
 check("NOTEBOOK: modal reading, controller scrolling, large text and return to menu",function()
  local pg=game:GetService("Players").LocalPlayer
  pg:SetAttribute("LargeText",true)
  driver.openMenu();assert(driver.menu:choose("Notebook"));wait(.3)
  local p=driver.notebookPanel
  assert(p:isShowing() and not driver.menu:isShowing(),"menu/notebook pause ownership")
  local hour=driver.life.clock.hour;local point=driver.motor.pos
  driver.input:simulate("Jump",true);driver.input:simulate("Forward",true);wait(.3)
  driver.input:simulate("Jump",false);driver.input:simulate("Forward",false)
  assert(driver.life.clock.hour==hour and (driver.motor.pos-point).Magnitude<1e-5,"reading didn't pause world")
  assert(p.text.TextSize==29 and p.sources.Text~="","missing large sourced text")
  assert(game:GetService("GuiService").SelectedObject==nil,"GUI navigation steals reading directions")
  assert(p.page.AbsoluteWindowSize.Y>60,"no readable area")
  p:scrollBy(100000);wait(.1)
  assert(p.page.CanvasPosition.Y>0,"long page can't scroll to sources")
  p:step(-1);wait(.1);assert(p.page.CanvasPosition.Y==0,"new page kept old scroll")
  for _,button in p.buttons do assert(button.TextFits,"notebook button clipped") end
  p:close();wait(.1)
  assert(driver.menu:isShowing() and driver.life.clock.hour==hour,"didn't return to paused life menu")
  assert(driver.menu:choose("Resume"));wait(.15)
  pg:SetAttribute("LargeText",false)
  driver.openNotebook();wait(.1);p:close();wait(.15)
  assert(not driver.menu:isShowing() and driver.life.clock.hour>hour,"direct notebook didn't resume")
 end)
 check("NOTEBOOK: optional checklist, end-screen return and compact footer",function()
  local player=game:GetService("Players").LocalPlayer
  player:SetAttribute("LargeText",true)
  driver.openNotebook("game");wait(.2)
  local p=driver.notebookPanel
  p:showChecklist();wait(.2)
  assert(p.shown=="_checklist" and string.find(p.text.Text,"[x] Change",1,true),"earned dance missing from checklist")
  assert(not p.sources.Visible and not p.empty.Visible,"checklist pretending to be a sourced fact")
  assert(string.find(p.text.Text,"dance outside",1,true),"last invitation absent")
  local full=game:GetService("TextService"):GetTextSize(p.text.Text,p.text.TextSize,p.text.Font,Vector2.new(p.text.AbsoluteSize.X,100000))
  assert(p.text.AbsoluteSize.Y>=full.Y,"checklist label clips later invitations")
  assert(p.text.TextFits,"complete checklist does not fit its scrolling label")
  for _,b in {p.tryButton,p.closeButton,p.backButton} do
   if b.Visible then
    assert(b.TextFits,"footer text clips: "..b.Text)
    assert(b.AbsolutePosition.X>=p.paper.AbsolutePosition.X and b.AbsolutePosition.X+b.AbsoluteSize.X<=p.paper.AbsolutePosition.X+p.paper.AbsoluteSize.X+1,"footer outside paper")
   end
  end
  p:close();wait(.1);driver.endLife("wasp");wait(5)
  assert(driver.caughtPanel:choose("Notebook"));wait(.2)
  assert(p:isShowing() and not driver.caughtPanel:isShowing(),"end screen did not open book")
  p:close();wait(.2)
  assert(driver.caughtPanel:isShowing() and driver.session.ended,"book did not return to end screen")
  assert(driver.caughtPanel:choose("Another"));wait(.2)
  player:SetAttribute("LargeText",false)
 end)
 local passed=0
	for _,row in rows do if row.passed then passed+=1 end end
	print("PORT_CLIENT_REPORT "..HttpService:JSONEncode({evidence_id=workspace:GetAttribute("PortEvidence"),tests=#rows,passed=passed,failed=#rows-passed,results=rows}))
	print("PORT_CLIENT_SUMMARY "..HttpService:JSONEncode({evidence_id=workspace:GetAttribute("PortEvidence"),tests=#rows,passed=passed,failed=#rows-passed}))
	driver.input:clear()
	-- Staged adult peacock portrait for visual inspection, after the reports. Test place only.
 driver.place(Vector3.new(-25.5,.31,6));driver.life.clock.hour=12;wait(.3)
 driver.input:simulate("Feed",true);wait(.1);driver.input:simulate("Feed",false);wait(.2)
 if driver.appearance()~="maratus_volans_male" then driver.changeSpider() end
 driver.life:stopRest();driver.life.growth.stage=3;driver.life.growth.softHoursLeft=0
 driver.place(Vector3.new(-18,.31,6));driver.motor.heading=Vector3.xAxis;driver.camera:snap()
 driver.camera.yaw+=math.pi;driver.camera.elevation=math.rad(22);driver.camera.distance=4
 wait(.3);driver.input:simulate("Display",true);wait(.1);driver.input:simulate("Display",false)
end
