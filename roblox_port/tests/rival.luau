local R=require("../src/Shared/Predator/RivalSpider")
local Needs=require("../src/Shared/Life/NeedsModel")
local passed,failed=0,0
local function check(ok,msg) if ok then passed+=1 else failed+=1;print("FAIL rival: "..msg) end end
local function player()
 return {position=Vector3.new(15,.31,8),previous=Vector3.new(15,.31,8),heading=Vector3.xAxis,day=2,meals=1,
 hour=12,resting=false,safe=false,wasp=false,gentle=false,grounded=true,moving=false,airborne=false,onLine=false,holding=false,striking=false}
end
local clear=function() return false end
local r=R.new();local s=player()
s.day=1;R.step(r,1/60,s,clear);check(r.state=="dormant","no rival on first day")
s.day=2;s.meals=0;R.step(r,1/60,s,clear);check(r.state=="dormant","first meal protected")
s.meals=1;R.step(r,1/60,s,clear);check(r.state=="patrol","optional far-end encounter starts")
check(R.valid(r) and R.valid(nil),"old saves and valid state")
s.position=Vector3.new(24,.31,8);s.previous=s.position
for _=1,90 do R.step(r,1/60,s,function() return true end) end
check(r.notice==0 and r.state=="patrol","cover conceals the player")
for _=1,45 do R.step(r,1/60,s,clear) end
check(r.state=="windup","visible warning before strike")
s.airborne=true;R.step(r,1/60,s,clear);check(r.state=="recover","jump breaks approach")
s.airborne=false;r.state="windup";r.elapsed=0;s.safe=true
R.step(r,1/60,s,clear);check(r.state=="recover","crack safe")
s.safe=false;s.wasp=true;r.state="windup"
R.step(r,1/60,s,clear);check(r.state=="recover","no stacked attack with wasp")
s.wasp=false;r.state="windup";r.elapsed=0;r.position=Vector3.new(25,.31,8)
local caught=false
for _=1,120 do local event=R.step(r,1/60,s,clear);if event=="caught" then caught=true;break end end
check(caught,"unguarded player can be caught")
r=R.new();r.state="patrol";s.position=r.position;s.previous=s.position;s.striking=true
local event=R.step(r,1/60,s,clear);check(event=="captured","player jump catches rival")
s.striking=false;s.moving=true
local _,food=R.step(r,1/60,s,clear);check(food==0 and r.food==R.FOOD,"walking pauses eating")
s.moving=false;local total=0
for _=1,360 do local _,n=R.step(r,1/60,s,clear);total+=n end
check(math.abs(total-.7)<1e-8 and r.state=="consumed","exact two-housefly reward, once")
local _,extra=R.step(r,1/60,s,clear);check(extra==0,"no duplicate food")
r.food=0/0;check(not R.valid(r),"malformed save rejected")
r=R.new();r.state="lunge";r.origin=Vector3.new(25,.31,8);r.target=Vector3.new(24,.31,8)
s=player();s.position=Vector3.new(24,.31,8);s.previous=s.position;s.gentle=true
local touched=false
for _=1,30 do local e=R.step(r,1/60,s,clear);if e=="touch" then touched=true end end
check(touched,"gentle mode touches without killing")
-- ---------------------------------------------------------------- the daily rival (ROBLOX-67)
local Rules=require("../src/Shared/Data/RivalRules")
local Layout=require("../src/Shared/Habitat/WindowsillLayout")
local function away() local s=player();s.position=Vector3.new(0,.31,8);s.previous=s.position;return s end
-- A rival arrives and the player eats it: returns the number of ticks it took and the state afterwards.
local function eat(r,s)
 s.striking=false
 for _=1,40 do R.step(r,1/60,s,clear) end -- it has arrived and patrols
 r.position=s.position+Vector3.xAxis*.3;r.previous=r.position;r.state="patrol"
 s.striking=true;s.previous=s.position;local e=R.step(r,1/60,s,clear);s.striking=false
 if e~="captured" then return false end
 for _=1,400 do R.step(r,1/60,s,clear) end
 return r.state=="consumed"
