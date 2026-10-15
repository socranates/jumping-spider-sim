--!strict
-- Frozen FlyFlight: accelerate, sweep every step, brake for landing, reserve the destination.
local M=require(script.Parent.PreyMath)
local F={};F.__index=F
function F.new(fly: any,graph: any): any
 return setmetatable({fly=fly,graph=graph,path={},length=0,s=0,speed=0,target=nil,mode='',started=0,replans=0,blocked=0,landings=0,sweeps=0},F)
end
function F.release(self: any)
 if self.target and self.target.reserved==self.fly.id then self.target.reserved='' end
 self.target=nil
end
function F.begin(self: any,path: {Vector3},target: any,mode: string,now: number)
 local f=self.fly;local air=f.state~='PERCHED' and f.state~='ALERT'
 self:release();self.path=path;self.length=M.pathLength(path);self.s=0;self.speed=if air then f.velocity.Magnitude else 0
 self.mode=mode;self.target=target;self.started=now;self.replans=0
 if target then target.reserved=f.id end
 if f.perch and f.perch.occupant==f.id then f.perch.occupant='' end
 f.state=if mode=='flee' then (if air then 'FLEE' else 'TAKEOFF') else 'REPOSITION'
 f.stateSince=now
end
function F.step(self: any,now: number,dt: number): boolean
 local f=self.fly;local p=f.profile.flight
 if self.length<=1e-6 or #self.path<2 then self.speed=0;f.velocity=Vector3.zero;return false end
 local fast=f.state=='TAKEOFF' or f.state=='FLEE'
 local top=if fast then p.flee_speed_wu_s else p.cruise_speed_wu_s
 local targetSpeed=if self.target then M.targetSpeed(self.length-self.s,top,p.landing_speed_wu_s,p.landing_slow_wu) else top
 self.speed=M.stepSpeed(self.speed,targetSpeed,if fast then p.takeoff_accel_wu_s2 else p.cruise_accel_wu_s2,dt)
 local sn=math.min(self.length,self.s+self.speed*dt);local nextPos=M.pointAt(self.path,sn)
 self.sweeps+=1
 if not self.graph:clear(f.position,nextPos) then
  self.blocked+=1;f.velocity=Vector3.zero
  if self.target and self.replans<3 then
   self.replans+=1
   local path=self.graph:plan(f.position,Vector3.zero,self.target,if self.mode=='flee' and f.senses.hasLastSeen then f.senses.lastSeenPosition else nil)
   if path then self.path=path;self.length=M.pathLength(path);self.s=0;return false end
  end
  self:release();self.path={};self.length=0;f.state='SEEK_PERCH';return false
 end
 local delta=nextPos-f.position;f.velocity=delta/dt;f.position=nextPos;self.s=sn
 local flat=Vector3.new(delta.X,0,delta.Z)
 if flat.Magnitude>.004 then
  local desired=math.atan2(-flat.X,-flat.Z);local old=math.atan2(-f.heading.X,-f.heading.Z)
  local diff=math.atan2(math.sin(desired-old),math.cos(desired-old));local angle=old+math.clamp(diff,-math.rad(p.turn_rate_deg_s)*dt,math.rad(p.turn_rate_deg_s)*dt)
  f.heading=Vector3.new(-math.sin(angle),0,-math.cos(angle))
 end
 if f.state=='TAKEOFF' and now-f.stateSince>=p.takeoff_s then f.state='FLEE';f.stateSince=now
 elseif f.state=='FLEE' and self.target and self.length-self.s<=p.approach_wu+p.landing_slow_wu then f.state='SEEK_PERCH' end
 if self.s>=self.length-1e-4 then
  local target=self.target
  if target and (f.position-self.graph:rest(target)).Magnitude<=.06 then
   self:release();self.path={};self.length=0;self.speed=0;self.landings+=1
   f.perch=target;target.occupant=f.id;f.position=self.graph:rest(target);f.normal=target.normal;f.velocity=Vector3.zero
   f.state='PERCHED';f.stateSince=now;f.goal='rest';f.goalSince=now;f:beginStay(now);return true
  end
  self:release();self.path={};self.length=0;f.state='SEEK_PERCH'
 end
 return false
end
return F
