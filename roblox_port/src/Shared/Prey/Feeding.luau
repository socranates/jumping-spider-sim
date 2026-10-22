--!strict
-- Frozen feeding_controller.gd: struggle after landing, then conserved nutrition grants. The energy itself belongs to the
-- NeedsModel (ROBLOX-24): each tick this advances it (active unless still on a surface, as Godot's controller does) and asks it
-- to grant what the fly gave up, under the meal's capture key. `needs` is the sandbox model unless the owner gives it another
-- (the client gives it the life one). taken/granted/ledger are this controller's own totals, kept as before.
-- The struggle's three numbers (the grip a catch starts with, what a tap adds, the jerks' scale) are Godot's until useGameRules() gives it
-- Data/Catch.game (ROBLOX-72); a controller never given them replays Godot, which the goldens check.
-- ROBLOX-77: the struggle scales with the prey. A controller given the game's rules (useGameRules) also reads the caught prey's size from its
-- profile and applies Catch.scaled(Catch.factorFor(profile)) at capture (the house fly is 1.0 and exactly ROBLOX-72's numbers; a fruit fly
-- is easier). Three more fields hold Godot's remaining struggle numbers (drainScale 1, tire .5, cap 12) so that useRivalRules can give the
-- rival's own; the struggle itself is `struggle`, which step runs and a second controller (Predator/RivalGrip) runs alone.
local R=require(script.Parent.PreyRandom)
local NeedsModel=require(script.Parent.Parent.Life.NeedsModel)
local Catch=require(script.Parent.Parent.Data.Catch)
local F={};F.__index=F
function F.new(needs: any?): any
 return setmetatable({held=nil,struggling=false,feeding=false,grip=0,elapsed=0,waiting=0,jerk=0,venom=6,
  swallow=0,needs=needs or NeedsModel.new(),taken=0,granted=0,ledger={},mealsFinished=0,auto=false,tap=false,note='',rng=R.new(513),
  startGrip=.4,tapGain=.085,jerkScale=1,drainScale=1,tire=.5,cap=12,game=false,tapToFeed=false,biteWindow=0,bites=0,bitePulse=0},F)
end
local function apply(self: any,g: any)
 self.startGrip,self.tapGain,self.jerkScale=g.startGrip,g.tapGain,g.jerkScale
 self.drainScale,self.tire,self.cap=g.drainScale,g.tire,g.cap
end
-- Opt in to the game's struggle (Data/Catch.game): an easier tap, and a struggle that scales with the prey caught (applied at each capture).
function F.useGameRules(self: any)
 apply(self,Catch.scaled(1));self.game=true
 -- ObjectRecord replaces tables on restore. Older rests have no presentation fields.
 self.bites=self.bites or 0;self.biteWindow=self.biteWindow or 0;self.bitePulse=self.bitePulse or 0
end
-- The rival's struggle (ROBLOX-77): its own numbers (Data/Catch.rival), or in the gentle modes the house fly's with no cap. Not scaled by a profile.
function F.useRivalRules(self: any,gentle: boolean)
 apply(self,Catch.forRival(gentle));self.game=false
end
function F.capture(self: any,fly: any)
 if self.game and fly.profile then apply(self,Catch.scaled(Catch.factorFor(fly.profile))) end
 self.held=fly;self.struggling=true;self.feeding=false;self.grip=self.startGrip;self.elapsed=0;self.waiting=0
 self.biteWindow=0;self.bitePulse=0;self.tap=false
 self.venom=self.rng:draw({6,8});self.jerk=self.rng:draw({.35,.75});self.note='Caught!'
end
function F.press(self: any)
 if self.struggling then self.tap=true
 elseif self.held and self.tapToFeed and not self.auto then
  -- A tap opens one bite, never a queue of free nutrition. The fixed tick validates posture.
  self.biteWindow=.38;self.bitePulse=0;self.feeding=true
 elseif self.held and self.swallow<=0 then self.feeding=not self.feeding end -- nothing to eat: E is the retreat's (LifeLoop)
end
function F.cancel(self: any) self.feeding=false;self.biteWindow=0 end
-- The struggle after a capture: waits up to a second for a landing, then the grip drains, jerks, rises with taps and ends in escape(f) (it tore
-- free; held is nil) or subdued (struggling false). Needs nothing of the reserves, so a second controller can run it alone.
function F.struggle(self: any,dt: number,attached: boolean,escape: (any)->())
 local f=self.held;if not f then self.tap=false;return end
 if not attached and self.waiting<1 then self.waiting+=dt;self.tap=false;return end
 self.elapsed+=dt
 local strength=1-(self.tire or .5)*math.clamp(self.elapsed/self.venom,0,1)
 self.grip-=.32*(self.drainScale or 1)*strength*dt
 self.jerk-=dt
 if self.jerk<=0 then self.grip-=.12*self.jerkScale*strength;self.jerk+=self.rng:draw({.35,.75}) end
 if self.auto then self.grip+=.4*dt end
 if self.tap then self.grip+=self.tapGain end
 self.tap=false
 if self.grip<=0 then self.held=nil;self.struggling=false;self.note='It tore free!';escape(f)
 elseif self.grip>=1 or self.elapsed>=(self.cap or 12) then self.grip=1;self.struggling=false;self.feeding=not self.tapToFeed or self.auto;self.swallow=if self.tapToFeed and not self.auto then 0 else 1;self.note='Subdued.' end
end
function F.step(self: any,dt: number,attached: boolean,moving: boolean,escape: (any)->())
 self.needs:advance(dt,not attached or moving)
 local f=self.held;if not f then self.tap=false;return end
 if self.struggling then self:struggle(dt,attached,escape);return end
 self.swallow=math.max(0,self.swallow-dt)
 if not attached or moving then self.feeding=false;self.biteWindow=0;return end
 if self.swallow>0 then self.feeding=true end
 local eatingDt=dt
 if self.tapToFeed and not self.auto then
  eatingDt=math.min(dt,self.biteWindow)
  self.biteWindow=math.max(0,self.biteWindow-dt)
  self.feeding=eatingDt>0
 end
 if not self.feeding then return end
 -- Pulses only follow valid eating ticks, including the automatic accessibility path.
 self.bitePulse=(self.bitePulse or 0)-eatingDt
 if self.bitePulse<=0 then self.bites=(self.bites or 0)+1;self.bitePulse=.38 end
 local take=math.min(f.nutrition,f.profile.body.feed_rate_per_s*eatingDt)
 f.nutrition-=take
 local granted=self.needs:grantEnergy(take,f.captureKey)
 self.taken+=take;self.granted+=granted
 self.ledger[f.captureKey]=(self.ledger[f.captureKey] or 0)+granted
 if f.nutrition<=1e-9 then f.nutrition=0;f.state='CONSUMED';self.held=nil;self.feeding=false;self.mealsFinished+=1;self.note='Meal finished.' end
end
return F
