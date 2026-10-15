local M=require("../src/Shared/Prey/PreyMath")
local S=require("../src/Shared/Prey/FlySenses")
local Species=require("../src/Shared/Data/Species")
local ref=require("./prey_reference")
local passed=0
local function near(a,b)
 assert(math.abs(a-b)<2e-4*math.max(1,math.abs(b)),tostring(a)..' ~= '..tostring(b));passed+=1
end
local function v(a) return Vector3.new(a[1],a[2],a[3]) end
for _,r in ref.rows do
 local a,b,c,d=v(r.a),v(r.b),v(r.c),v(r.d)
 local t,dist=M.sweepClosest(a,b,c,d);near(t,r.sweep.t);near(dist,r.sweep.distance)
 near(M.apparentAngle(.3,r.dist),r.angle);near(M.bearingRate(a,b,r.dt),r.bearing)
 local gain=M.awarenessGain(r.motion,10,6,M.distanceWeight(r.dist,3,14),M.facingWeight(r.off,90,150,.12),2/3,1.5)
 near(gain,r.gain);near(M.integrateAwareness(r.aw,gain,r.dt,.35,1.5),r.aw_next);near(M.threat(r.aw,.1,1),r.threat)
 local path={a,b,c,d};near(M.pathLength(path),r.length);near((M.pointAt(path,r.s)-v(r.point)).Magnitude,0)
 near(M.distanceToPath(path,Vector3.zero),r.path_distance);near(M.targetSpeed(r.dist,15,2,1.2),r.target);near(M.stepSpeed(r.s,15,80,r.dt),r.speed)
end
local p=Species.fly_like_prototype.senses
local s=S.new(p);local clear=function()return nil end
local up=Vector3.new(0,1,0);local gaze=Vector3.new(0,0,-1)
local ev=s:update(clear,Vector3.zero,gaze,up,Vector3.new(0,0,-4),.3,0,1,.35)
assert(ev.seen and ev.gain==0);passed+=1
-- Moving the fly's own eye past a still spider must not invent spider motion.
ev=s:update(clear,Vector3.new(1,0,0),gaze,up,Vector3.new(0,0,-4),.3,1/60,1,.35)
near(ev.motion,0)
ev=s:update(clear,Vector3.new(1,0,0),gaze,up,Vector3.new(1,0,-4),.3,2/60,1,.35)
assert(ev.startle and ev.gain>0);passed+=1
local last=s.lastSeenPosition
local blocked=function(a,b)return a+(b-a)*.3 end
for i=3,100 do s:update(blocked,Vector3.zero,gaze,up,Vector3.new(i,0,-4),.3,i/60,1,.35) end
assert(s.lastSeenPosition==last and not s.evidence.seen);passed+=1
near(s.awareness,0)
local spec=require("./studio/PreySpec")
spec(function(name,fn) local ok,err=pcall(fn);assert(ok,name..": "..tostring(err));passed+=1 end)
print('PREY passed='..passed..' failed=0')
