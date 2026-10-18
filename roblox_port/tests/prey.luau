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
-- The fly-catch struggle (ROBLOX-72): Godot's numbers stay Feeding's defaults; the game opts in to an easier tap (Data/Catch.game).
local F=require("../src/Shared/Prey/Feeding")
local Catch=require("../src/Shared/Data/Catch")
local PR=require("../src/Shared/Prey/PreyRandom")
local fp=Species.fly_like_prototype
-- One struggle at `rate` taps a second (the first at `from`, none inside [lapseFrom, lapseFrom + lapseLen)), a fixed 60 Hz, a seed for the fly's own draws
-- (the controller's default stream when nil). Returns { escaped, seconds, lowest grip, final grip, note }.
local function struggle(tuned: boolean,rate: number,seed: number?,from: number?,lapseFrom: number?,lapseLen: number?): any
 local f=F.new();if seed then f.rng=PR.new(seed) end
 if tuned then f:useGameRules() end
 f:capture({profile=fp,nutrition=.35,state='CAPTURED',captureKey='catch'})
 local esc,t,nextTap,low=0,0,from or 0,f.grip
 for _=1,1000 do
  t+=1/60
  local lapsed=lapseFrom~=nil and t>=lapseFrom and t<lapseFrom+(lapseLen or 0)
  if lapsed then nextTap=lapseFrom+(lapseLen or 0) end -- (it resumes where it left off, with no taps owed)
  if rate>0 and t>=nextTap and not lapsed then f:press();nextTap=math.max(nextTap+1/rate,t) end
  f:step(1/60,true,false,function() esc+=1 end)
  low=math.min(low,f.grip)
  if not f.struggling then break end
 end
 return {escaped=esc==1 and f.held==nil,seconds=t,low=low,grip=f.grip,note=f.note,subdued=f.feeding}
end
do
 -- the defaults are Godot's, bit for bit: a scripted struggle ends exactly as it did before the game's rules existed (4.5 taps a second from 0.2 s)
 local d=F.new()
 assert(d.startGrip==.4 and d.tapGain==.085 and d.jerkScale==1);passed+=1
 d:capture({profile=fp,nutrition=.35,state='CAPTURED',captureKey='k'});assert(d.grip==.4 and d.rng:next()>0);passed+=1
 local f=F.new();f:capture({profile=fp,nutrition=.35,state='CAPTURED',captureKey='k'})
 local esc,t,nextTap,grips=false,0,.2,{}
 for i=1,900 do
  t+=1/60
  if t>=nextTap then f:press();nextTap+=1/4.5 end
  f:step(1/60,true,false,function() esc=true end)
  if i%45==0 then table.insert(grips,string.format("%.17g",f.grip)) end
  if esc or not f.struggling then table.insert(grips,string.format("end@%d %.17g %s",i,f.grip,f.note));break end
 end
 assert(table.concat(grips,"|")=="0.30814906914720031|0.23727007136461867|0.17183694450317205|0.054692600292865282|0.051556275205353261|0.15372610753503657|0.12296615430443757|0.2724060579987394|0.34740605799873975|0.36240605799874054|0.52240605799874118|0.59740605799873991|0.67240605799873798|0.77240605799873596|0.78740605799873409|1|end@720 1 Subdued.",table.concat(grips,"|"));passed+=1
 -- the game's numbers, pinned
 assert(Catch.game.startGrip==.5 and Catch.game.tapGain==.12 and Catch.game.jerkScale==.8);passed+=1
 local g=F.new();g:useGameRules()
 assert(g.startGrip==.5 and g.tapGain==.12 and g.jerkScale==.8);passed+=1
 g:capture({profile=fp,nutrition=.35,state='CAPTURED',captureKey='k'});assert(g.grip==.5);passed+=1
 assert(F.new().startGrip==.4,'a new controller is still Godot');passed+=1
 -- the same taps subdue faster: five a second ends sooner (and with a higher grip all the way), over many flies
 local sooner,higher,n=0,0,0
 for seed=1,60 do
  local a,b=struggle(false,5,seed*7+1),struggle(true,5,seed*7+1)
  assert(not b.escaped,'tuned: five taps a second tore free (seed '..seed..')')
  n+=1;if b.seconds<a.seconds then sooner+=1 end;if b.low>a.low then higher+=1 end
 end
 assert(sooner==n and higher==n,'sooner '..sooner..' higher '..higher..' of '..n);passed+=1
 -- a steady three a second wins from the start with the game's numbers and loses with Godot's
 local won,lost,longest=0,0,0
 for seed=1,60 do
  local a,b=struggle(false,3,seed*7+1),struggle(true,3,seed*7+1)
  if a.escaped then lost+=1 end
  if b.subdued and not b.escaped then won+=1;longest=math.max(longest,b.seconds) end
 end
 assert(won==60 and lost==60,'three taps a second: tuned won '..won..', Godot lost '..lost);passed+=1
 assert(longest<=12.02,'the 12 s cap holds ('..longest..')');passed+=1
 -- a late start and a lapse: the first tap can come at 0.75 s and a steady four a second still wins (Godot's tears free before it); after two seconds of
 -- five a second a pause of a second and a half no longer loses the fly (a pause of a second did not, and any pause of that length lost it before)
 local late,godotLate,paused,godotPaused=0,0,0,0
 for seed=1,60 do
  if not struggle(true,4,seed*7+1,.75).escaped then late+=1 end
  if not struggle(false,4,seed*7+1,.75).escaped then godotLate+=1 end
  if not struggle(true,5,seed*7+1,0,2.0,1.5).escaped then paused+=1 end
  if not struggle(false,5,seed*7+1,0,2.0,1.0).escaped then godotPaused+=1 end
 end
 assert(late==60 and godotLate==0,'late start: tuned '..late..', Godot '..godotLate);passed+=1
 assert(paused==60 and godotPaused==0,'pause: tuned 1.5 s '..paused..', Godot 1.0 s '..godotPaused);passed+=1
 -- and still tears free when it is not held: no taps, too few taps, a long pause; it is still its note, its escape once, and no meal
 for _,rate in {0,1,2} do
  for seed=1,20 do
   local r=struggle(true,rate,seed*7+1)
   assert(r.escaped and r.note=='It tore free!' and r.grip<=0 and r.seconds<12,'tuned: '..rate..' taps a second, seed '..seed..' did not tear free');passed+=1
  end
 end
 local lapse=struggle(true,4,1,0,3.0,3.0)
 assert(lapse.escaped,'a lapse of three seconds in the middle tears free');passed+=1
 -- untouched, a fresh catch lasts a little longer: 1.0 to 1.45 s with the game's numbers (0.7 to 1.0 s with Godot's)
 local lo,hi,glo,ghi=math.huge,0,math.huge,0
 for seed=1,60 do
  local r,gr=struggle(true,0,seed*7+1),struggle(false,0,seed*7+1)
  lo,hi=math.min(lo,r.seconds),math.max(hi,r.seconds);glo,ghi=math.min(glo,gr.seconds),math.max(ghi,gr.seconds)
 end
 assert(lo>=1.0 and hi<=1.45 and glo>=.7 and ghi<=1.0,'untouched: '..lo..' to '..hi..' s (Godot '..glo..' to '..ghi..')');passed+=1
end
print('PREY passed='..passed..' failed=0')
