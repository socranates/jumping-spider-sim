--!strict
-- scripts/prey/fly_senses.gd, A-028. No controls, plans or velocity enter this interface.
local M=require(script.Parent.PreyMath)
local PM=require(script.Parent.Parent.Perception.PerceptionMath)
local S={};S.__index=S
function S.new(profile: any): any
 return setmetatable({p=profile,awareness=0,evidence={},hasLastSeen=false,lastSeenPosition=Vector3.zero,lastSeenTime=-1e9,
  started=false,hasLast=false,lastPoint=Vector3.zero,lastTime=-1e9,lastMask=0,lastCheck=-1e9,nextCheck=0,checks=0,rays=0},S)
end
function S.shouldCheck(self: any,now: number): boolean return now+1e-9>=self.nextCheck end
function S.finish(self: any,ev: any,now: number,dt: number,gain: number,decay: number,seen: boolean): any
 if not seen then self.hasLast=false end
 self.started=true
 self.awareness=M.integrateAwareness(self.awareness,gain,dt,decay*(if seen then 1 else self.p.unseen_decay_mult),self.p.awareness_max)
 ev.awareness=self.awareness;ev.seen=seen;self.evidence=ev
 self.nextCheck=if seen and ev.distance<=self.p.near_check_range_wu then now else now+1/math.max(self.p.far_check_hz,.1)
 return ev
end
function S.update(self: any,cast: (Vector3,Vector3)->Vector3?,eye: Vector3,facing: Vector3,up: Vector3,pos: Vector3,radius: number,now: number,vigilance: number,decay: number): any
 local p=self.p;local dt=if self.started then math.clamp(now-self.lastCheck,0,.25) else 0
 self.lastCheck=now;self.checks+=1
 local offset=pos-eye;local dist=offset.Magnitude
 local ev={t=now,dt=dt,seen=false,distance=dist,reason='',startle=false,appeared=false,bearing=0,loom=0,motion=0,gain=0,visible=0}
 if dist>p.sight_range_wu or dist<.05 then ev.reason='out of range';return self:finish(ev,now,dt,0,decay,false) end
 local dir=offset/dist
 local off=if facing.Magnitude>1e-9 then math.deg(math.acos(math.clamp(facing.Unit:Dot(dir),-1,1))) else 0
 local face=M.facingWeight(off,p.front_half_deg,p.rear_half_deg,p.rear_gain)
 local distance=M.distanceWeight(dist,p.full_sensitivity_wu,p.sight_range_wu)
 local side=dir:Cross(up);if side.Magnitude<.001 then side=dir:Cross(Vector3.xAxis) end
 side=if side.Magnitude>0 then side.Unit else Vector3.zero
 local centre=Vector3.zero;local count,mask=0,0
 for i,point in {pos,pos+side*radius*.8,pos-side*radius*.8} do
  self.rays+=1;local hit=cast(eye,point);local length=(point-eye).Magnitude
  if hit==nil or (hit-eye).Magnitude>=length-PM.sightTolerance(radius,length) then
   centre+=point;count+=1;mask+=2^(i-1)
  end
 end
 if count==0 then ev.reason='no line of sight';return self:finish(ev,now,dt,0,decay,false) end
 centre/=count;offset=centre-eye;local vd=offset.Magnitude;local angle=M.apparentAngle(radius,vd)
 ev.visible=count/3;ev.distance=vd
 if self.started then
  if self.hasLast and now-self.lastTime<=p.sample_gap_max_s+1e-9 then
   if mask==self.lastMask then
    local gap=math.max(now-self.lastTime,1e-9);local old=self.lastPoint-eye
    ev.bearing=M.bearingRate(old,offset,gap);ev.loom=M.loomRate(M.apparentAngle(radius,old.Magnitude),angle,gap,p.loom_scale_deg_s)
   end
  elseif vd<=p.appear_range_wu then ev.appeared=true;ev.bearing=p.appear_motion_deg_s end
 end
 ev.motion=math.max(ev.bearing,ev.loom)
 ev.gain=M.awarenessGain(ev.motion,p.motion_threshold_deg_s,p.motion_scale_deg_s,distance,face,ev.visible,vigilance)
 ev.startle=ev.motion*math.max(face,p.startle_rear_gain)*ev.visible>=p.startle_motion_deg_s and vd<=p.startle_range_wu
 self.hasLast=true;self.lastPoint=centre;self.lastTime=now;self.lastMask=mask
 self.hasLastSeen=true;self.lastSeenPosition=centre;self.lastSeenTime=now
 return self:finish(ev,now,dt,ev.gain,decay,true)
end
return S
