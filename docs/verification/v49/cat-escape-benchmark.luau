-- Controlled response-window benchmark, not a complete escape playthrough.
-- Same cat seed, floor stop, starting distance and outward movement. Compare
-- ordinary walking to the run speed earned after the first moult.
local Cat=require("../src/Shared/Predator/Cat")
local Motor=require("../src/Shared/Movement/SpiderMotor")
local Species=require("../src/Shared/Data/Species")
local Map=require("../src/Shared/World/WorldMap")
Map.use("preserve")
local seed=Map.seed(914,"cat")
local stop
for _,s in Cat.plan(seed,1) do
 if s.kind~="walk" and (s.spot=="rug" or s.spot=="door" or s.spot=="bowls") then stop=s;break end
end
assert(stop)
local hour=(stop.t0+stop.t1)/2
local function trial(distance,run)
 local cat=Cat.new(seed);cat:step(1/60,1,hour,nil)
 local direction=cat.heading;local origin=Cat.chest(cat)+direction*distance+Vector3.new(0,.31,0)
 cat.react="crouch";cat.reactS=0;cat.pose="crouch"
 local speed=Species.phidippus_audax_prototype.locomotion.walk_speed_wu_s*(if run then Motor.RUN_MULTIPLIER else 1)
 local struck=false
 for tick=1,60 do
  local t=tick/60
  cat:step(1/60,1,hour+t*Cat.HOUR_PER_S,{pos=origin+direction*speed*t,speed=speed,hidden=false,visible=true})
  for _,signal in cat:drainSignals() do if signal.kind=="struck" then struck=true end end
 end
 return struck
end
local walkingHits,runningHits,runOnlyEscapes=0,0,0
for i=0,30 do
 local distance=20.5+i*.1
 local walk,run=trial(distance,false),trial(distance,true)
 if walk then walkingHits+=1 end
 if run then runningHits+=1 end
 if walk and not run then runOnlyEscapes+=1 end
end
print(`CAT_ESCAPE trials=31 walk_hits={walkingHits} run_hits={runningHits} run_only_escapes={runOnlyEscapes}`)
assert(walkingHits>runningHits and runOnlyEscapes>0,"earned run must improve a real paw response window")
Map.use("test_garden")
