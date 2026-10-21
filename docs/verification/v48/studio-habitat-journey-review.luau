-- Studio-only review: initial placement, then real input/motor/camera throughout each leg.
-- Three separate routes; not a claim of one unassisted life. Never ship as SilkPlayback.
return function(d)
 local Run=game:GetService("RunService");assert(Run:IsStudio())
 task.spawn(function()
  local ok,err=pcall(function()
   while not d.session.started do if d.menu:isShowing() then d.menu:choose("New") end;task.wait(.2) end
   task.wait(2.5);if d.title:holding() then d.title:skip() end;task.wait(2)
   assert(d.fresh("free",false));d.life.clock.hour=12
   local living=assert(d.world.living)
   local function onScreen(at)
    local p,on=workspace.CurrentCamera:WorldToViewportPoint(at)
    return on and p.Z>0
   end
   local function shownAnimals(pool)
    local n=0
    for _,r in pool do if r.shown and r.parts[1] and onScreen(r.parts[1].Position) then n+=1 end end
    return n
   end
   local function observe(label)
    local bugs,n=workspace:FindFirstChild("Bugs"),0
    if bugs then for _,rig in bugs:GetChildren() do
     for _,p in rig:GetDescendants() do
      if p:IsA("BasePart") and p.Transparency<1 and onScreen(p.Position) then n+=1;break end
     end
    end end
    print("[CHET_HABITAT_JOURNEY_VIEW]",d.detail,label,d.world.region.id,d.motor.pos,
     #living.grass,living.count,shownAnimals(living.fleas),shownAnimals(living.ants),shownAnimals(living.grubs),
     living.dog.shown and onScreen(living.dog.parts[1].Position),n)
   end
   local function sample(label,seconds,action)
    local regions,frames,hidden,outside,detached={},0,0,0,0
    local hiddenTime,longest,lastSample=0,0,-math.huge
    local start=os.clock()
    if action then d.input:simulate(action,true) end
    while os.clock()-start<seconds do
     local dt=Run.RenderStepped:Wait();frames+=1
     regions[d.world.region.id]=true
     if d.motor.mode~="attached" then detached+=1 end
     if not onScreen(d.motor.pos) then outside+=1 end
     if d.rig()._bodyHidden then hidden+=1;hiddenTime+=dt;longest=math.max(longest,hiddenTime) else hiddenTime=0 end
     if os.clock()-lastSample>=2 then lastSample=os.clock();observe(label) end
     assert(not d.life.lifeOver,"life ended on route "..label)
    end
    if action then d.input:simulate(action,false) end
    local names={};for id in regions do table.insert(names,id) end;table.sort(names)
    print("[CHET_HABITAT_JOURNEY_LEG]",d.detail,label,frames,hidden,outside,detached,longest,
     table.concat(names,","),d.motor.mode,d.motor.pos,d.motor.up)
    assert(d.motor.mode=="attached","route lost support: "..label)
   end
   local routes={
    {id="station-can-doorway",at=Vector3.new(116,-69.69,234),heading=Vector3.xAxis,seconds=16},
    {id="garden-west-shoulder",at=Vector3.new(-182,-84.29,-190),heading=-Vector3.xAxis,seconds=28},
    {id="path-west-shoulder-to-bench",at=Vector3.new(-108,-84.29,-450),heading=-Vector3.zAxis,seconds=28},
   }
   for _,route in routes do
    d.place(route.at);d.motor:place(route.at,Vector3.yAxis,route.heading);d.cam:snap()
    task.wait(12)
    print("[CHET_HABITAT_JOURNEY_READY]",d.detail,route.id,d.motor.mode,d.motor.pos,d.world.region.id)
    sample(route.id.."-approach",route.seconds,"Forward")
    sample(route.id.."-hold",4,nil)
   end
   print("[CHET_HABITAT_JOURNEY_DONE]",d.detail)
  end)
  d.input:clear()
  if not ok then warn("[CHET_HABITAT_JOURNEY_FAIL]",d.detail,err) end
 end)
end
