--!strict
-- Optional intraguild predator. Timings/reward are game tuning, not species measurements.
-- Plain state lives in LifeLoop's checkpoint graph; no clock, engine instance or hidden player tracking.
local M=require(script.Parent.Parent.Prey.PreyMath)
local Rival={}
Rival.FOOD=.7 -- two housefly-equivalent meals
local states={dormant=true,patrol=true,stalk=true,windup=true,lunge=true,recover=true,captured=true,consumed=true}
function Rival.new(): any
 return {state="dormant",position=Vector3.new(25,.31,8),previous=Vector3.new(25,.31,8),heading=-Vector3.xAxis,
  elapsed=0,notice=0,food=Rival.FOOD,target=Vector3.new(25,.31,8),origin=Vector3.new(25,.31,8),patrol=0}
end
function Rival.valid(r: any): boolean
 if r==nil then return true end
 if type(r)~="table" or not states[r.state] then return false end
 for _,k in {"elapsed","notice","food","patrol"} do
  local n=r[k];if type(n)~="number" or n~=n or n<0 or n==math.huge then return false end
 end
 if r.food>Rival.FOOD+1e-8 then return false end
 for _,k in {"position","previous","heading","target","origin"} do
  local v=r[k];if typeof(v)~="Vector3" and type(v)~="table" then return false end
  if type(v.X)~="number" or type(v.Y)~="number" or type(v.Z)~="number" or type(v.Magnitude)~="number" or v.X~=v.X or v.Y~=v.Y or v.Z~=v.Z or v.Magnitude>1000 then return false end
 end
 return true
end
local function phase(r: any,s: string) r.state=s;r.elapsed=0 end
-- blocked(a,b) is the same opaque-world sight query as flies use. Player input is a snapshot of this fixed tick.
-- Returns an event and the amount swallowed; the caller owns food grants and end-of-life presentation.
function Rival.step(r: any,dt: number,s: any,blocked: (Vector3,Vector3)->any): (string,number)
 if dt<=0 or dt~=dt then return "",0 end
 dt=math.min(dt,.05);r.previous=r.position
 if r.state=="consumed" then return "",0 end
 if r.state=="captured" then
  r.position=s.position+s.heading*.4;r.heading=s.heading
  if not s.grounded or s.moving then return "paused",0 end
  local food=math.min(r.food,.14*dt);r.food=math.max(0,r.food-food)
  if r.food<=1e-8 then r.food=0;phase(r,"consumed");return "eaten",food end
  return "feeding",food
 end
 if r.state=="dormant" then
  if s.day<2 or s.meals<1 or (s.position-r.position).Magnitude<8 or s.resting or s.wasp then return "",0 end
  phase(r,"patrol")
 end
 -- Never stack two attackers or pursue into the retreat. No hidden-target chase.
 if s.safe or s.resting or s.wasp then phase(r,"recover");r.notice=0;return "",0 end
 r.elapsed+=dt
 local delta=s.position-r.position
 local visible=delta.Magnitude<8 and math.abs(delta.Y)<1.5 and not blocked(r.position,s.position)
 if s.striking and not s.holding and r.state~="lunge" then
  local _,d=M.sweepClosest(s.previous,s.position,r.previous,r.position)
  if d<.65 and not blocked(s.position,r.position) then phase(r,"captured");return "captured",0 end
 end
 if r.state=="lunge" then
  local k=math.clamp(r.elapsed/.4,0,1)
  local next=r.origin:Lerp(r.target,k)+Vector3.yAxis*(.35*4*k*(1-k))
  if blocked(r.position,next) then phase(r,"recover");return "missed",0 end
  r.position=next
  local _,d=M.sweepClosest(s.previous,s.position,r.previous,r.position)
  if d<.6 and not blocked(r.position,s.position) then
   phase(r,"recover");return if s.gentle then "touch" else "caught",0
  end
  if k>=1 then r.position=Vector3.new(r.position.X,.31,r.position.Z);phase(r,"recover") end
 elseif r.state=="windup" then
  if not visible or s.airborne or s.onLine then phase(r,"recover");return "missed",0 end
  if r.elapsed>=1 then
   r.origin=r.position;r.target=Vector3.new(math.clamp(s.position.X,18,28),.31,math.clamp(s.position.Z,3,10.8))
   phase(r,"lunge")
  end
 elseif r.state=="recover" then
  r.position=Vector3.new(r.position.X,.31,r.position.Z)
  if r.elapsed>=3 then phase(r,"patrol") end
 else
  r.notice=if visible then math.min(1,r.notice+dt) else math.max(0,r.notice-dt*2)
  if visible and r.notice>=.6 then
   phase(r,"stalk")
   local flat=Vector3.new(delta.X,0,delta.Z)
   if flat.Magnitude>.01 then r.heading=flat.Unit end
   if flat.Magnitude<2.5 then phase(r,"windup");return "warning",0 end
  elseif not visible then r.state="patrol" end
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
 if r.state=="dormant" or r.state=="captured" or r.state=="consumed" then return nil end
 return {id="rival_spider",position=r.position,radius=.45,velocity=(r.position-r.previous)*60,maxCategory="movement"}
end
return Rival
