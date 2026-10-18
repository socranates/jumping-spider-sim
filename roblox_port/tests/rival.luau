local R=require("../src/Shared/Predator/RivalSpider")
local Needs=require("../src/Shared/Life/NeedsModel")
local passed,failed=0,0
local function check(ok,msg) if ok then passed+=1 else failed+=1;print("FAIL rival: "..msg) end end
local function player()
 return {position=Vector3.new(15,.31,8),previous=Vector3.new(15,.31,8),heading=Vector3.xAxis,day=2,meals=1,
 resting=false,safe=false,wasp=false,gentle=false,grounded=true,moving=false,airborne=false,onLine=false,holding=false,striking=false}
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
print(`RIVAL passed={passed} failed={failed}`)
if failed>0 then error("rival tests failed") end
