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
-- ---------------------------------------------------------------- striking the rival is a contest, and it presses harder (ROBLOX-73)
local RivalText=require("../src/Shared/UI/RivalText")
do -- the numbers, pinned
 check(Rules.reachWu==3.2 and Rules.rememberSeconds==5.0 and Rules.stalkNotice==.45,"initiative: windup from 3.2 wu, remembers 5 s, stalks from a notice of 0.45")
 check(Rules.awareNotice==.3 and Rules.contestCaptured==.55 and Rules.contestSprang==.25 and Rules.counterCost==.25,"contest: aware from 0.3, 55% caught, 25% sprang clear, the rest a bite worth 0.25")
 check(math.abs(Rules.contestCaptured+Rules.contestSprang+.20-1)<1e-12,"55 + 25 + 20 is all of it")
 check(Rules.reachWu>2.5 and Rules.rememberSeconds>3 and Rules.stalkNotice<.6,"each is more pressing than Godot's 2.5, 3 and 0.6")
end
local function strike(r,day,gentle)
 local s=player();s.day=day or 2;s.seed=914;s.gentle=gentle==true
 s.position=r.position+Vector3.xAxis*.2;s.previous=s.position;s.striking=true
 return s
end
do -- it stalks sooner: a patrolling rival that sees the spider starts to stalk at a notice of 0.45, not 0.6
 local r=R.new();local s=player();r.state="patrol";s.position=Vector3.new(20,.31,8);s.previous=s.position
 local at=0
 for i=1,60 do R.step(r,1/60,s,clear);if r.state=="stalk" then at=i;break end end
 check(at>=25 and at<=29 and r.notice>=.45 and r.notice<.5,`it stalks after about {Rules.stalkNotice} s of seeing the spider (tick {at}, notice {r.notice})`)
end
do -- who is aware: stalking, winding up, or patrolling with a notice of 0.3; not one that has not noticed, and not one recovering
 local r=R.new()
 for _,c in {{"patrol",.29,false},{"patrol",.3,true},{"patrol",0,false},{"stalk",0,true},{"windup",0,true},{"recover",1,false},{"lunge",1,false},{"dormant",1,false}} do
  r.state=c[1];r.notice=c[2];check(R.aware(r)==c[3],`{c[1]} at notice {c[2]}: aware is {tostring(c[3])}`)
 end
end
do -- a strike at a rival that has not seen it is caught outright, as before, and uses no draw
 for _,c in {{"patrol",0},{"patrol",.29},{"recover",1}} do
  local r=R.new();r.state=c[1];r.notice=c[2];r.position=Vector3.new(24,.31,8);r.previous=r.position
  local e=R.step(r,1/60,strike(r),clear)
  check(e=="captured" and r.state=="captured" and r.contests==0,`a strike at a rival that is {c[1]} (notice {c[2]}) catches it, with no draw`)
 end
end
do -- a strike at one that has: a contest, over many strikes the rates are 55 / 25 / 20, each rival state is a contest, and the outcomes are what they say
 local counts={captured=0,sprang=0,counter=0};local N=6000
 for i=1,N do
  local r=R.new();r.state=({"stalk","windup","patrol"})[i%3+1];r.notice=if r.state=="patrol" then .5 else 0
  r.position=Vector3.new(24,.31,8);r.previous=r.position;r.contests=i//7
  local e,amount=R.step(r,1/60,strike(r,2+i%9),clear)
  counts[e]=(counts[e] or 0)+1
  if e=="captured" then check(r.state=="captured" and amount==0 and not r.spared,"caught: held") 
  elseif e=="sprang" then if not (r.state=="recover" and amount==0 and r.spared==true) then check(false,"sprang clear: recovers, nothing lost") end
  elseif e=="counter" then if not (r.state=="recover" and amount==.25 and r.spared==true) then check(false,"counter-bite: recovers, costs 0.25") end
  else check(false,"an unknown event "..tostring(e)) end
  if r.contests~=i//7+1 then check(false,"the contest is counted once") end
 end
 local c,sp,cb=counts.captured/N,counts.sprang/N,counts.counter/N
 check(math.abs(c-.55)<.03 and math.abs(sp-.25)<.03 and math.abs(cb-.20)<.03,`rates over {N} strikes: {string.format("%.3f %.3f %.3f",c,sp,cb)}`)
 print(string.format("RIVAL contest rates over %d strikes: caught %.3f, sprang clear %.3f, counter-bite %.3f",N,c,sp,cb))
end
do -- the draw is determined by the seed, the day and how many contests it has had: the same strike gives the same outcome, a different one may not
 local seen={}
 for n=0,40 do
  local a,b=R.contest(914,3,n),R.contest(914,3,n)
  check(a==b,"the same seed, day and count: the same outcome");seen[a]=true
 end
 check(seen.captured and seen.sprang and seen.counter,"and over the counts all three come up")
 local differs=false
 for n=0,40 do if R.contest(914,3,n)~=R.contest(914,4,n) or R.contest(914,3,n)~=R.contest(915,3,n) then differs=true end end
 check(differs,"another day or another world is another stream")
 local function once(r,day) r.state="stalk";r.position=Vector3.new(24,.31,8);r.previous=r.position;return (R.step(r,1/60,strike(r,day),clear)) end
 local a,b=R.new(),R.new()
 check(once(a,5)==once(b,5) and a.contests==1,"two rivals with the same record, struck on the same day, do the same")
 -- a return to a record (a copy of the table as it was) brings the same outcome: no rerolling the draw
 local rec=R.new();rec.state="stalk";rec.position=Vector3.new(24,.31,8);rec.previous=rec.position;rec.contests=11
 local back=table.clone(rec)
 local first=once(rec,6)
 check(R.valid(rec) and rec.contests==12,"the count moves on with the contest")
 for _=1,5 do local again=table.clone(back);check(once(again,6)==first,"struck again from the same record, the outcome is the same") end
 -- a record from before the contest has no count, and means none
 local old=R.new();old.contests=nil;old.state="stalk";old.position=Vector3.new(24,.31,8);old.previous=old.position
 check(R.valid(old) and once(old,6)==R.contest(914,6,0) and old.contests==1,"an older record means no contests so far")
