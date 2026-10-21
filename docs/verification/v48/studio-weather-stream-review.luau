-- Studio-only Free play weather observer; no frame performance claims.
-- The rain front advances on the real life clock. Only its starting hour is set.
return function(d)
 assert(game:GetService("RunService"):IsStudio())
 task.spawn(function()
  while not d.session.started do if d.menu:isShowing() then d.menu:choose("New") end;task.wait(.2) end
  task.wait(2.5);if d.title:holding() then d.title:skip() end;task.wait(2)
  assert(d.fresh("free",false))
  local at=Vector3.new(-310,-84.29,-155)
  d.place(at);d.motor:place(at,Vector3.yAxis,Vector3.zAxis);d.cam:snap()
  task.wait(8)
  local living=assert(d.world.living)
  d.life.clock.day=1;d.life.clock.hour=12;task.wait(.8)
  local first=living.state;local previous=first
  local maxRainStep,maxCloudStep,maxWindStep=0,0,0
  local rootGap,againstWind,grassSamples=0,0,0
  local start=os.clock();local steps=0
  -- Outdoor regions slow the life clock. Observe .8 actual game hours rather
  -- than assuming the windowsill's rate (about three real minutes here).
  while previous.totalHours-first.totalHours<.8 and os.clock()-start<240 do
   task.wait(1);steps+=1
   local s=living.state
   assert(not d.caughtPanel:isShowing() and math.abs(s.hour-d.life.clock.hour)<.03,"paused weather observer")
   maxRainStep=math.max(maxRainStep,math.abs(s.rain-previous.rain))
   maxCloudStep=math.max(maxCloudStep,math.abs(s.cloud-previous.cloud))
   maxWindStep=math.max(maxWindStep,(s.wind-previous.wind).Magnitude)
   for _,row in living.grass do
    rootGap=math.max(rootGap,(row.part.CFrame:PointToWorldSpace(row.rootLocal)-row.pivot).Magnitude)
    if s.wind.Magnitude>.1 then
     local up=row.part.CFrame.UpVector
     if Vector3.new(up.X,0,up.Z):Dot(s.wind)<-.0001 then againstWind+=1 end
     grassSamples+=1
    end
   end
   previous=s
   if steps%30==0 then print("[CHET_WEATHER_STREAM_FRONT]",d.detail,steps,s.hour,s.rain,s.cloud,s.wind.Magnitude,d.motor.mode,d.life.lifeOver) end
  end
  print("[CHET_WEATHER_STREAM_TRANSITION]",d.detail,steps,first.hour,previous.hour,first.rain,previous.rain,maxRainStep,maxCloudStep,maxWindStep)
  assert(previous.rain>.8 and previous.rain-first.rain>.6 and maxRainStep<.1 and maxCloudStep<.1,"rain front did not advance smoothly")
  print("[CHET_WEATHER_STREAM_GRASS]",d.detail,grassSamples,againstWind,rootGap)
  assert(grassSamples>0 and againstWind==0 and rootGap<.001,"grass does not follow wind from planted roots")
  local function floors()
   local lo,hi=math.huge,-math.huge
   for _,r in living.rain do lo=math.min(lo,r.floor);hi=math.max(hi,r.floor) end
   return lo,hi
  end
  local beforeLo,beforeHi=floors()
  -- A temporary queryable roof imitates streamed shelter. It is not saved or published.
  local roof=Instance.new("Part");roof.Name="ChetTemporaryRainRoof";roof.Anchored=true
  roof.Size=Vector3.new(70,.5,70);roof.CFrame=CFrame.new(at+Vector3.yAxis*8)
  roof.Transparency=1;roof.CanCollide=false;roof.CanTouch=false;roof.CanQuery=true;roof.Parent=d.world.root
  local roofY=roof.Position.Y+.25
  task.wait(1.3)
  local coveredLo,coveredHi=floors()
  local leaked=0
  for _,r in living.rain do if r.part.Transparency<1 and r.part.Position.Y<=roofY+.15 then leaked+=1 end end
  roof:Destroy()
  task.wait(1.3)
  local afterLo,afterHi=floors()
  print("[CHET_WEATHER_STREAM_ROOF]",d.detail,beforeLo,beforeHi,roofY,coveredLo,coveredHi,afterLo,afterHi,leaked,d.motor.mode,(d.motor.pos-at).Magnitude,living.count)
  assert(math.abs(coveredLo-roofY)<.01 and math.abs(coveredHi-roofY)<.01 and leaked==0,"streamed roof did not shelter every rain probe")
  assert(math.abs(afterLo-beforeLo)<.01 and math.abs(afterHi-beforeHi)<.01,"unloaded roof left stale rain support")
  assert((d.motor.pos-at).Magnitude<.01,"stationary observer moved during shelter test")
  print("[CHET_WEATHER_STREAM_DONE]",d.detail)
 end)
end
