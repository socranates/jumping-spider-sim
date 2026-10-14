-- Studio-only profiler, substituted for SilkPlayback in an isolated profiling place.
local Run=game:GetService("RunService")
local Http=game:GetService("HttpService")
return function(d)
 local frames={}; local phase="warmup"; local samples={warmup={},route={}}
 local connection=Run.RenderStepped:Connect(function(dt) table.insert(samples[phase],dt*1000) end)
 local function waitFor(fn,seconds)
  local limit=os.clock()+seconds
  repeat Run.Heartbeat:Wait();if fn() then return true end until os.clock()>limit
  return false
 end
 local function wait(seconds) local t=os.clock();waitFor(function()return os.clock()-t>=seconds end,seconds+1) end
 d.camera.mouse=false
 wait(5)
 phase="route"
 local fixtures={
 {Vector3.new(21.5,5.4,-0.6),Vector3.zAxis,Vector3.new(21.5,5.3,2.9),"reel"},
 {Vector3.new(21.5,5.4,-5.4),-Vector3.zAxis,Vector3.new(21.5,5.3,-8.9),"reel"},
 {Vector3.new(0.5,4.2,0.4),Vector3.zAxis,Vector3.new(0.5,4.1,2.9),"reel"},
 {Vector3.new(0.5,4.2,-3.4),-Vector3.zAxis,Vector3.new(0.5,4.1,-5.9),"reel"},
 {Vector3.new(-15,4.2,0.4),Vector3.zAxis,Vector3.new(-15,4.1,2.9),"reel"},
 {Vector3.new(-17.4,4.2,-1.5),-Vector3.xAxis,Vector3.new(-19.9,4.1,-1.5),"reel"},
 {Vector3.new(10,4.6,0.2),Vector3.zAxis,Vector3.new(10,4.5,3.2),"reel"},
 {Vector3.new(-3,4.2,0.4),Vector3.zAxis,Vector3.new(-3,4.1,2.9),"lower"},
 {Vector3.new(24,5.4,-0.6),Vector3.zAxis,Vector3.new(24,5.3,2.9),"lower"},
 {Vector3.new(-13,4.2,0.4),Vector3.zAxis,Vector3.new(-13,4.1,2.9),"release"}}
 local rows={}
 for i,f in fixtures do
  d.place(f[1]+Vector3.new(0,0.31,0));d.motor.heading=f[2];d.camera:snap()
  local p=Instance.new("Part");p.Anchored=true;p.Size=Vector3.new(1,0.4,1);p.Position=f[3]-Vector3.new(0,0.2,0);p:SetAttribute("ProfileId","leaf_dry_prototype");p.Parent=d.sill
  local plan=d.motor:planJump(f[3],Vector3.yAxis,p)
  local launched=plan.kind=="reachable" and d.motor:commit(plan);p:Destroy()
  local caught=launched and waitFor(function()return d.motor:onLine() and d.motor.silk.taut end,8)
  wait(1)
  local action=if f[4]=="reel" then "Forward" elseif f[4]=="lower" then "Back" else "Cancel"
  d.input:simulate(action,true)
  local recovered=caught and waitFor(function()return d.motor.mode=="attached" end,15)
  d.input:simulate(action,false);d.input:clear()
  table.insert(rows,{index=i,launched=launched,caught=caught,recovered=recovered})
 end
 connection:Disconnect()
 local function summary(values)
  table.sort(values);local n=#values
  return {frames=n,median=values[math.max(1,math.ceil(n*0.5))],p95=values[math.max(1,math.ceil(n*0.95))],worst=values[n]}
 end
 print("PORT_PROFILE "..Http:JSONEncode({tier=workspace:GetAttribute("Detail") or "full",viewport=tostring(workspace.CurrentCamera.ViewportSize),warmup=summary(samples.warmup),route=summary(samples.route)}))
 for _,row in rows do print("PORT_PROFILE_CASE "..Http:JSONEncode(row)) end
 d.place(Vector3.new(-22,0.31,6));d.camera.mouse=true
end
