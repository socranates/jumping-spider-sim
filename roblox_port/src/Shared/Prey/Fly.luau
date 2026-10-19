--!strict
-- Fly's evidence-owned decisions, reactions, flights, glances and surface bursts.
-- Sources: frozen fly.gd and fly_mind.gd. Geometry and random stream are explicit dependencies.
-- ROBLOX-96: a profile whose body says `walker` (the aphid, Data/Species) never launches: `launch` refuses every flight, so FlyFlight is never used for it, and
-- startled it freezes on its perch instead of turning to face the threat. Godot's profiles have no such field, so nothing of theirs is touched.
-- ROBLOX-101: the bestiary's behaviours are Prey/PreyKinds', called only for a profile that asks: a `hop` profile flees by a ballistic hop (state HOP, stepped
-- by PreyKinds.step instead of FlyFlight) and a `flightless` one never begins a flight; a `sidestep` profile goes round its stem when watched; a profile with
-- `flight.wander_local` keeps its wander loops near the height it flew from (the sill's 0.8 to 10 band is the sill's, and the wall and the bed are far below it).
local M=require(script.Parent.PreyMath)
local S=require(script.Parent.FlySenses)
local F=require(script.Parent.FlyFlight)
local R=require(script.Parent.PreyRandom)
local K=require(script.Parent.PreyKinds)
local Fly={};Fly.__index=Fly
function Fly.new(id: string,serial: number,seed: number,perch: any,graph: any,profile: any,now: number): any
 local f:any=setmetatable({id=id,serial=serial,profile=profile,graph=graph,rng=R.new(seed),senses=S.new(profile.senses),
  position=graph:rest(perch),prevPosition=graph:rest(perch),normal=perch.normal,heading=Vector3.new(0,0,-1),velocity=Vector3.zero,
  state='PERCHED',stateSince=now,goal='rest',goalSince=now,perch=perch,fatigue=0,restlessBias=0,
  nextDecision=now+(serial*.0371)%(1/profile.behavior.decision_hz),nextGlance=now,nextWalk=now+2,nextGroom=now+6,groomUntil=0,
  walkLeft=0,burstUntil=0,pauseUntil=0,walkSpeed=0,walkDirection=Vector3.zero,pending=nil,blocked={},candidates=0,
  nutrition=profile.body.nutrition,captureSerial=0,trace={},enabled=true},Fly)
 f.flight=F.new(f,graph);perch.occupant=id;f:beginStay(now)
 return f
end
function Fly.beginStay(self: any,now: number)
 local p=self.profile.behavior
 self.perchedSince=now;self.restlessRate=p.restless_per_s*(1+p.restless_spread*(self.rng:next()*2-1))
 self.nextGroom=now+self.rng:draw(p.groom_interval_s);self.groomUntil=0
 self.nextGlance=now+self.rng:draw(p.glance_interval_s);self.glanceSign=if self.rng:next()<.5 then -1 else 1
 self.nextWalk=now+self.rng:draw(p.walk_interval_s);self.nextFidget=now+self.rng:draw(p.fidget_interval_s)
 self.homeHeading=self.heading;self.glanceTarget=nil;self.fidgetUntil=0;self.restSpot=self.position;self.walkLeft=0
end
function Fly.turn(self: any,target: Vector3,dt: number): boolean
 local tangent=target-self.normal*target:Dot(self.normal)
 if tangent.Magnitude<1e-6 then return true end
 local angle=math.atan2(self.normal:Dot(self.heading:Cross(tangent.Unit)),self.heading:Dot(tangent.Unit))
 local limit=math.rad(self.profile.flight.turn_rate_deg_s)*dt
 self.heading=CFrame.fromAxisAngle(self.normal,math.clamp(angle,-limit,limit)):VectorToWorldSpace(self.heading).Unit
 return math.abs(angle)<=limit+1e-4
end
function Fly.surface(self: any,point: Vector3): boolean
 local hit=self.graph.cast(point+self.normal*.3,point-self.normal*.3)
 return hit~=nil and hit.Normal:Dot(self.normal)>.98 and math.abs((hit.Position+self.normal*self.profile.body.hover_wu-point):Dot(self.normal))<=.06
end
function Fly.alive(self: any): boolean return self.state~='CAPTURED' and self.state~='CONSUMED' end
function Fly.airborne(self: any): boolean return self.state~='PERCHED' and self.state~='ALERT' and self:alive() end
function Fly.percept(self: any): any
 if not self:alive() then return nil end
 return {id=self.id,position=self.position,radius=self.profile.body.radius_wu,velocity=self.velocity,maxCategory='fly_like_prey'}
