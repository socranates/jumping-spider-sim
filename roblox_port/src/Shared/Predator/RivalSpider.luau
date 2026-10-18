--!strict
-- Intraguild predator, one at a time on the eastern sill: present in every life from the first day it is allowed (Data/RivalRules), and a new one
-- arrives on the morning after one is eaten (ROBLOX-67). Timings/reward are game tuning, not species measurements.
-- Plain state lives in LifeLoop's checkpoint graph; no clock, engine instance or hidden player tracking.
-- ROBLOX-73: the spider's strike catches a rival that has not seen it coming outright, but a rival that has (stalking, winding up, or patrolling
-- with a notice of Rules.awareNotice) is a contest: caught, sprang clear, or a counter-bite that costs energy. The draw is the rival's own stream.
local M=require(script.Parent.Parent.Prey.PreyMath)
local PreyRandom=require(script.Parent.Parent.Prey.PreyRandom)
local Rules=require(script.Parent.Parent.Data.RivalRules)
local Layout=require(script.Parent.Parent.Habitat.WindowsillLayout)
local Rival={}
local function phase(r: any,s: string) r.state=s;r.elapsed=0 end
Rival.FOOD=.7 -- two housefly-equivalent meals
local states={dormant=true,patrol=true,stalk=true,windup=true,lunge=true,recover=true,captured=true,consumed=true,taken=true}
-- "dormant" is "has not arrived yet". `day` (nil in a record from before the daily rival) is the day it was eaten, so the next one comes after it.
function Rival.new(): any
 local at=Rules.arriveAt
 return {state="dormant",position=at,previous=at,heading=-Vector3.xAxis,
  elapsed=0,notice=0,food=Rival.FOOD,target=at,origin=at,patrol=0,up=Vector3.yAxis,leg=0,contests=0}
end
-- Has it seen the spider coming (so that a strike is a contest and not a sure catch)?
function Rival.aware(r: any): boolean
 return r.state=="stalk" or r.state=="windup" or (r.state=="patrol" and r.notice>=Rules.awareNotice)
end
-- The outcome of a contest, from a stream of its own so no other draw moves: "captured", "sprang" or "counter". It depends only on the world's seed,
-- the day and `n` (how many contests this rival has had, kept in its record), so a return to a rest brings back the same outcome for the same strike.
function Rival.contest(seed: number,day: number,n: number): string
 local g=PreyRandom.new((seed*73856093+(day*1009+41)*19349663+n*83492791+12345)%2147483647)
 g:next();g:next()
 local u=g:next()
 if u<Rules.contestCaptured then return "captured" end
 if u<Rules.contestCaptured+Rules.contestSprang then return "sprang" end
 return "counter"
end
-- The next rival, in the same table (the world holds this table): a fresh one that has not yet arrived.
function Rival.renew(r: any)
 for k,v in Rival.new() do r[k]=v end
 r.day=nil
 r.fate=nil
end
-- Where the wasp may take it from (ROBLOX-70): nil unless it is on the sill, awake and free; never in the retreat.
function Rival.target(r: any): any
 if r==nil or not (r.state=="patrol" or r.state=="stalk" or r.state=="windup" or r.state=="recover") or Layout.inRetreat(r.position) then return nil end
 return {position=r.position,up=r.up or Vector3.yAxis,present=true}
end
-- The wasp has it: it hangs under the wasp and nothing else touches it.
function Rival.seize(r: any): boolean
 if r==nil or Rival.target(r)==nil then return false end
 phase(r,"taken");return true
end
-- The wasp has carried it off the sill: gone for today (food for no one), and a new one comes on a later morning like after an eaten one.
function Rival.carried(r: any,day: number)
 r.state="consumed";r.elapsed=0;r.food=0;r.day=day;r.fate="taken by the wasp"
end
function Rival.valid(r: any): boolean
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
 if r.fate~=nil and r.fate~="eaten" and r.fate~="taken by the wasp" then return false end
 if r.state=="patrol" or r.state=="stalk" or r.state=="windup" or r.state=="lunge" or r.state=="recover" then
  local p,lo,hi=r.position,Layout.PLAY_BOUNDS_MIN,Layout.PLAY_BOUNDS_MAX
  if p.X<lo.X or p.Y<lo.Y or p.Z<lo.Z or p.X>hi.X or p.Y>hi.Y or p.Z>hi.Z or Layout.inRetreat(Vector3.new(p.X,p.Y,p.Z)) then return false end
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
 dt=math.min(dt,.05);r.previous=r.position
 if r.state=="taken" then
  -- In the wasp's grip. If the wasp no longer holds it (a record returned to), it is gone: carried off.
  if s.taken then return "",0 end
  Rival.carried(r,s.day or 0);return "taken",0
 end
 if r.state=="consumed" then
  -- An old record has no day: the day it is first seen eaten is the day it was eaten. A new rival comes on a later morning.
  if r.day==nil then r.day=s.day end
  if s.day>r.day and (s.hour or Rules.arriveHour)>=Rules.arriveHour then Rival.renew(r) else return "",0 end
 end
 if r.state=="captured" then
  r.position=s.position+s.heading*.4;r.heading=s.heading
  if not s.grounded or s.moving then return "paused",0 end
  local food=math.min(r.food,.14*dt);r.food=math.max(0,r.food-food)
  if r.food<=1e-8 then r.food=0;r.day=s.day;r.fate="eaten";phase(r,"consumed");return "eaten",food end
  return "feeding",food
 end
 if r.state=="dormant" then
  if s.day<Rules.firstDay or s.meals<Rules.firstMeals or (s.hour or Rules.arriveHour)<Rules.arriveHour
   or (s.position-r.position).Magnitude<Rules.arriveDistance or s.resting or s.wasp then return "",0 end
  phase(r,"patrol")
  if s.drive then r.leg=(s.day or 0)*5 end -- a different first place to patrol to each day
 end
 -- Never stack two attackers or pursue into the retreat. No hidden-target chase.
 if s.safe or s.resting or s.wasp then phase(r,"recover");r.notice=0;return "",0 end
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
    outcome=Rival.contest(s.seed or 0,s.day or 0,r.contests or 0)
    r.contests=(r.contests or 0)+1
   end
   if outcome=="captured" then phase(r,"captured");return "captured",0 end
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
    if Layout.inRetreat(s.position) then phase(r,"recover");return "missed",0 end
    r.target=s.position
   else r.target=Vector3.new(math.clamp(s.position.X,18,28),.31,math.clamp(s.position.Z,3,10.8)) end
   phase(r,"lunge")
  end
 elseif r.state=="recover" then
  if not D then r.position=Vector3.new(r.position.X,.31,r.position.Z) end
  if r.elapsed>=3 then phase(r,"patrol") end
 else
  r.notice=if visible then math.min(1,r.notice+dt) else math.max(0,r.notice-dt*2)
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
