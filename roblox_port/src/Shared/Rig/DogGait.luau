--!strict
-- Presentation only. Stance paws remain in world space; travel drives the
-- diagonal step pairs. Two-bone joints connect those paws to the moving body.
local DogGait={}
DogGait.STRIDE=40
DogGait.STANCE=.6
DogGait.UPPER=22
DogGait.LOWER=20
local Y=Vector3.yAxis
local function smooth(t: number): number return t*t*(3-2*t) end
local function nominal(frame: CFrame,i: number,lead: number): Vector3
 return frame:PointToWorldSpace(Vector3.new(if i%2==1 then -8 else 8,0,if i<=2 then -20-lead else 19-lead))
end
function DogGait.new(): any
 return {cycle=0,previous=nil,heading=nil,feet={},resets=0}
end
function DogGait.joint(hip: Vector3,ankle: Vector3,pole: Vector3): (Vector3,Vector3)
 local delta=ankle-hip
 local distance=math.clamp(delta.Magnitude,math.abs(DogGait.UPPER-DogGait.LOWER)+.01,DogGait.UPPER+DogGait.LOWER-.01)
 local direction=if delta.Magnitude>.001 then delta.Unit else -Y
 local along=(DogGait.UPPER^2-DogGait.LOWER^2+distance^2)/(2*distance)
 local bend=pole-direction*pole:Dot(direction)
 if bend.Magnitude<.001 then
  local axis=if math.abs(direction.X)<.9 then Vector3.xAxis else Vector3.zAxis
  bend=axis-direction*axis:Dot(direction)
 end
 local knee=hip+direction*along+bend.Unit*math.sqrt(math.max(0,DogGait.UPPER^2-along^2))
 return knee,hip+direction*distance
end
function DogGait.step(self: any,frame: CFrame,dt: number,ground: (Vector3)->Vector3?,reduced: boolean): any
 local travelled=if self.previous then (frame.Position-self.previous).Magnitude else 0
 local turn=if self.heading then math.acos(math.clamp(self.heading:Dot(frame.LookVector),-1,1)) else 0
 local reset=self.previous==nil or travelled>DogGait.STRIDE*.75 or turn>1.3
 self.previous,self.heading=frame.Position,frame.LookVector
 if reset then self.feet={};self.cycle=0;self.resets+=1;travelled=0;turn=0 end
 local moving=travelled>.001 or turn>.001
 if not reduced then self.cycle+=(travelled+turn*12)/DogGait.STRIDE end
 local supported=true
 for i=1,4 do
  local phase=self.cycle+(if i==1 or i==4 then 0 else .5)
  local cycle=math.floor(phase);phase%=1
  local f=self.feet[i]
  if f==nil then
   local lead=if reduced then 0 else 12-math.min(phase/DogGait.STANCE,1)*24
   local at=ground(nominal(frame,i,lead))
   f={anchor=at or nominal(frame,i,lead),supported=at~=nil,lastCycle=-1,u=0,heading=frame.LookVector}
   self.feet[i]=f
  end
  if reduced then
   -- A static pose follows the animal without procedural stepping or bobbing.
   local at=ground(nominal(frame,i,0));f.anchor=at or f.anchor;f.supported=at~=nil;f.swing=nil
  elseif phase>=DogGait.STANCE and f.lastCycle~=cycle then
   f.lastCycle=cycle
   local target=ground(nominal(frame,i,if travelled>.05 then 28 else 0))
   if target then
    f.swing={from=f.anchor,to=target,heading=frame.LookVector};f.u=0
   else f.supported=false end
  end
  local hip=nominal(frame,i,0)+Y*33
  -- During a sniff turn the hips move round planted paws without forward
  -- travel. Reposition a reaching paw instead of letting the leg disconnect.
  if not reduced and f.swing==nil and (hip-f.anchor-Y*3.5).Magnitude>36 then
   local target=ground(nominal(frame,i,0))
   if target then f.swing={from=f.anchor,to=target,heading=frame.LookVector,turn=true};f.u=0 end
  end
  if f.swing then
   local u=if f.swing.turn then f.u+math.clamp(dt,0,.15)/.15
    elseif cycle>f.lastCycle then 1 else math.clamp((phase-DogGait.STANCE)/(1-DogGait.STANCE),0,1)
   if not moving then u=math.max(u,f.u+math.clamp(dt,0,.15)/.15) end
   f.u=math.clamp(math.max(u,f.u),0,1)
   f.anchor=f.swing.from:Lerp(f.swing.to,smooth(f.u))+Y*(math.sin(f.u*math.pi)*5)
   if f.u>=1 then f.anchor=f.swing.to;f.heading=f.swing.heading;f.supported=true;f.swing=nil end
  end
  f.hip=hip
  f.knee,f.ankle=DogGait.joint(hip,f.anchor+Y*3.5,frame.LookVector*(if i<=2 then -1 else 1))
  supported=supported and f.supported
 end
 return {feet=self.feet,supported=supported,moving=moving}
end
return DogGait
