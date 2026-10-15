--!strict
-- Frozen feeding_controller.gd / needs_model.gd: struggle after landing, then conserved nutrition grants.
local R=require(script.Parent.PreyRandom)
local F={};F.__index=F
function F.new(): any
 return setmetatable({held=nil,struggling=false,feeding=false,grip=0,elapsed=0,waiting=0,jerk=0,venom=6,
  swallow=0,energy=.55,taken=0,granted=0,ledger={},auto=false,tap=false,note='',rng=R.new(513)},F)
end
function F.capture(self: any,fly: any)
 self.held=fly;self.struggling=true;self.feeding=false;self.grip=.4;self.elapsed=0;self.waiting=0
 self.venom=self.rng:draw({6,8});self.jerk=self.rng:draw({.35,.75});self.note='Caught!'
end
function F.press(self: any)
 if self.struggling then self.tap=true elseif self.swallow<=0 then self.feeding=not self.feeding end
end
function F.cancel(self: any) self.feeding=false end
function F.step(self: any,dt: number,attached: boolean,moving: boolean,escape: (any)->())
 self.energy=math.max(.2,self.energy-.0006*dt)
 local f=self.held;if not f then self.tap=false;return end
 if self.struggling then
  if not attached and self.waiting<1 then self.waiting+=dt;self.tap=false;return end
  self.elapsed+=dt
  local strength=1-.5*math.clamp(self.elapsed/self.venom,0,1)
  self.grip-=.32*strength*dt
  self.jerk-=dt
  if self.jerk<=0 then self.grip-=.12*strength;self.jerk+=self.rng:draw({.35,.75}) end
  if self.auto then self.grip+=.4*dt end
  if self.tap then self.grip+=.085 end
  self.tap=false
  if self.grip<=0 then self.held=nil;self.struggling=false;self.note='It tore free!';escape(f)
  elseif self.grip>=1 or self.elapsed>=12 then self.grip=1;self.struggling=false;self.feeding=true;self.swallow=1;self.note='Subdued.' end
  return
 end
 self.swallow=math.max(0,self.swallow-dt)
 if not attached or moving then self.feeding=false;return end
 if self.swallow>0 then self.feeding=true end
 if not self.feeding then return end
 local take=math.min(f.nutrition,f.profile.body.feed_rate_per_s*dt)
 local granted=math.min(take,1-self.energy)
 f.nutrition-=take;self.energy+=granted;self.taken+=take;self.granted+=granted
 self.ledger[f.captureKey]=(self.ledger[f.captureKey] or 0)+granted
 if f.nutrition<=1e-9 then f.nutrition=0;f.state='CONSUMED';self.held=nil;self.feeding=false;self.note='Meal finished.' end
end
return F
