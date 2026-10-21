--!strict
-- Intraguild predator, one at a time on the eastern sill: present in every life from the first day it is allowed (Data/RivalRules), and a new one
-- arrives on the morning after one is eaten (ROBLOX-67). Timings/reward are game tuning, not species measurements.
-- Plain state lives in LifeLoop's checkpoint graph; no clock, engine instance or hidden player tracking.
-- ROBLOX-73: the spider's strike catches a rival that has not seen it coming outright, but a rival that has (stalking, winding up, or patrolling
-- with a notice of Rules.awareNotice) is a contest: caught, sprang clear, or a counter-bite that costs energy. The draw is the rival's own stream.
-- ROBLOX-77: a rival that was caught is held but not yet eaten: it struggles (`subdued` false) until the player has subdued it with the tapping
-- grip (Predator/RivalGrip runs that; Rival.subdue marks it) or it tears free (Rival.tearFree: back to recover, its day kept). Only a subdued rival
-- is eaten. A held rival with no `subdued` at all (a record from before) is eaten as it always was.
-- ROBLOX-91: a rival that tore free is `shaken` while it recovers: it is aware (a strike is the contest again, with its counter-bite, and not a free re-catch);
-- the mark goes at its next change of phase. The rival keeps away from a courting pair and from the mating scene (`s.courting`, `s.scene`: it recovers, like
-- the wasp's visit). The day it was eaten is a morning, not the raw day counter: a new one comes at the next 07:00 after the 07:00 it was eaten in.
local M=require(script.Parent.Parent.Prey.PreyMath)
local PreyRandom=require(script.Parent.Parent.Prey.PreyRandom)
local Rules=require(script.Parent.Parent.Data.RivalRules)
local WorldMap=require(script.Parent.Parent.World.WorldMap)
local Hut=require(script.Parent.Parent.World.Hut)
local Rival={}
local function phase(r: any,s: string) if r.state~=s then r.shaken=nil end;r.state=s;r.elapsed=0 end
Rival.FOOD=.7 -- two housefly-equivalent meals
local states={dormant=true,patrol=true,stalk=true,windup=true,lunge=true,recover=true,captured=true,consumed=true,taken=true}
-- "dormant" is "has not arrived yet". `day` (nil in a record from before the daily rival) is the day it was eaten, so the next one comes after it.
-- ROBLOX-117: where a rival arrives, and its region: the sill's east end in the test garden (Data/RivalRules; no region, as every record there has always been), the
-- hut garden's path in the preserve (World/Hut.CREATURES), with the region kept in its record (`region`: the drive walks it from region to region, Hut.ROAM).
function Rival.arriveAt(): (Vector3,string?)
 if WorldMap.world()=="preserve" then return Hut.CREATURES.rival.at,Hut.CREATURES.rival.region end
 return Rules.arriveAt,nil
end
-- The regions a rival of this world roams (nil: it keeps to its own, the sill).
function Rival.roam(): {[string]:boolean}?
 if WorldMap.world()=="preserve" then return Hut.ROAM end
 return nil
end
function Rival.new(): any
 local at,region=Rival.arriveAt()
 local r={state="dormant",position=at,previous=at,heading=-Vector3.xAxis,
  elapsed=0,notice=0,food=Rival.FOOD,target=at,origin=at,patrol=0,up=Vector3.yAxis,leg=0,contests=0,grips=0}
 if region~=nil then r.region=region end
 return r
end
-- ROBLOX-117: a record of another world's rival (a rest kept in one world and put back in the other): a preserve rival in the test garden, or a sill rival (or one of a
-- region this world has not) in the preserve. That rival is not here: this world's is a new one, yet to arrive.
function Rival.misplaced(r: any): boolean
 local _,region=Rival.arriveAt()
 if region==nil then return r.region~=nil end
 return type(r.region)~="string" or WorldMap.region(r.region)==nil
end
-- The morning an hour of the clock belongs to: the hours before 07:00 are the night of the day before.
function Rival.morning(day: number,hour: number?): number
 return if (hour or Rules.arriveHour)>=Rules.arriveHour then day else day-1
end
-- Has it seen the spider coming (so that a strike is a contest and not a sure catch)?
function Rival.aware(r: any): boolean
 return r.state=="stalk" or r.state=="windup" or (r.state=="patrol" and r.notice>=Rules.awareNotice) or (r.state=="recover" and r.shaken==true)