end
function Fly.relevance(self: any,now: number): number
 local s=self.senses;if not s.hasLastSeen then return 0 end
 local p=self.profile
 return math.clamp(1-(now-s.lastSeenTime-.4)/math.max(p.senses.threat_memory_s-.4,.1),0,1)
  *math.clamp((p.flight.safe_distance_wu*1.5-(self.position-s.lastSeenPosition).Magnitude)/p.flight.safe_distance_wu,0,1)
end
function Fly.ranked(self: any,kind: string,now: number,threat: number,relaxed: boolean?): {any}
 local p=self.profile;local origin=self.position;local list={}
 local restless=math.clamp((now-self.perchedSince)*self.restlessRate,0,1)
 for _,c in self.graph.perches do
  local d=(origin-c.position).Magnitude
  local minimum=if kind=='flee' and not relaxed then math.max(p.flight.min_hop_wu,p.flight.flee_speed_wu_s*p.flight.flee_min_s*.5) else p.flight.min_hop_wu
  local maximum=if kind=='move' then p.behavior.reposition_max_wu else p.flight.max_flight_wu
  local away=if self.senses.hasLastSeen then (c.position-self.senses.lastSeenPosition).Magnitude else p.flight.safe_distance_wu*.5
  if c.valid and c.occupant=='' and (c.reserved=='' or c.reserved==self.id) and d>=minimum and d<=maximum and (self.blocked[c.id] or 0)<=now
   and (kind~='flee' or relaxed or away>=p.flight.perch_avoid_wu) then
   self.candidates+=1
   local travel=math.clamp(d/p.flight.max_flight_wu,0,1)
   local score=if kind=='move' then M.scoreMove(p.utility,restless,math.clamp(c.food-self.perch.food,0,1),math.clamp(c.shelter-self.perch.shelter,0,1),travel,self.fatigue,threat)
    else M.scoreFlee(p.utility,threat,c.shelter,math.clamp(away/p.flight.safe_distance_wu,0,1),travel)
   table.insert(list,{perch=c,score=score})
  end
 end
 table.sort(list,function(a,b) return a.score>b.score or (a.score==b.score and a.perch.id<b.perch.id) end)
 return list
end
function Fly.choose(self: any,kind: string,now: number,threat: number,relaxed: boolean?): (any,{Vector3}?)
 local danger=if kind=='flee' and self.senses.hasLastSeen then self.senses.lastSeenPosition else nil
 for i,c in self:ranked(kind,now,threat,relaxed) do
  if i>self.profile.behavior.candidates_validated then break end
  local path=self.graph:plan(self.position,if self:airborne() then Vector3.zero else self.normal,c.perch,danger)
  if path then return c.perch,path end
  self.blocked[c.perch.id]=now+self.profile.behavior.block_retry_s
 end
 return nil,nil
end
function Fly.launch(self: any,kind: string,now: number): boolean
 if self.profile.body.walker then return false end -- (ROBLOX-96: a walker never flies)
 if self.hop then return false end -- (ROBLOX-101: in the air on a hop already)
 if kind=='flee' and self.profile.body.hop and K.hop(self,now) then return true end -- (ROBLOX-101: the escape hop first)
 if self.profile.body.flightless then return false end
 local target,path=self:choose(kind,now,if kind=='flee' then 1 else 0)
 if not path and kind=='flee' then target,path=self:choose(kind,now,1,true) end
 if not path and kind=='flee' then
  local away=if self.senses.hasLastSeen then self.position-self.senses.lastSeenPosition else self.heading
  local angle=math.atan2(away.X,away.Z)
  for i=0,7 do
   local a=angle+i*math.pi/4;local dest=self.position+Vector3.new(math.sin(a),.35,math.cos(a)).Unit*self.profile.flight.open_escape_wu
   if self.graph:clear(self.position,dest) then path={self.position,dest};break end
  end
 end
 if not path then return false end
 if kind=='move' and target and not self:airborne() and self.rng:next()<self.profile.behavior.wander_flight_chance then
  local lifted=self.position+self.normal*self.profile.flight.lift_wu
  for _=1,4 do
   local a=self.rng:next()*math.pi*2;local d=self.rng:draw({2.5,6})
   local w=lifted+Vector3.new(math.cos(a)*d,0,math.sin(a)*d)
   local rise=self.rng:draw({.5,3.5})
   w=Vector3.new(w.X,if self.profile.flight.wander_local then lifted.Y+rise else math.clamp(lifted.Y+rise,.8,10),w.Z)
   if self.graph:clear(self.position,lifted) and self.graph:clear(lifted,w) then
    local tail=self.graph:plan(w,Vector3.zero,target,nil)
    if tail then local loop={self.position,lifted};for _,point in tail do table.insert(loop,point) end
     if M.pathLength(loop)<=self.profile.flight.max_flight_wu*1.6 then path=loop;break end
    end
   end
  end
 end
 self.flight:begin(path,target,kind,now);self.goal=kind;self.goalSince=now;self.walkLeft=0
 table.insert(self.trace,{t=now,goal=kind,target=if target then target.id else 'open'});if #self.trace>80 then table.remove(self.trace,1) end
 return true
