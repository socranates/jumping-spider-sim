--!strict
-- Frozen Godot scripts/life/growth.gd, LIFE-10..12. Durations and scales are game tuning, not measured instars.
local Species = require(script.Parent.Parent.Data.Species)
local Random = require(script.Parent.Parent.Prey.PreyRandom)
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
-- Legacy Roblox rules, retained for old fixtures/tools. The live client opts
-- into `instars` through useInstarRules instead.
Growth.game = { firstMoultFlies = 7, secondMoultFlies = 10, moultFlies = 5, gentleMoultFlies = 3 }
-- Live ladder, separate from the frozen four-stage reference above. Bailey's
-- lab sample is the basis for this draw, not a population-wide survival claim.
Growth.game.instars = {
 first = 2, earlyAdult = 7, lateAdult = 8, earlyChance = .15,
 meals = {4,6,8,11,15,20}, gentleMeals = {2,3,4,6,8,10},
 -- A seven-instar life omits the middle (11-meal) requirement.
 earlyGoals = {1,2,3,5,6}, runMoult = 2, lockMoult = 5,
}
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
-- First/second game moults ask for seven/ten full-fly equivalents in every mode.
-- The last moult retains `moultFlies` (`gentleMoultFlies` when gentle). Stores the later threshold;
-- food already eaten is kept (a spider that has eaten two flies has eaten two flies), and a spider already ready to moult stays ready.
function Growth.useGameRules(self: any,gentle: boolean?)
 self.readyFood=(if gentle==true then Growth.game.gentleMoultFlies else Growth.game.moultFlies)*Growth.FLY_FOOD;self.gameRules=true
end
function Growth.nextSeed(seed: number, serial: number): number
 return Random.mixed(seed,serial,73019).state
end
function Growth.drawMaturity(seed: number): number
 return if Random.mixed(seed, 8163):next()<Growth.game.instars.earlyChance then 7 else 8
end
-- Applying this to an old life is a one-time, deterministic migration. Stage 1
-- maps to instar 4; stage 2 to instar 6; adults stay adults. Historical abilities
-- remain earned even if the new unlock is later. Never change consumed credit,
-- a sticky ready flag, a running moult, softness, or the old skins.
function Growth.useInstarRules(self: any, gentle: boolean?, seed: number?, fresh: boolean?)
 if self.instarVersion==nil then
  local old=self.stage
  self.lifeSeed=math.floor(seed or 914)%2147483647
  self.matureInstar=Growth.drawMaturity(self.lifeSeed)
  self.instarVersion=1
  if fresh~=true then
   self.stage=if old>=3 then self.matureInstar-2 else old*2
   self.earnedRun=old>=1;self.earnedLock=old>=2
  end
 end
 self.gameRules=true;self.gentleRules=gentle==true
 if not self:isAdult() then self.ready=self.ready or self.fedSinceMoult>=self:readyAt()-1e-9 end
end
function Growth.adultStage(self: any): number
 return if self.instarVersion==1 then self.matureInstar-2 else Growth.ADULT
end
function Growth.instar(self: any): number return self.stage+2 end
function Growth.visualStage(self: any): number
 return self.stage/self:adultStage()*Growth.ADULT
end
function Growth.unlockedRun(self: any): boolean
 return self.earnedRun==true or self.stage>=(if self.instarVersion==1 then Growth.game.instars.runMoult else 1)
end
function Growth.unlockedLock(self: any): boolean
 return self.earnedLock==true or self.stage>=(if self.instarVersion==1 then Growth.game.instars.lockMoult else 2)
end
function Growth.unlockAt(self: any, ability: string): boolean
 local threshold=if ability=="run" then Growth.game.instars.runMoult else Growth.game.instars.lockMoult
 local earned=if ability=="run" then self.earnedRun else self.earnedLock
 return self.instarVersion==1 and self.stage==threshold and earned~=true