end
-- The outcome of a contest, from a stream of its own so no other draw moves: "captured", "sprang" or "counter". It depends only on the world's seed,
-- the day and `n` (how many contests this rival has had, kept in its record), so a return to a rest brings back the same outcome for the same strike.
-- ROBLOX-91: `gentle` (Easy, Free play) keeps ROBLOX-73's odds (Rules.contestGentle), the standard rules ROBLOX-88's harder ones.
function Rival.contest(seed: number,day: number,n: number,gentle: boolean?): string
 local g=PreyRandom.new((seed*73856093+(day*1009+41)*19349663+n*83492791+12345)%2147483647)
 g:next();g:next()
 local u=g:next()
 local captured,sprang=Rules.contestCaptured,Rules.contestSprang
 if gentle==true then captured,sprang=Rules.contestGentle.captured,Rules.contestGentle.sprang end
 if u<captured then return "captured" end
 if u<captured+sprang then return "sprang" end
 return "counter"
end
-- The player has the caught rival subdued: it can now be eaten (stay still).
function Rival.subdue(r: any): boolean
 if r==nil or r.state~="captured" then return false end
 r.subdued=true;return true
end
-- The caught rival tore free of the fangs (ROBLOX-77): it is simply gone from them and recovers where it stands, with its day, its food and its
-- contest count as they were; not a contest and no new rival. ROBLOX-91: it is `shaken` while it recovers (see Rival.aware): the next strike at it is the contest
-- again, with the counter-bite, not a free re-catch that skips both.
function Rival.tearFree(r: any): boolean
 if r==nil or r.state~="captured" then return false end
 phase(r,"recover");r.notice=0;r.subdued=nil;r.shaken=true;return true
end
-- Held and still fighting the player's grip (a held rival with no `subdued`, as in an older record, is not).
function Rival.struggling(r: any): boolean
 return r~=nil and r.state=="captured" and r.subdued==false
end
-- The next rival, in the same table (the world holds this table): a fresh one that has not yet arrived.
function Rival.renew(r: any)
 r.region=nil -- (ROBLOX-117: Rival.new gives it again where this world has one)
 for k,v in Rival.new() do r[k]=v end
 r.day=nil
 r.hour=nil
 r.fate=nil
 r.subdued=nil
 r.shaken=nil
 r.camp=nil