end
function Fly.schedule(self: any,now: number,startle: boolean)
 local p=self.profile.reaction
 local pair=p.delay_deliberate_s
 if startle then pair=if self.state=='ALERT' then p.delay_startle_alert_s elseif now<self.groomUntil then p.delay_startle_grooming_s else p.delay_startle_relaxed_s end
 self.pending=now+self.rng:draw(pair);self.goal='flee'
end
function Fly.think(self: any,now: number)
 local p=self.profile;local s=self.senses;local ev=s.evidence
 if ev.t==now and ev.startle and not self.pending and (self.state=='PERCHED' or self.state=='ALERT' or self.state=='SEEK_PERCH' or self.state=='REPOSITION') then self:schedule(now,true) end
 if self.state=='PERCHED' and ((s.awareness>=p.senses.awareness_alert and self:relevance(now)>=.5) or self.pending) then self.state='ALERT';self.stateSince=now;self.walkLeft=0 end
 if self.pending and now>=self.pending then self.pending=nil;self:launch('flee',now) end
 if now<self.nextDecision then return end
 self.nextDecision=now+1/p.behavior.decision_hz
 local threat=M.threat(s.awareness,p.senses.awareness_calm,p.senses.awareness_flee)*self:relevance(now)
 if self:airborne() then
  if self.state=='SEEK_PERCH' and not self.flight.target then
   if not self:launch('move',now) and self.profile.flight.home_in then K.homeIn(self,now) end -- (ROBLOX-101: no perch in reach, fly toward the nearest)
  end
  if (self.state=='REPOSITION' or self.state=='SEEK_PERCH') and not self.pending and threat>=p.behavior.interrupt_threat and ev.seen and now-ev.t<=.3 and ev.gain>0 and ev.distance<=p.flight.safe_distance_wu then self:schedule(now,false) end
  return
 end
 local scores={rest=M.scoreRest(p.utility,self.fatigue,self.perch.shelter,self.perch.food,threat)}
 local move=if self.state=='PERCHED' then self:ranked('move',now,threat) else {}
 local flee=if threat>.02 then self:ranked('flee',now,threat) else {}
 if move[1] then scores.move=move[1].score end;if flee[1] then scores.flee=flee[1].score end
 local chosen=M.pickGoal(scores,self.goal,p.behavior.hysteresis)
 if chosen~=self.goal and threat<p.behavior.interrupt_threat and now-self.goalSince<p.behavior.min_commit_s then chosen=self.goal end
 if chosen=='flee' and not self.pending then self:schedule(now,false)
 elseif chosen=='move' and not self.pending and self.state=='PERCHED' then self:launch('move',now)
 elseif chosen=='rest' and not self.pending then
  if self.goal~='rest' then self.goal='rest';self.goalSince=now end
  if self.state=='ALERT' and (s.awareness<p.senses.awareness_calm or self:relevance(now)<.25) and now-self.stateSince>=p.behavior.alert_min_s then self.state='PERCHED';self.stateSince=now end
 end