end
do
 local d=R.new();local s=away()
 s.day=1;s.meals=0;s.hour=12;R.step(d,1/60,s,clear);check(d.state=="dormant","day 1: protected")
 s.day=1;s.meals=1;R.step(d,1/60,s,clear);check(d.state=="dormant","day 1 even after a meal: protected like the wasp")
 s.day=2;s.meals=0;R.step(d,1/60,s,clear);check(d.state=="dormant","day 2 before the first meal: protected")
 s.meals=1;s.hour=6.9;R.step(d,1/60,s,clear);check(d.state=="dormant","before the morning it has not arrived")
 s.hour=Rules.arriveHour;R.step(d,1/60,s,clear);check(d.state=="patrol","day 2, first meal done, morning: it is on the sill")
 check(Rules.arriveAt.X>=18 and not Layout.inRetreat(Rules.arriveAt),"it arrives at the east end, far from the retreat")
end
do -- a week: a new rival every morning after one is eaten, one at a time
 local r=R.new();local s=away();s.hour=12;s.meals=1
 local arrivals,eaten=0,0
 for day=2,10 do
  s.day=day;s.hour=Rules.arriveHour
  R.step(r,1/60,s,clear)
  if r.state=="patrol" then arrivals+=1 end
  check(r.state=="patrol" and r.food==R.FOOD,`day {day}: a fresh rival, not a half-eaten one`)
  if eat(r,s) then eaten+=1 end
  check(r.state=="consumed" and r.day==day,`day {day}: eaten, and the day is kept`)
  s.hour=23.9;for _=1,30 do R.step(r,1/60,s,clear) end
  check(r.state=="consumed","the same night no second rival comes")
  s.day=day+1;s.hour=6.5;R.step(r,1/60,s,clear);check(r.state=="consumed","not before the morning")
  s.day=day;s.hour=12
 end
 check(arrivals==9 and eaten==9,`nine days, nine rivals ({arrivals} arrived, {eaten} eaten)`)
end
do -- it waits while it could not arrive safely
 local r=R.new();r.state="consumed";r.day=3;local s=away();s.day=4;s.hour=8;s.meals=2
 s.resting=true;R.step(r,1/60,s,clear);check(r.state=="dormant","a new rival is waiting while the spider rests")
 s.resting=false;s.wasp=true;R.step(r,1/60,s,clear);check(r.state=="dormant","and while the wasp visits")
 s.wasp=false;s.position=Vector3.new(24,.31,8);s.previous=s.position;R.step(r,1/60,s,clear);check(r.state=="dormant","and while the spider stands where it would arrive")
 s.position=Vector3.new(0,.31,8);s.previous=s.position;R.step(r,1/60,s,clear);check(r.state=="patrol","then it arrives")
end
do -- an old record: eaten, no day. It restores, is stamped when first seen, and a new rival comes the next morning
 local r=R.new();r.state="consumed";r.food=0
 check(R.valid(r),"an eaten rival without a day is a good record")
 local s=away();s.day=6;s.hour=15;s.meals=4
 for _=1,10 do R.step(r,1/60,s,clear) end
 check(r.state=="consumed" and r.day==6,"it stays eaten that day, and is stamped")
 s.day=7;s.hour=7.1;R.step(r,1/60,s,clear);check(r.state=="patrol","the next morning a new rival is there")
 for _,bad in {-1,0/0,math.huge,"6",true} do local b=R.new();b.day=bad;check(not R.valid(b),`a day of {tostring(bad)} is refused`) end
end
do -- never in the retreat, never an attack there or while resting, whatever the spider does (a long scripted walk through the whole sill)
 local r=R.new();local s=player();s.day=3;s.meals=2
 local worst=0;local events={}
 local seen=false
 for i=1,6000 do
  local x=-28+(i%560)/10 -- the spider walks the sill from the far west to the far east and back, through the retreat
  s.position=Vector3.new(if (i//560)%2==0 then x else 28-(x+28),.31,6);s.previous=s.position
  s.safe=Layout.inRetreat(s.position);s.resting=s.safe and i%3==0
  s.moving=i%2==0
  local e=R.step(r,1/60,s,clear)
  if s.safe and (e=="caught" or e=="warning" or e=="touch") then events[#events+1]=e end
  if Layout.inRetreat(r.position) or r.position.X<18 or r.position.X>28 then worst+=1 end
  if r.state=="consumed" then r.state="dormant" end
  seen=seen or r.state~="dormant"
 end
 check(seen and worst==0,`the rival stays on the eastern sill ({worst} ticks outside)`)
 check(#events==0,"no attack, warning or touch while the spider is in the retreat")
end
print(`RIVAL passed={passed} failed={failed}`)
if failed>0 then error("rival tests failed") end