end
do -- it got away from this strike, but the next strike or a recovering rival is caught outright (recover is still free)
 local r;local day
 for d=1,200 do
  r=R.new();r.state="stalk";r.position=Vector3.new(24,.31,8);r.previous=r.position;day=d
  if R.contest(914,d,0)=="sprang" then break end
 end
 local s=strike(r,day)
 check(R.step(r,1/60,s,clear)=="sprang","(a strike that springs the rival clear)")
 for _=1,30 do
  local e=R.step(r,1/60,s,clear) -- the same strike goes on, with the rival still within reach
  if e=="captured" then check(false,"the rest of the same strike caught a rival that had just sprung clear") break end
 end
 check(r.state=="recover" and r.contests==1,"the rest of the same strike does not catch it, and draws nothing more")
 s.striking=false;R.step(r,1/60,s,clear)
 check(r.spared==nil,"when the strike is over it is not spared any more")
 r.position=s.position+Vector3.xAxis*.2;r.previous=r.position
 s.striking=true;s.previous=s.position
 check(R.step(r,1/60,s,clear)=="captured" and r.contests==1,"a new strike catches it while it recovers, with no draw")
end
do -- a holding spider, a lunging rival and a blocked line are not strikes
 for _,c in {"holding","lunge","blocked"} do
  local r=R.new();r.state="stalk";r.position=Vector3.new(24,.31,8);r.previous=r.position;r.origin=r.position;r.target=r.position
  local s=strike(r);local block=clear
  if c=="holding" then s.holding=true elseif c=="lunge" then r.state="lunge" else block=function() return true end end
  local e=R.step(r,1/60,s,block)
  check(r.contests==0 and e~="sprang" and e~="counter" and e~="captured",`{c}: no contest`)
 end
end
do -- the gentle modes: the bite costs nothing
 for d=1,200 do
  if R.contest(914,d,0)=="counter" then
   local r=R.new();r.state="stalk";r.position=Vector3.new(24,.31,8);r.previous=r.position
   local e,cost=R.step(r,1/60,strike(r,d,true),clear)
   check(e=="counter" and cost==0 and r.state=="recover","gentle: the counter-bite is the same event and costs nothing")
   local r2=R.new();r2.state="stalk";r2.position=Vector3.new(24,.31,8);r2.previous=r2.position
   local e2,cost2=R.step(r2,1/60,strike(r2,d,false),clear)
   check(e2=="counter" and cost2==.25,"and standard rules: 0.25")
   break
  end
 end
end
do -- the record: the count and the flag are checked
 for _,bad in {-1,0/0,math.huge,1.5,"2",true} do local b=R.new();b.contests=bad;check(not R.valid(b),`a contest count of {tostring(bad)} is refused`) end
 for _,bad in {1,"yes"} do local b=R.new();b.spared=bad;check(not R.valid(b),`a spared of {tostring(bad)} is refused`) end
 local g=R.new();g.contests=7;g.spared=true;check(R.valid(g),"a count and a flag are good")
 local n=R.new();R.renew(n);check(n.contests==0 and n.spared==nil,"a new rival has had no contests")
 local used=R.new();used.contests=9;R.renew(used);check(used.contests==0,"and renewing clears them")
end
do -- the cost goes through the needs model: 0.25, never below nothing, nothing in the gentle modes, a bad number nothing
 local m=Needs.new(true,false);m:configure({energy=.8})
 check(math.abs(m:injure(.25)-.25)<1e-12 and math.abs(m.energy-.55)<1e-12,"0.25 of the reserve is lost")
 m:configure({energy=.1});check(math.abs(m:injure(.25)-.1)<1e-12 and m.energy==0,"never below nothing: it loses what there was")
 check(m:injure(.25)==0 and m:injure(-1)==0 and m:injure(0/0)==0 and m.energy==0,"nothing to lose, or a bad number: nothing")
 local g=Needs.new(true,true);g:configure({energy=.8})
 check(g:injure(.25)==0 and g.energy==.8,"gentle: nothing")
 local heard={};local h=Needs.new(true,false);h:configure({energy=.9});h.onEnergyChanged=function(a,b) table.insert(heard,{a,b}) end
 h:injure(.25);check(#heard==1 and math.abs(heard[1][1]-.9)<1e-12 and math.abs(heard[1][2]-.65)<1e-12,"the energy-changed signal is told")
 local before=m.grantedTotal;check(before==0,"(it is no meal: the ledger is untouched)")
end
do -- the words
 check(RivalText.CAPTURED=="Caught the rival. Stay still to eat; worth two housefly meals." and RivalText.SPRANG=="It sprang clear of your strike." and RivalText.COUNTER=="It bit back! Jump away!","the three lines")
 check(RivalText.counter(false)==RivalText.COUNTER and string.find(RivalText.counter(true),"safe in this mode",1,true)~=nil and RivalText.counter(true)~=RivalText.counter(false),"gentle says you are safe")
 check(RivalText.strike("captured",false)==RivalText.CAPTURED and RivalText.strike("sprang",true)==RivalText.SPRANG and RivalText.strike("counter",true)==RivalText.COUNTER_GENTLE and RivalText.strike("warning",false)==nil,"each event has its line")
end
print(`RIVAL passed={passed} failed={failed}`)
if failed>0 then error("rival tests failed") end