end
function Fly.rest(self: any,now: number,dt: number)
 local p=self.profile.behavior
 if self.profile.body.sidestep and K.sidestep(self,now,dt) then return end -- (ROBLOX-101: round the stem, away from the spider)
 if self.state=='ALERT' then
  self.groomUntil=0;self.fidgetUntil=0;self.glanceTarget=nil
  if self.profile.body.walker then return end -- (ROBLOX-96: a walker freezes)
  if self.senses.hasLastSeen then local d=self.senses.lastSeenPosition-self.position;local flat=d-self.normal*d:Dot(self.normal);if flat.Magnitude>.001 then self:turn(flat.Unit,dt) end end
  return
 end
 if now<self.fidgetUntil then
  local t=math.clamp((now-self.fidgetStarted)/(self.fidgetUntil-self.fidgetStarted),0,1)
  self.position=self.fidgetFrom:Lerp(self.fidgetTo,t*t*(3-2*t));return
 end
 if self.glanceTarget then if self:turn(self.glanceTarget,dt) then self.glanceTarget=nil end;return end
 if now>=self.nextGroom then self.groomUntil=now+self.rng:draw(p.groom_duration_s);self.nextGroom=self.groomUntil+self.rng:draw(p.groom_interval_s) end
 if now<self.groomUntil then return end
 if now>=self.nextGlance and self.walkLeft<=0 then
  self.glanceTarget=CFrame.fromAxisAngle(self.normal,math.rad(self.rng:draw(p.glance_angle_deg))*self.glanceSign):VectorToWorldSpace(self.homeHeading)
  self.glanceSign=-self.glanceSign;self.nextGlance=now+self.rng:draw(p.glance_interval_s);return
 end
 if now>=self.nextWalk and self.walkLeft<=0 then
  local home=self.graph:rest(self.perch)-self.position
  local direction=if home.Magnitude>p.wander_radius_wu*.5 then home.Unit else self.heading
  local angle=if home.Magnitude>p.wander_radius_wu*.5 then 40 else 100
  self.walkDirection=CFrame.fromAxisAngle(self.normal,math.rad(self.rng:draw({-angle,angle}))):VectorToWorldSpace(direction)
  local wanted=self.rng:draw(p.walk_distance_wu);self.walkLeft=0
  for distance=.15,wanted,.15 do
   local nextPos=self.position+self.walkDirection*distance
   if not self:surface(nextPos) or (nextPos-self.graph:rest(self.perch)).Magnitude>p.wander_radius_wu or not self.graph:clear(self.position,nextPos) then break end
   self.walkLeft=distance
  end
  if self.walkLeft<.2 then self.walkLeft=0 end
  self.walkSpeed=self.rng:draw(p.walk_speed_wu_s)
  self.burstUntil=now+self.rng:draw(p.walk_burst_s);self.pauseUntil=0;self.nextWalk=now+self.rng:draw(p.walk_interval_s)
 end
 if self.walkLeft>0 then
  if math.deg(math.acos(math.clamp(self.heading:Dot(self.walkDirection),-1,1)))>20 then self:turn(self.walkDirection,dt);return end
  if now<self.pauseUntil then return end
  if now>=self.burstUntil then self.pauseUntil=now+self.rng:draw(p.walk_pause_s);self.burstUntil=self.pauseUntil+self.rng:draw(p.walk_burst_s);return end
  local step=math.min(self.walkLeft,self.walkSpeed*dt);local nextPos=self.position+self.walkDirection*step
  local hit=self.graph.cast(nextPos+self.normal*.3,nextPos-self.normal*.3)
  if hit and hit.Normal:Dot(self.normal)>.98 and math.abs((hit.Position+self.normal*self.profile.body.hover_wu-nextPos):Dot(self.normal))<=.06
   and (nextPos-self.graph:rest(self.perch)).Magnitude<=p.wander_radius_wu and self.graph:clear(self.position,nextPos) then
   self.position=nextPos;self.walkLeft-=step;self.heading=self.heading:Lerp(self.walkDirection,.3).Unit
   if self.walkLeft<=.001 then self.restSpot=self.position;self.homeHeading=self.heading end
  else self.walkLeft=0 end
 elseif now>=self.nextFidget then
  local dir=CFrame.fromAxisAngle(self.normal,self.rng:next()*math.pi*2):VectorToWorldSpace(self.heading)
  local distance=self.rng:draw(p.fidget_distance_wu);local duration=self.rng:draw(p.fidget_duration_s)
  if (self.position+dir*distance-self.restSpot).Magnitude>p.perch_radius_wu and (self.restSpot-self.position).Magnitude>.001 then dir=(self.restSpot-self.position).Unit end
  local target=self.position+dir*distance
  self.nextFidget=now+duration+self.rng:draw(p.fidget_interval_s)
  if self:surface(target) and self.graph:clear(self.position,target) then
   self.fidgetFrom=self.position;self.fidgetTo=target;self.fidgetStarted=now;self.fidgetUntil=now+duration
  end
 end
end
function Fly.step(self: any,dt: number,now: number,stimulus: Vector3,radius: number,cast: any)
 self.prevPosition=self.position
 if not self:alive() or not self.enabled then return end
 local p=self.profile
 if self.senses:shouldCheck(now) then
  local vigilant=if self.state=='ALERT' then p.senses.vigilance_alert elseif now<self.groomUntil then p.senses.vigilance_grooming else p.senses.vigilance_relaxed
  self.senses:update(cast,self.position+self.normal*.1,if self:airborne() and self.velocity.Magnitude>.1 then self.velocity.Unit else self.heading,if self:airborne() then Vector3.yAxis else self.normal,stimulus,radius,now,vigilant,if self.state=='ALERT' then p.senses.decay_alert_per_s else p.senses.decay_relaxed_per_s)
 end
 self:think(now)
 if self:airborne() then if self.hop then K.step(self,now,dt) else self.flight:step(now,dt) end;self.fatigue=math.min(1,self.fatigue+p.behavior.fatigue_up_per_s*dt)
 else self:rest(now,dt);self.fatigue=math.max(0,self.fatigue-p.behavior.fatigue_down_per_s*dt) end
 if not self:airborne() and math.abs(self.heading:Dot(self.normal))>.9 then K.upright(self) end -- (ROBLOX-101: landed on a wall facing it; never on the sill's flat perches)
 self.velocity=(self.position-self.prevPosition)/dt
end
return Fly
