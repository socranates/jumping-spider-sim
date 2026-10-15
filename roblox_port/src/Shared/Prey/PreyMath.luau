--!strict
-- Frozen scripts/prey/prey_math.gd: explicit evidence, utility and swept-contact math.
local M = {}
local EPS = 1e-6
function M.sweepClosest(a0: Vector3,a1: Vector3,b0: Vector3,b1: Vector3): (number,number)
 local d=a0-b0; local dv=a1-b1-d
 local t=if dv:Dot(dv)>EPS*EPS then math.clamp(-d:Dot(dv)/dv:Dot(dv),0,1) else 0
 return t,(d+dv*t).Magnitude
end
function M.apparentAngle(radius: number,distance: number): number return 2*math.atan(math.max(radius,0)/math.max(distance,EPS)) end
function M.bearingRate(a: Vector3,b: Vector3,dt: number): number
 if dt<=EPS or a:Dot(a)<EPS or b:Dot(b)<EPS then return 0 end
 return math.deg(math.acos(math.clamp(a.Unit:Dot(b.Unit),-1,1)))/dt
end
function M.loomRate(old: number,angle: number,dt: number,scale: number): number
 return if dt<=EPS or angle<=EPS then 0 else scale*math.max(0,((angle-old)/dt)/angle)
end
function M.distanceWeight(d: number,full: number,zero: number): number
 if zero<=full then return if d<=full then 1 else 0 end
 return math.clamp((zero-d)/(zero-full),0,1)
end
function M.facingWeight(angle: number,front: number,rear: number,gain: number): number
 if angle<=front then return 1 end
 if angle>=rear or rear<=front then return gain end
 local t=(angle-front)/(rear-front); return 1+(gain-1)*t*t*(3-2*t)
end
function M.awarenessGain(motion: number,threshold: number,scale: number,distance: number,facing: number,visible: number,vigilance: number): number
 return if motion<=threshold or scale<=EPS then 0 else (motion-threshold)/scale*distance*facing*math.clamp(visible,0,1)*math.max(vigilance,0)
end
function M.integrateAwareness(a: number,gain: number,dt: number,decay: number,maximum: number): number
 return math.clamp(a+(if gain>0 then gain else -decay)*math.max(dt,0),0,maximum)
end
function M.threat(a: number,calm: number,flee: number): number
 if flee<=calm then return if a>=flee then 1 else 0 end
 return math.clamp((a-calm)/(flee-calm),0,1)
end
function M.scoreRest(w: any,fatigue: number,shelter: number,food: number,threat: number): number
 return w.rest_base+w.rest_fatigue*fatigue+w.rest_shelter*shelter+w.rest_food*food-w.rest_threat*threat
end
function M.scoreMove(w: any,restless: number,food: number,shelter: number,travel: number,fatigue: number,threat: number): number
 return w.move_restless*restless+w.move_food*food+w.move_shelter*shelter-w.move_travel*travel-w.move_fatigue*fatigue-w.move_threat*threat
end
function M.scoreFlee(w: any,threat: number,shelter: number,away: number,travel: number): number
 return threat*(w.flee_threat+w.flee_shelter*shelter+w.flee_away*away-w.flee_travel*travel)
end
function M.pickGoal(scores: {[string]:number},current: string,hysteresis: number): string
 local best,value=current,-math.huge
 for _,g in {'rest','move','flee'} do
  if scores[g] then local v=scores[g]+(if g==current then hysteresis else 0); if v>value+1e-9 then best,value=g,v end end
 end
 return best
end
function M.pathLength(points: {Vector3}): number
 local total=0; for i=2,#points do total+=(points[i]-points[i-1]).Magnitude end; return total
end
function M.pointAt(points: {Vector3},s: number): Vector3
 if #points==0 then return Vector3.zero end
 if s<=0 or #points==1 then return points[1] end
 for i=2,#points do local n=(points[i]-points[i-1]).Magnitude
  if s<=n then return if n<EPS then points[i-1] else points[i-1]:Lerp(points[i],s/n) end; s-=n
 end
 return points[#points]
end
function M.distanceToPath(points: {Vector3},p: Vector3): number
 if #points==0 then return math.huge end
 local best=(points[1]-p).Magnitude
 for i=2,#points do local a=points[i-1];local ab=points[i]-a
  local t=if ab:Dot(ab)<EPS*EPS then 0 else math.clamp((p-a):Dot(ab)/ab:Dot(ab),0,1)
  best=math.min(best,(a+ab*t-p).Magnitude)
 end
 return best
end
function M.targetSpeed(remaining: number,top: number,landing: number,slow: number): number
 return if slow<=EPS or remaining>=slow then top else landing+(top-landing)*math.clamp(remaining/slow,0,1)
end
function M.stepSpeed(speed: number,target: number,accel: number,dt: number): number
 return if speed>=target then target else math.min(speed+accel*dt,target)
end
function M.inView(cf: CFrame,fov: number,aspect: number,p: Vector3,margin: number): boolean
 local v=cf:PointToObjectSpace(p);if v.Z>=-EPS then return false end
 return math.atan2(math.abs(v.X),-v.Z)<=math.atan(math.tan(math.rad(fov)*.5)*math.max(aspect,.1))+math.rad(margin)
  and math.atan2(math.abs(v.Y),-v.Z)<=math.rad(fov)*.5+math.rad(margin)
end
return M
