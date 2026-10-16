local Loop=require("../src/Shared/Life/LifeLoop")
local Needs=require("../src/Shared/Life/NeedsModel")
local Session=require("../src/Shared/Life/LifeSession")
local ref=require("./continuing_reference")
local passed,failed=0,0
local function check(ok,name) if ok then passed+=1 else failed+=1;print("FAIL CONTINUING "..name) end end
for _,r in ref.thresholds do
 local n=Needs.new(true,r.gentle);n.starvingStreakH=r.streak
 local l=Loop.new(n,nil)
 check(l:tooHungryToSleep()==r.weak,"Godot weak threshold")
 check(l:starved()==r.dead,"Godot death threshold")
 l.clock.hour=22
 l:step(1/60,{inRetreat=true,attached=true,still=true,holding=false,feeding=false},true,false)
 check(l.resting and l.asleep==not r.weak,"weak rests without sleeping")
 local events=l:drainEvents();local deaths=0
 for _,e in events do if e.kind=="starved" then deaths+=1 end end
 check(deaths==(if r.dead then 1 else 0),"death event")
 l:step(1/60,{inRetreat=true,attached=true,still=true,holding=false,feeding=false},false,false)
 for _,e in l:drainEvents() do check(e.kind~="starved","end once") end
end
for _,r in ref.drain do
 local n=Needs.new(true,r.gentle);n:configure({energy=.5});n:addHours(r.hours,false)
 n:advance(.25,false);n:advance(.25,false)
 check(math.abs(n.energy-r.energy)<1e-9,"Godot energy")
 check(math.abs(n.starvingStreakH-r.streak)<1e-9,"Godot streak")
 n:grantEnergy(.3,"fly");check(n.starvingStreakH==0,"meal ends streak")
end
local s=Session.new()
check(not s:begin("main",true),"Easy locked")
check(s:begin("free",false) and s.rules=="gentle","free gentle")
check(not s:endLife("wasp",{}),"gentle cannot end")
check(not s:finishAdult(3),"free cannot unlock")
s:begin("main",false)
check(not s:finishAdult(2),"subadult cannot unlock")
check(s:finishAdult(3)==ref.progress.first,"adult unlocks")
check(s:finishAdult(3)==ref.progress.second,"only once")
check(s.finishedMain==ref.progress.easy,"Easy state")
check(s:endLife("starved",{hours=48}),"standard ends")
check(not s:endLife("wasp",{}),"second end ignored")
check(s.deaths==ref.progress.deaths,"one death")
check(s:another()==Session.SPOTS[2],"new unrelated spot matches Godot")
check(#s.lives==1 and s.lives[1].cause=="starved" and not s.ended,"life archived")
check(s:begin("main",true) and s.rules=="gentle","Easy unlocked")
check(not s:endLife("starved",{}),"Easy cannot die")
print(`CONTINUING passed={passed} failed={failed}`)
if failed>0 then error("continuing failed") end