end
-- Where the wasp may take it from (ROBLOX-70): nil unless it is on the sill, awake and free; never in the retreat. ROBLOX-94: `region` (the sill's unless given) is the
-- region it belongs to, whose retreats it keeps out of.
function Rival.target(r: any,region: string?): any
 if r==nil or not (r.state=="patrol" or r.state=="stalk" or r.state=="windup" or r.state=="recover") or WorldMap.inRetreat(r.position,region or r.region or WorldMap.HOME)~=nil then return nil end
 return {position=r.position,up=r.up or Vector3.yAxis,present=true}
end
-- The wasp has it: it hangs under the wasp and nothing else touches it.
function Rival.seize(r: any): boolean
 if r==nil or Rival.target(r)==nil then return false end
 phase(r,"taken");return true
end
-- The wasp has carried it off the sill: gone for today (food for no one), and a new one comes on a later morning like after an eaten one. `hour` (the clock's,
-- ROBLOX-91) says which morning it belongs to; without it the day's own.
function Rival.carried(r: any,day: number,hour: number?)
 r.state="consumed";r.elapsed=0;r.food=0;r.day=day;r.hour=hour;r.fate="taken by the wasp";r.shaken=nil
end
-- ROBLOX-94: `region` is the region the rival belongs to (the sill's unless given): where it may stand is that region's bounds, outside that region's retreats.
function Rival.valid(r: any,region: string?): boolean
 if r==nil then return true end
 if type(r)~="table" or not states[r.state] then return false end
 for _,k in {"elapsed","notice","food","patrol"} do
  local n=r[k];if type(n)~="number" or n~=n or n<0 or n==math.huge then return false end
 end
 if r.food>Rival.FOOD+1e-8 then return false end
 -- ROBLOX-69: where it stands. `up` (the face under it) and `leg` (patrol places visited) are missing in older records: they mean the floor and
 -- none. It is on the sill, never in the crack.
 if r.up~=nil then
  local u=r.up
  if (typeof(u)~="Vector3" and type(u)~="table") or type(u.X)~="number" or type(u.Y)~="number" or type(u.Z)~="number"
   or u.X~=u.X or u.Y~=u.Y or u.Z~=u.Z or math.abs(u.Magnitude-1)>.05 then return false end
 end
 if r.leg~=nil and (type(r.leg)~="number" or r.leg~=r.leg or r.leg<0 or r.leg>1e9 or r.leg%1~=0) then return false end
 if r.contests~=nil and (type(r.contests)~="number" or r.contests~=r.contests or r.contests<0 or r.contests>1e9 or r.contests%1~=0) then return false end
 if r.spared~=nil and type(r.spared)~="boolean" then return false end
 if r.subdued~=nil and type(r.subdued)~="boolean" then return false end
 if r.shaken~=nil and type(r.shaken)~="boolean" then return false end
 if r.camp~=nil and (type(r.camp)~="number" or r.camp~=r.camp or r.camp<0 or r.camp>1e4) then return false end -- (ROBLOX-106: the watch by the crack)
 if r.grips~=nil and (type(r.grips)~="number" or r.grips~=r.grips or r.grips<0 or r.grips>1e9 or r.grips%1~=0) then return false end
 if r.hour~=nil and (type(r.hour)~="number" or r.hour~=r.hour or r.hour<0 or r.hour>=24) then return false end
 if r.fate~=nil and r.fate~="eaten" and r.fate~="taken by the wasp" then return false end
 -- ROBLOX-117: `region` (optional: the preserve's rival roams the hut garden) names a region of 1 to 64 characters. One this world has not is another world's rival
 -- (Rival.misplaced: a new one comes); its place is not looked at here.
 if r.region~=nil and (type(r.region)~="string" or #r.region<1 or #r.region>64) then return false end
 if r.state=="patrol" or r.state=="stalk" or r.state=="windup" or r.state=="lunge" or r.state=="recover" then
  local p,id=r.position,region or r.region or WorldMap.HOME
  if WorldMap.region(id)~=nil and (not WorldMap.inBounds(p,id) or WorldMap.inRetreat(Vector3.new(p.X,p.Y,p.Z),id)~=nil) then return false end
 end
 if r.day~=nil and (type(r.day)~="number" or r.day~=r.day or r.day<0 or r.day==math.huge) then return false end
 for _,k in {"position","previous","heading","target","origin"} do
  local v=r[k];if typeof(v)~="Vector3" and type(v)~="table" then return false end
  if type(v.X)~="number" or type(v.Y)~="number" or type(v.Z)~="number" or type(v.Magnitude)~="number" or v.X~=v.X or v.Y~=v.Y or v.Z~=v.Z or v.Magnitude>1000 then return false end
 end
 return true
end
-- blocked(a,b) is the same opaque-world sight query as flies use. Player input is a snapshot of this fixed tick.
-- Returns an event and the amount swallowed; the caller owns food grants and end-of-life presentation. The strike's contest (ROBLOX-73) returns
-- "captured", "sprang" (it got clear) or "counter" (it bit back) with, for "counter", the energy that costs (0 in the gentle modes) in place of the amount
-- swallowed. `s.seed` is the world's seed (nil: 0).
function Rival.step(r: any,dt: number,s: any,blocked: (Vector3,Vector3)->any): (string,number)
 if dt<=0 or dt~=dt then return "",0 end
 if r.state~="captured" and r.state~="taken" and Rival.misplaced(r) then Rival.renew(r) end -- (ROBLOX-117: another world's rival is not here)
 dt=math.min(dt,.05);r.previous=r.position
 if r.state=="taken" then
  -- In the wasp's grip. If the wasp no longer holds it (a record returned to), it is gone: carried off.
  if s.taken then return "",0 end
  Rival.carried(r,s.day or 0,s.hour);return "taken",0
 end
 if r.state=="consumed" then
  -- An old record has no day: the day it is first seen eaten is the day it was eaten. A new rival comes on a later morning.
  if r.day==nil then r.day=s.day end
  -- (ROBLOX-91: by morning, not by the day counter: one eaten in the small hours belongs to the night before, and one eaten just before midnight still
  -- gives way at the next 07:00.)
  if Rival.morning(s.day,s.hour)>Rival.morning(r.day,r.hour or Rules.arriveHour) then Rival.renew(r) else return "",0 end
 end
 if r.state=="captured" then
  r.position=s.position+s.heading*.4;r.heading=s.heading
  if r.subdued==false then return "struggling",0 end -- fighting the grip: nothing is eaten and no time passes toward it
  if not s.grounded or s.moving then return "paused",0 end
  local food=math.min(r.food,.14*dt);r.food=math.max(0,r.food-food)
  if r.food<=1e-8 then r.food=0;r.day=s.day;r.hour=s.hour;r.fate="eaten";phase(r,"consumed");return "eaten",food end
  return "feeding",food
 end
 if r.state=="dormant" then
  -- (`s.born` ROBLOX-91: the day before this generation began, and `s.meals` this generation's: the first day and first meal of a spiderling are protected too.)
  if s.day-(s.born or 0)<Rules.firstDay or s.meals<Rules.firstMeals or (s.hour or Rules.arriveHour)<Rules.arriveHour
   or (s.position-r.position).Magnitude<Rules.arriveDistance or s.resting or s.wasp or s.scene or s.courting then return "",0 end
  phase(r,"patrol")
  if s.drive then r.leg=(s.day or 0)*5 end -- a different first place to patrol to each day
 end
 -- Never stack two attackers or pursue into the retreat. No hidden-target chase.
 -- (ROBLOX-91: and while the spider is courting or mating, so a lunge cannot land on a pair: the rival keeps away from them.)
 if s.safe or s.resting or s.wasp or s.scene or s.courting then phase(r,"recover");r.notice=0;return "",0 end
 r.elapsed+=dt
 local delta=s.position-r.position
 -- Driven by a RivalDrive (its own motor over the whole sill): what it sees is decided ten times a second, at any height; otherwise
 -- (the CLI's floor-only checks, Godot's rule) every tick and on the floor's level.
 local D=s.drive
 local visible
 if D then visible=D.sees else visible=delta.Magnitude<8 and math.abs(delta.Y)<1.5 and not blocked(r.position,s.position) end
 if not s.striking then r.spared=nil end
 if s.striking and not s.holding and r.state~="lunge" and not r.spared then
  local _,d=M.sweepClosest(s.previous,s.position,r.previous,r.position)
  if d<.65 and not blocked(s.position,r.position) then
   local outcome="captured"
   if Rival.aware(r) then
    outcome=Rival.contest(s.seed or 0,s.day or 0,r.contests or 0,s.gentle)
    r.contests=(r.contests or 0)+1
   end
   if outcome=="captured" then phase(r,"captured");r.subdued=false;return "captured",0 end
   -- It got away from this strike: it recovers, and the rest of the same strike cannot catch it (the next one, a recovering rival, can).
   phase(r,"recover");r.spared=true
   if outcome=="counter" then return "counter",if s.gentle then 0 else Rules.counterCost end
   return "sprang",0
  end
 end
 if r.state=="lunge" then
  local k=math.clamp(r.elapsed/.4,0,1)
  local next=r.origin:Lerp(r.target,k)+(if D then r.up or Vector3.yAxis else Vector3.yAxis)*(.35*4*k*(1-k))
  if blocked(r.position,next) then phase(r,"recover");return "missed",0 end
  r.position=next
  local _,d=M.sweepClosest(s.previous,s.position,r.previous,r.position)
  if d<.6 and not blocked(r.position,s.position) then
   phase(r,"recover");return if s.gentle then "touch" else "caught",0
  end
  if k>=1 then if not D then r.position=Vector3.new(r.position.X,.31,r.position.Z) end;phase(r,"recover") end
 elseif r.state=="windup" then
  if not visible or s.airborne or s.onLine then phase(r,"recover");return "missed",0 end
  if r.elapsed>=1 then
   r.origin=r.position
   if D then
    -- At the spider's own place, wherever that is; never at the crack.
    if WorldMap.inRetreat(s.position)~=nil then phase(r,"recover");return "missed",0 end
    r.target=s.position
   else r.target=Vector3.new(math.clamp(s.position.X,18,28),.31,math.clamp(s.position.Z,3,10.8)) end
   phase(r,"lunge")
  end
 elseif r.state=="recover" then
  if not D then r.position=Vector3.new(r.position.X,.31,r.position.Z) end
  if r.elapsed>=3 then phase(r,"patrol") end
 else
  -- (ROBLOX-106: `s.noticeScale`, the standard rules' cover factor, Life/Nature.cover: halved under a leaf and when still, doubled moving in the open; absent, 1)
  local rate=if type(s.noticeScale)=="number" then s.noticeScale else 1
  r.notice=if visible then math.min(1,r.notice+dt*rate) else math.max(0,r.notice-dt*2)
  if visible and r.notice>=Rules.stalkNotice then
   phase(r,"stalk")
   local flat=if D then delta else Vector3.new(delta.X,0,delta.Z)
   if not D and flat.Magnitude>.01 then r.heading=flat.Unit end
   if flat.Magnitude<(if D then Rules.reachWu else 2.5) and (not D or D.reach) then phase(r,"windup");return "warning",0 end
  elseif not visible and not (D and r.state=="stalk" and D.remember) then r.state="patrol" end
  if D then return "",0 end -- its legs are the drive's
  local next=r.position
  if r.state=="stalk" then next+=r.heading*dt*1.1
  elseif r.state=="patrol" then
   r.patrol+=dt
   r.heading=if math.floor(r.patrol/4)%2==0 then -Vector3.xAxis else Vector3.xAxis
   next+=r.heading*dt*.45
  end
  next=Vector3.new(math.clamp(next.X,18,28),.31,math.clamp(next.Z,3,10.8))
  if not blocked(r.position,next) then r.position=next end
 end
 return "",0
end
function Rival.percept(r: any): any
 if r.state=="dormant" or r.state=="captured" or r.state=="consumed" or r.state=="taken" then return nil end
 return {id="rival_spider",position=r.position,radius=.45,velocity=(r.position-r.previous)*60,maxCategory="movement"}
end
return Rival
