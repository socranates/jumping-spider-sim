--!strict
-- Frozen Godot scripts/life/growth.gd, LIFE-10..12. Durations and scales are game tuning, not measured instars.
local Growth = {}
Growth.__index = Growth
Growth.STAGES = { "young juvenile", "juvenile", "subadult", "adult" }
Growth.SCALES = { 1, 1.15, 1.32, 1.50 }
Growth.ADULT = 3
Growth.READY_FOOD = 0.9
-- What one housefly counts for in `fedSinceMoult`: a third of Godot's 0.9 (ROBLOX-61; a small prey is half of it). The client credits food in these units.
Growth.FLY_FOOD = 0.3
-- The game's own rules (ROBLOX-88), opt-in like NeedsModel.game and Data/Catch.game: the housefly-equivalents a moult asks for. Godot's is 3 (READY_FOOD,
-- pinned by tests/growth_reference.json); a Growth never given these replays it. Growth:useGameRules() applies them.
Growth.game = { moultFlies = 5 }
Growth.MOULT_HOURS = 12
Growth.SOFT_HOURS = 10
Growth.SOFT_REACH = 0.7
Growth.SOFT_SPEED = 0.65 -- Gameplay tuning for the vulnerable soft-cuticle period.
local function finite(v: any): boolean
 return type(v)=="number" and v==v and math.abs(v)<math.huge
end
function Growth.new(): any
 return setmetatable({stage=0,fedSinceMoult=0,ready=false,moultingHoursLeft=0,softHoursLeft=0,exuviae={}},Growth)
end
-- The game's moult: `moultFlies` housefly-equivalents instead of three. Sets the instance's own threshold; food already eaten is kept (a spider that has
-- eaten two flies has eaten two flies), and a spider already ready to moult stays ready.
function Growth.useGameRules(self: any)
 self.readyFood=Growth.game.moultFlies*Growth.FLY_FOOD;self.gameRules=true
end
-- The food a moult asks for, in the units of `fedSinceMoult`, and in housefly-equivalents (3 by Godot's rule, 5 in the game).
function Growth.readyAt(self: any): number return self.readyFood or Growth.READY_FOOD end
function Growth.mealGoal(self: any): number return math.floor(self:readyAt()/Growth.FLY_FOOD+.5) end
function Growth.isAdult(self: any): boolean return self.stage>=Growth.ADULT end
function Growth.isMoulting(self: any): boolean return self.moultingHoursLeft>0 end
function Growth.isSoft(self: any): boolean return self.softHoursLeft>0 end
function Growth.stageName(self: any): string return Growth.STAGES[self.stage+1] end
function Growth.reachFactor(self: any): number return if self:isSoft() or self:isMoulting() then Growth.SOFT_REACH else 1 end
function Growth.speedFactor(self: any): number return if self:isSoft() or self:isMoulting() then Growth.SOFT_SPEED else 1 end
function Growth.softness(self: any): number return if self:isMoulting() then 1 else math.clamp(self.softHoursLeft/Growth.SOFT_HOURS,0,1) end
function Growth.eat(self: any, energy: number): boolean
 if not finite(energy) or energy<=0 or self:isAdult() or self:isMoulting() then return false end
 self.fedSinceMoult+=energy
 local before=self.ready
 self.ready=self.fedSinceMoult>=self:readyAt()-1e-9
 return self.ready and not before
end
function Growth.beginMoult(self: any): boolean
 if not self.ready or self:isAdult() or self:isMoulting() then return false end
 self.moultingHoursLeft=Growth.MOULT_HOURS
 return true
end
function Growth.passHours(self: any, hours: number, at: Vector3): string
 if not finite(hours) or hours<=0 then return "" end
 if self:isMoulting() then
  self.moultingHoursLeft=math.max(0,self.moultingHoursLeft-hours)
  if self.moultingHoursLeft==0 then
   self.stage=math.min(self.stage+1,Growth.ADULT)
   self.ready=false;self.fedSinceMoult=0;self.softHoursLeft=Growth.SOFT_HOURS
   table.insert(self.exuviae,at)
   return "moulted"
  end
 elseif self:isSoft() then
  self.softHoursLeft=math.max(0,self.softHoursLeft-hours)
  if self.softHoursLeft==0 then return "hardened" end
 end
 return ""
end
function Growth.toRecord(self: any): any
 local skins={}
 for _,p in self.exuviae do table.insert(skins,{p.X,p.Y,p.Z}) end
 return {stage=self.stage,fed_since_moult=self.fedSinceMoult,ready=self.ready,
  moulting_hours_left=self.moultingHoursLeft,soft_hours_left=self.softHoursLeft,exuviae=skins}
end
function Growth.problems(r: any): {string}
 if type(r)~="table" then return {"growth: not a record"} end
 local e={}
 if not finite(r.stage) or r.stage%1~=0 or r.stage<0 or r.stage>3 then table.insert(e,"growth: invalid stage") end
 for _,k in {"fed_since_moult","moulting_hours_left","soft_hours_left"} do
  if not finite(r[k]) or r[k]<0 then table.insert(e,"growth: invalid "..k) end
 end
 if type(r.ready)~="boolean" then table.insert(e,"growth: invalid ready") end
 if type(r.exuviae)~="table" or #r.exuviae>3 then table.insert(e,"growth: invalid old skins")
 else for _,p in r.exuviae do
  if type(p)~="table" or #p~=3 or not finite(p[1]) or not finite(p[2]) or not finite(p[3]) then table.insert(e,"growth: invalid skin position") end
 end end
 return e
end
function Growth.load(self: any,r: any): boolean
 if #Growth.problems(r)>0 then return false end
 self.stage=r.stage;self.fedSinceMoult=r.fed_since_moult;self.ready=r.ready
 self.moultingHoursLeft=r.moulting_hours_left;self.softHoursLeft=r.soft_hours_left;self.exuviae={}
 for _,p in r.exuviae do table.insert(self.exuviae,Vector3.new(p[1],p[2],p[3])) end
 return true
end
return Growth
