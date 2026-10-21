local Gait=require("../src/Shared/Rig/DogGait")
local Environment=require("../src/Shared/World/Environment")
local passed,failed=0,0
local function check(ok,msg) if ok then passed+=1 else failed+=1;print("FAIL DOG_GAIT "..msg) end end
local function ground(at) return Vector3.new(at.X,0,at.Z) end
local function near(a,b) return (a-b).Magnitude<1e-5 end
local function finite(p) return p.X==p.X and p.Y==p.Y and p.Z==p.Z and p.Magnitude<1e6 end
local g=Gait.new();local previous={};local swings,plants=0,0
for frame=0,1200 do
 local at=Vector3.new(0,0,-frame/60*140)
 local pose=Gait.step(g,CFrame.lookAt(at,at-Vector3.zAxis),1/60,ground,false)
 check(pose.supported,"flat-ground gait is supported")
 for i,f in pose.feet do
  check(finite(f.knee) and finite(f.ankle),"finite articulated joints")
  check(math.abs((f.knee-f.hip).Magnitude-Gait.UPPER)<1e-5,"upper bone retains length")
  check(math.abs((f.ankle-f.knee).Magnitude-Gait.LOWER)<1e-5,"lower bone retains length")
  check(near(f.ankle,f.anchor+Vector3.yAxis*3.5),"paw joins lower bone without stretching")
  if f.swing then swings+=1 else
   check(math.abs(f.anchor.Y)<1e-5,"stance paw contacts ground")
   local old=previous[i]
   if old and not old.swing then check(near(old.at,f.anchor),"stance paw does not slide in world space");plants+=1 end
  end
  previous[i]={at=f.anchor,swing=f.swing~=nil}
 end
end
check(swings>100 and plants>100,"test exercises swinging and planted phases")
-- Stopping halfway through a swing must finish it, rather than hold a paw up.
local stopFrame=CFrame.lookAt(g.previous,g.previous-Vector3.zAxis)
for _=1,60 do Gait.step(g,stopFrame,1/60,ground,false) end
for _,f in g.feet do check(f.swing==nil and math.abs(f.anchor.Y)<1e-5,"stopped dog settles every paw") end
local resets=g.resets
Gait.step(g,CFrame.new(10000,0,0),1/60,ground,false)
check(g.resets==resets+1,"a load/teleport resets stale footholds")
local missing=Gait.step(Gait.new(),CFrame.identity,1/60,function() return nil end,false)
check(not missing.supported,"missing ground is not treated as an invisible floor")
local quiet=Gait.new()
for frame=0,120 do
 local pose=Gait.step(quiet,CFrame.new(frame*.1,0,0),1/60,ground,true)
 for _,f in pose.feet do check(f.swing==nil and math.abs(f.anchor.Y)<1e-5,"reduced motion has no lift or step cycle") end
end
for _,delta in {Vector3.zero,Vector3.xAxis,Vector3.yAxis*100,-Vector3.zAxis*25} do
 local knee,ankle=Gait.joint(Vector3.zero,delta,Vector3.xAxis)
 check(finite(knee) and finite(ankle),"degenerate reach/pole produces finite joints")
end
-- Route orientation should turn during the sniff stop, not snap at a segment boundary.
local last=Environment.dog(0,0).heading;local worst=0
for frame=1,60*60 do
 local nextPose=Environment.dog(frame/60,0)
 worst=math.max(worst,math.acos(math.clamp(last:Dot(nextPose.heading),-1,1)))
 last=nextPose.heading
end
check(worst<.08,"route turns continuously across the sniff stop")
local wander={};local lastPos=nil;local waited=false;local resumed=false;local restingAt=nil
for frame=0,2400 do
 local wet=if frame<1200 then 1 else 0
 local pose=Environment.stepDog(wander,frame/60,wet)
 if lastPos then check((pose.position-lastPos).Magnitude<2.34,"rain/release follows route without a shortcut or teleport") end
 if pose.rainRest then waited=true;restingAt=restingAt or pose.position;check(near(pose.position,restingAt),"rain rest stays at the reached stop") end
 if frame>1300 and restingAt and (pose.position-restingAt).Magnitude>1 then resumed=true end
 lastPos=pose.position
end
check(waited and resumed,"rain stop ends when weather clears")
print(`DOG_GAIT passed={passed} failed={failed} planted={plants} swing={swings}`)
if failed>0 then error("dog gait failed") end
