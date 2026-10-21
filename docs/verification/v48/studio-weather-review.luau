-- Studio-only observation of the real client weather/lighting path.
-- Clock samples and observer placement are diagnostic; not an ordinary survival run.
-- Do not use frame timings while the CLI regression is running.
return function(d)
 local Run=game:GetService("RunService");assert(Run:IsStudio())
 local Lighting=game:GetService("Lighting")
 local E=require(game.ReplicatedStorage.Shared.World.Environment)
 task.spawn(function()
  while not d.session.started do if d.menu:isShowing() then d.menu:choose("New") end;task.wait(.2) end
  task.wait(2.5);if d.title:holding() then d.title:skip() end;task.wait(2)
  assert(d.fresh("free",false),"weather review needs a fresh Free play observer")
  local living=assert(d.world.living)
  -- Lighting is deliberately applied at 2 Hz, while fauna/rain sample at 20 Hz.
  -- Compare native properties to their last applied state, not a newer gust.
  local applied=nil;local apply=living.lighting
  living.lighting=function(self,state,clock) apply(self,state,clock);applied=state end
  local function sample(label,day,hour,position)
   d.input:clear();d.life.clock.day=day;d.life.clock.hour=hour
   if position then d.place(position);d.motor:place(position,Vector3.yAxis,Vector3.zAxis);d.cam:snap() end
   task.wait(3)
   local s=assert(living.state)
   assert(not d.caughtPanel:isShowing() and math.abs(s.hour-d.life.clock.hour)<.03,"weather observer paused or stale")
   local light=assert(applied);local native=Lighting:GetSunDirection()
   local gap=math.deg(math.acos(math.clamp(native:Dot(light.solar.direction),-1,1)))
   local rain,below=0,0
   for _,r in living.rain do
    if r.part.Transparency<1 then rain+=1;if r.part.Position.Y<=r.floor+.15 then below+=1 end end
   end
   local windGap=(workspace.GlobalWind-light.wind*12).Magnitude
   print("[CHET_WEATHER_V3_SAMPLE]",label,d.detail,s.day,s.hour,s.name,s.rain,s.cloud,s.wetness,
    s.solar.altitude,gap,windGap,rain,below,d.motor.mode,d.motor.pos,d.world.region.id,d.life.lifeOver,
    Lighting.Brightness,Lighting.ExposureCompensation,living.count)
   assert(gap<.1 and windGap<.0001 and below==0,"native environment disagrees with its applied state")
   return rain
  end
  local outside=Vector3.new(-310,-84.29,-155)
  for _,entry in {{"dawn",6},{"noon",12},{"dusk",19},{"night",23}} do
   sample(entry[1],1,entry[2],outside)
  end
  local storm=nil
  for day=1,7 do for hour=9,16,.5 do
   local s=E.sample(day,hour,914)
   if s.rain>.75 then storm={day=day,hour=hour};break end
  end;if storm then break end end
  assert(storm,"no daytime storm in the diagnostic week")
  local drops=sample("rain-outside",storm.day,storm.hour,outside)
  assert(drops>0,"storm has no visible outdoor rain")
  local inside=sample("rain-inside",storm.day,storm.hour,Vector3.new(140,-69.69,238))
  assert(inside==0,"rain enters the station floor")
  sample("rain-outside-return",storm.day,storm.hour,outside)
  print("[CHET_WEATHER_V3_DONE]",d.detail)
 end)
end