end
-- What swallowing `energy` (of the reserves, in the units a housefly's meal is 0.35 of) credits toward a moult, in `fedSinceMoult`'s units: a housefly credits
-- FLY_FOOD (0.3) whatever the moult asks for. One formula for the prey and the rival (a whole rival, Rival.FOOD 0.7, is two houseflies); it was written out twice in the client.
function Growth.rivalCredit(energy: number): number
 return energy*Growth.READY_FOOD/(3*Species.fly_like_prototype.body.nutrition)
end
-- A meal of `energy` in housefly-equivalents ("2 meals" for a whole rival).
function Growth.mealsOf(energy: number): number
 return math.floor(Growth.rivalCredit(energy)/Growth.FLY_FOOD+.5)
end
-- The food a moult asks for, in the units of `fedSinceMoult`, and in housefly-equivalents (3 by Godot's rule, 5 in the game).
function Growth.readyAt(self: any): number
 if self.instarVersion==1 then
  local config=Growth.game.instars
  local index=math.min(self.stage+1,self:adultStage())
  if self.matureInstar==7 then index=config.earlyGoals[index] end
  return (if self.gentleRules then config.gentleMeals[index] else config.meals[index])*Growth.FLY_FOOD
 end
 if self.gameRules then
  if self.stage==0 then return Growth.game.firstMoultFlies*Growth.FLY_FOOD end
  if self.stage==1 then return Growth.game.secondMoultFlies*Growth.FLY_FOOD end
 end
 return self.readyFood or Growth.READY_FOOD
end
function Growth.mealGoal(self: any): number return math.floor(self:readyAt()/Growth.FLY_FOOD+.5) end
function Growth.isAdult(self: any): boolean return self.stage>=self:adultStage() end
function Growth.isMoulting(self: any): boolean return self.moultingHoursLeft>0 end
-- New lives unlock after the second/fifth completed moult. Migration also keeps
-- historical abilities already earned under the old three-moult rules.
function Growth.canRun(self: any): boolean return self:unlockedRun() and not self:isMoulting() end
function Growth.canLock(self: any): boolean return self:unlockedLock() and not self:isMoulting() end
function Growth.isSoft(self: any): boolean return self.softHoursLeft>0 end
function Growth.stageName(self: any): string
 return if self.instarVersion==1 then (if self:isAdult() then "adult" else `juvenile (instar {self:instar()})`) else Growth.STAGES[self.stage+1]
end
function Growth.reachFactor(self: any): number return if self:isSoft() or self:isMoulting() then Growth.SOFT_REACH else 1 end
function Growth.speedFactor(self: any): number return if self:isSoft() or self:isMoulting() then Growth.SOFT_SPEED else 1 end
function Growth.softness(self: any): number return if self:isMoulting() then 1 else math.clamp(self.softHoursLeft/Growth.SOFT_HOURS,0,1) end
function Growth.eat(self: any, energy: number): boolean
 if not finite(energy) or energy<=0 or self:isAdult() or self:isMoulting() then return false end
 self.fedSinceMoult+=energy
 local before=self.ready
 self.ready=before or self.fedSinceMoult>=self:readyAt()-1e-9
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
   self.stage=math.min(self.stage+1,self:adultStage())
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
 local record:any={stage=self.stage,fed_since_moult=self.fedSinceMoult,ready=self.ready,
  moulting_hours_left=self.moultingHoursLeft,soft_hours_left=self.softHoursLeft,exuviae=skins}
 record.instar_version=self.instarVersion;record.mature_instar=self.matureInstar;record.life_seed=self.lifeSeed
 record.gentle_rules=self.gentleRules;record.earned_run=self.earnedRun;record.earned_lock=self.earnedLock
 return record
end
function Growth.problems(r: any): {string}
 if type(r)~="table" then return {"growth: not a record"} end
 local e={}
 local adult=3
 if r.instar_version~=nil then
  if r.instar_version~=1 or (r.mature_instar~=7 and r.mature_instar~=8)
   or not finite(r.life_seed) or r.life_seed%1~=0 or r.life_seed<0 or r.life_seed>=2147483647
   or type(r.gentle_rules)~="boolean" then table.insert(e,"growth: invalid instar ladder")
  else adult=r.mature_instar-2 end
  for _,k in {"earned_run","earned_lock"} do if r[k]~=nil and type(r[k])~="boolean" then table.insert(e,"growth: invalid earned ability") end end
 elseif r.mature_instar~=nil or r.life_seed~=nil or r.gentle_rules~=nil or r.earned_run~=nil or r.earned_lock~=nil then
  table.insert(e,"growth: incomplete instar ladder")
 end
 if not finite(r.stage) or r.stage%1~=0 or r.stage<0 or r.stage>adult then table.insert(e,"growth: invalid stage") end
 for _,k in {"fed_since_moult","moulting_hours_left","soft_hours_left"} do
  if not finite(r[k]) or r[k]<0 then table.insert(e,"growth: invalid "..k) end
 end
 if type(r.ready)~="boolean" then table.insert(e,"growth: invalid ready") end
 if type(r.exuviae)~="table" or #r.exuviae>adult then table.insert(e,"growth: invalid old skins")
 else for _,p in r.exuviae do
  if type(p)~="table" or #p~=3 or not finite(p[1]) or not finite(p[2]) or not finite(p[3]) then table.insert(e,"growth: invalid skin position") end
 end end
 return e
end
function Growth.load(self: any,r: any): boolean
 if #Growth.problems(r)>0 then return false end
 self.stage=r.stage;self.fedSinceMoult=r.fed_since_moult;self.ready=r.ready
 self.moultingHoursLeft=r.moulting_hours_left;self.softHoursLeft=r.soft_hours_left;self.exuviae={}
 self.instarVersion=r.instar_version;self.matureInstar=r.mature_instar;self.lifeSeed=r.life_seed
 self.gentleRules=r.gentle_rules;self.earnedRun=r.earned_run;self.earnedLock=r.earned_lock
 if self.instarVersion==1 then self.gameRules=true end
 for _,p in r.exuviae do table.insert(self.exuviae,Vector3.new(p[1],p[2],p[3])) end
 return true
end
return Growth
