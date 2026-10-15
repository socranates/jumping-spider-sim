--!strict
-- Frozen prey_population.gd: delayed, twice-unseen vent entries; never teleport a replacement onto a perch.
local R=require(script.Parent.PreyRandom)
local P={};P.__index=P
function P.new(profile: any,seed: number,target: number): any
 return setmetatable({p=profile,rng=R.new(seed),target=target,owed={},eligible={},rest={},nextCheck=0,entries=0,deferred=0},P)
end
function P.step(self: any,now: number,living: number,vents: {any},safe: (any)->boolean,enter: (any)->boolean)
 local missing=math.max(0,self.target-living)
 while #self.owed>missing do table.remove(self.owed) end
 while #self.owed<missing do table.insert(self.owed,now+self.rng:draw(self.p.replenish_delay_s)) end
 table.sort(self.owed)
 if #self.owed==0 or now<self.owed[1] or now<self.nextCheck then return end
 self.nextCheck=now+self.p.replenish_retry_s
 for _,vent in vents do
  if now>=(self.rest[vent.id] or 0) and safe(vent) then
   local old=self.eligible[vent.id]
   self.eligible[vent.id]=now
   if old and now-old<=self.p.replenish_retry_s*1.6+1e-6 and enter(vent) then
    table.remove(self.owed,1);self.rest[vent.id]=now+6;self.eligible[vent.id]=nil;self.entries+=1;return
   end
  else self.eligible[vent.id]=nil end
 end
 self.deferred+=1
end
return P
