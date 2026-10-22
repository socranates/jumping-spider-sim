-- Diagnostic of the published rules, no engine or world-clock approximation.
local Needs=require("../src/Shared/Life/NeedsModel")
local Loop=require("../src/Shared/Life/LifeLoop")
local Clock=require("../src/Shared/Life/LifeClock")
Clock.game.clockScale=60
for _,gentle in {false,true} do
 for _,energy in {0,.55,1} do
  local n=Needs.new(true,gentle);n:useGameRules();n.energy=energy
  local l=Loop.new(n)
  local s={inRetreat=true,attached=true,still=true,holding=false,feeding=false}
  local start=(l.clock.day-1)*24+l.clock.hour
  for _=1,1200 do
   n:advance(.25,false);l:step(.25,s,false,false)
   if l.lifeOver or (l.clock.day-1)*24+l.clock.hour-start>=120 then break end
  end
  print("STARVATION_BEFORE",gentle,energy,"elapsed_game_hours",(l.clock.day-1)*24+l.clock.hour-start,
   "energy",n.energy,"streak",n.starvingStreakH,"dead",l.lifeOver)
 end
end
Clock.game.clockScale=1
