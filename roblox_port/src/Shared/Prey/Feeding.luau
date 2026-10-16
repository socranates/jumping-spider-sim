--!strict
-- Frozen feeding_controller.gd: struggle after landing, then conserved nutrition grants. The energy itself belongs to the
-- NeedsModel (ROBLOX-24): each tick this advances it (active unless still on a surface, as Godot's controller does) and asks it
-- to grant what the fly gave up, under the meal's capture key. `needs` is the sandbox model unless the owner gives it another
-- (the client gives it the life one). taken/granted/ledger are this controller's own totals, kept as before.
local R=require(script.Parent.PreyRandom)
local NeedsModel=require(script.Parent.Parent.Life.NeedsModel)
local F={};F.__index=F
function F.new(needs: any?): any
 return setmetatable({held=nil,struggling=false,feeding=false,grip=0,elapsed=0,waiting=0,jerk=0,venom=6,
  swallow=0,needs=needs or NeedsModel.new(),taken=0,granted=0,ledger={},mealsFinished=0,auto=false,tap=false,note='',rng=R.new(513)},F)
end
function F.capture(self: any,fly: any)
 self.held=fly;self.struggling=true;self.feeding=false;self.grip=.4;self.elapsed=0;self.waiting=0
 self.venom=self.rng:draw({6,8});self.jerk=self.rng:draw({.35,.75});self.note='Caught!'
end
function F.press(self: any)
 if self.struggling then self.tap=true elseif self.held and self.swallow<=0 then self.feeding=not self.feeding end -- nothing to eat: E is the retreat's (LifeLoop)
end
function F.cancel(self: any) self.feeding=false end
function F.step(self: any,dt: number,attached: boolean,moving: boolean,escape: (any)->())
 self.needs:advance(dt,not attached or moving)
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
 f.nutrition-=take
 local granted=self.needs:grantEnergy(take,f.captureKey)
 self.taken+=take;self.granted+=granted
 self.ledger[f.captureKey]=(self.ledger[f.captureKey] or 0)+granted
 if f.nutrition<=1e-9 then f.nutrition=0;f.state='CONSUMED';self.held=nil;self.feeding=false;self.mealsFinished+=1;self.note='Meal finished.' end
end
return F
