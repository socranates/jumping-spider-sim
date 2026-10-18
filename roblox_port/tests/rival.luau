local R=require("../src/Shared/Predator/RivalSpider")
local Species=require("../src/Shared/Data/Species")
local Needs=require("../src/Shared/Life/NeedsModel")
local passed,failed=0,0
local function check(ok,msg) if ok then passed+=1 else failed+=1;print("FAIL rival: "..msg) end end
local function player()
 return {position=Vector3.new(15,.31,8),previous=Vector3.new(15,.31,8),heading=Vector3.xAxis,day=2,meals=1,
 hour=12,resting=false,safe=false,wasp=false,gentle=false,grounded=true,moving=false,airborne=false,onLine=false,holding=false,striking=false}
end
local clear=function() return false end
local Grip=require("../src/Shared/Predator/RivalGrip")
-- Fights a held rival the way the client does each tick (the rival's step, then the grip's) with a tap every 1/rate s from `start` s: the outcome
-- ("subdued", "tore" or "timeout") and the seconds it took. rate 0 is no taps at all. `g` is the grip, if the caller keeps one.
local function fight(r,s,rate,limit,start,g)
 g=g or Grip.new();local t,nextTap=0,start or .2
 for _=1,math.floor((limit or 40)*60) do
  t+=1/60
  R.step(r,1/60,s,clear)
  if rate>0 and t>=nextTap then Grip.tap(g);nextTap+=1/rate end
  local e=Grip.step(g,r,1/60,s)
  if e=="subdued" or e=="tore" then return e,t end
 end
 return "timeout",t
end
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
check(r.subdued==false,"a caught rival is held but not yet subdued (ROBLOX-77)")
s.striking=false;check(fight(r,s,5.5)=="subdued" and r.subdued==true,"and the player subdues it with the tapping grip before it is eaten")
s.moving=true
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
 if fight(r,s,5.5)~="subdued" then return false end
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
 check(RivalText.CAPTURED=="Caught the rival! It fights back. Tap to keep your grip." and RivalText.SPRANG=="It sprang clear of your strike." and RivalText.COUNTER=="It bit back! Jump away!","the three lines")
 check(RivalText.counter(false)==RivalText.COUNTER and string.find(RivalText.counter(true),"safe in this mode",1,true)~=nil and RivalText.counter(true)~=RivalText.counter(false),"gentle says you are safe")
 check(RivalText.strike("captured",false)==RivalText.CAPTURED and RivalText.strike("sprang",true)==RivalText.SPRANG and RivalText.strike("counter",true)==RivalText.COUNTER_GENTLE and RivalText.strike("warning",false)==nil,"each event has its line")
end
-- ---------------------------------------------------------------- a caught rival is a hard meal (ROBLOX-77)
local Catch=require("../src/Shared/Data/Catch")
local Feeding=require("../src/Shared/Prey/Feeding")
-- A rival just caught on `day` by a strike at one that had not noticed (no draw): the rival and the spider's state, ready to fight.
local function held(day,gentle)
 local r=R.new();r.state="patrol";r.position=Vector3.new(24,.31,8);r.previous=r.position
 local s=strike(r,day,gentle);s.seed=914
 assert(R.step(r,1/60,s,clear)=="captured")
 s.striking=false;s.previous=s.position
 return r,s
end
do -- the numbers, pinned: its own, not the fly's scaled
 local k=Catch.rival
 check(k.startGrip==.6 and k.tapGain==.085 and k.jerkScale==.8 and k.drainScale==.5 and k.tire==.25 and k.cap==math.huge,"the rival's numbers: grip 0.6, a tap 0.085, drain x0.5, jerks 0.8, tires to 0.75, no cap")
 check(k.tapGain<Catch.game.tapGain,"a tap is worth less than a house fly's (0.12)")
 local full,gentle=Catch.forRival(false),Catch.forRival(true)
 check(full.startGrip==.6 and full.cap==math.huge and gentle.cap==math.huge,"neither has a cap: it is never subdued by waiting")
 check(gentle.tapGain==Catch.game.tapGain and gentle.jerkScale==Catch.game.jerkScale and gentle.startGrip==Catch.game.startGrip and gentle.drainScale==1 and gentle.tire==.5,"gentle is the house fly's struggle")
 local f=Feeding.new();f:useRivalRules(false);check(f.tapGain==.085 and f.cap==math.huge and f.game==false,"a controller given the rival's rules has them")
end
do -- held: a caught rival is not eaten until it is subdued; no time runs toward the meal while it fights
 local r,s=held(5)
 check(r.state=="captured" and r.subdued==false and R.struggling(r) and R.valid(r),"caught: held, not subdued, a good record")
 local g=Grip.new()
 local events={}
 for i=1,100 do
  local e,food=R.step(r,1/60,s,clear);events[e]=true
  check(food==0 and r.food==R.FOOD,"nothing is eaten while it fights")
  local ge=Grip.step(g,r,1/60,s);events[ge]=true
  if ge~="" and ge~="begin" then break end
 end
 check(events.struggling and events.begin,"it struggles (the sim says so) and the grip begins once")
 check(Grip.active(g) or r.state~="captured","(and the grip is active while the rival is held)")
 r.food=R.FOOD
end
do -- subdued: the same tapping, then eaten as before (stay still, 0.7, "eaten", the day kept)
 local r,s=held(6)
 local out,t=fight(r,s,5.5,20)
 check(out=="subdued" and r.state=="captured" and r.subdued==true and not R.struggling(r),`steady 5.5 taps a second subdues it ({t} s)`)
 check(r.food==R.FOOD,"nothing eaten yet at the moment it is subdued")
 s.moving=true;local _,f0=R.step(r,1/60,s,clear);check(f0==0,"walking pauses eating, as before")
 s.moving=false;local total,ticks,last=0,0,""
 for _=1,600 do local e,n=R.step(r,1/60,s,clear);total+=n;ticks+=1;if e~="feeding" then last=e;break end end
 check(last=="eaten" and math.abs(total-.7)<1e-8 and r.state=="consumed" and r.fate=="eaten" and r.day==6,`eaten: exactly 0.7 once, fate eaten, day kept`)
 check(math.abs(ticks/60-5)<.05,`and the five seconds of eating start only after it is subdued ({ticks/60} s)`)
 check(R.subdue(r)==false and R.tearFree(r)==false and not R.struggling(r),"a consumed rival cannot be subdued or torn free")
end
do -- the feel (60 rivals, taps evenly spaced from 0.2 s, standard rules)
 local function stats(rate,gentle,limit,start,auto)
  local won,lost,tw,tl,lo,hi,top=0,0,0,0,math.huge,0,0
  for day=2,61 do
   local r,s=held(day,gentle);s.auto=auto
   local out,t=fight(r,s,rate,limit or 40,start)
   if out=="subdued" then won+=1;tw+=t;lo=math.min(lo,t);hi=math.max(hi,t) elseif out=="tore" then lost+=1;tl+=t;top=math.max(top,t) end
  end
  return won,lost,if won>0 then tw/won else 0,if lost>0 then tl/lost else 0,lo,hi,top
 end
 local w0,l0,_,t0=stats(0,false)
 check(w0==0 and l0==60 and t0>=1.7 and t0<=2.4,`no taps: it tears free every time, after {t0} s on average (about 2 s; the house fly 1.1 s)`)
 local w2,l2=stats(2,false);local w3,l3=stats(3,false)
 check(w2==0 and l2==60 and w3==0,`2 taps a second tear free every time (won {w2}, lost {l2}) and 3 never subdue it in 40 s (won {w3}, tore free {l3}, the rest still holding on)`)
 local w4,l4,t4,_,lo4,hi4=stats(4,false)
 check(w4==60 and l4==0 and lo4>=5.2 and hi4<=9.7 and t4>=6.3 and t4<=8.3,`4 a second wins every time in {lo4} to {hi4} s (mean {t4})`)
 local w5,l5,t5=stats(5,false);local w6,_,t6=stats(6,false)
 check(w5==60 and w6==60 and t5<t4 and t6<t5 and t6<3,`5 and 6 a second win sooner ({t5} s, {t6} s)`)
 local wl,ll=stats(4,false,40,.5)
 check(wl==60 and ll==0,`a first tap as late as 0.5 s still wins at 4 a second (won {wl})`)
 -- a lapse costs: a one-second pause at three seconds delays the win by several seconds; a three-second pause loses it
 local function lapse(len,at)
  local won,lost,tw=0,0,0
  for day=2,61 do
   local r,s=held(day,false);local g=Grip.new();local t,nextTap=0,.2
   for _=1,40*60 do
    t+=1/60;R.step(r,1/60,s,clear)
    if t>=nextTap then if not (t>=at and t<at+len) then Grip.tap(g) end;nextTap+=1/4 end
    local e=Grip.step(g,r,1/60,s)
    if e=="subdued" then won+=1;tw+=t;break elseif e=="tore" then lost+=1;break end
   end
  end
  return won,lost,if won>0 then tw/won else 0
 end
 local lw,ll1,lt=lapse(1,3);check(lw==60 and lt>t4+2,`a one-second lapse at 3 s costs {lt-t4} s more (won {lw})`)
 local _,l3s=lapse(3,3);check(l3s==60,`a three-second lapse loses it every time (lost {l3s})`)
 -- the house fly for comparison, same taps, same limit: the rival needs more
 local hf=0
 for day=2,61 do local r,s=held(day,true);if fight(r,s,3,40)=="subdued" then hf+=1 end end
 check(hf==60,`(the gentle rival is the house fly's struggle: 3 taps a second win it every time, {hf} of 60)`)
 -- gentle: the house fly's struggle, no cap
 local gw0,gl0,_,gt0=stats(0,true)
 check(gw0==0 and gl0==60 and gt0>=1.0 and gt0<=1.45,`gentle, no taps: it tears free after {gt0} s (the fly's)`)
 local gw4,_,gt4=stats(4,true)
 check(gw4==60 and gt4<t4,`gentle 4 a second wins sooner than standard ({gt4} s against {t4} s)`)
 -- automatic grip needs no taps in either
 local aw,al,at=stats(0,false,40,nil,true);local gaw=stats(0,true,40,nil,true)
 check(aw==60 and gaw==60,`automatic grip subdues it with no taps (standard {aw}, gentle {gaw}; {at} s)`)
 print(string.format("RIVAL feel: no taps tears free in %.2f s; 3 a second never wins; 4 a second wins in %.1f to %.1f s (mean %.1f); 5 in %.1f; 6 in %.1f; gentle idle %.2f s, gentle 4 in %.1f s, automatic grip alone %.1f s, a 1 s lapse at 3 s costs %.1f s",t0,lo4,hi4,t4,t5,t6,gt0,gt4,at,lt-t4))
end
do -- no cap: waiting never subdues it. A rival held for a minute with an occasional tap that cannot keep up is not subdued by the clock
 local r,s=held(7);local g=Grip.new();local t,nextTap=0,.2
 local out="timeout"
 for _=1,60*90 do
  t+=1/60;R.step(r,1/60,s,clear)
  if t>=nextTap then Grip.tap(g);nextTap+=1/3.2 end -- barely enough to hold on without ever climbing
  local e=Grip.step(g,r,1/60,s);if e=="subdued" or e=="tore" then out=e;break end
 end
 check(out~="timeout" or R.struggling(r),"a thin tapper never gets a free subdue")
 local f=Feeding.new();f:useRivalRules(false);f:capture(r);f.elapsed=1000;f.grip=.3
 f:struggle(1/60,true,function() end)
 check(f.struggling==true and f.grip<1,"even after a very long time the clock subdues nothing (a fly's cap is 12 s)")
 local fly=Feeding.new();fly:capture({profile=Species.fly_like_prototype,nutrition=.35,state="CAPTURED",captureKey="k"});fly.elapsed=13;fly.grip=.3
 fly:step(1/60,true,false,function() end);check(fly.struggling==false and fly.note=="Subdued.","(the fly still is, at 12 s)")
end
do -- tearing free: simply gone from the fangs, to recover; nothing drawn, nothing lost, no early respawn, its day and its meal kept
 local r,s=held(8);local c=r.contests
 local out,t=fight(r,s,0,10)
 check(out=="tore" and r.state=="recover" and r.subdued==nil and not R.struggling(r),`no taps: it tears free to recover after {t} s`)
 check(r.contests==c and r.food==R.FOOD and r.day==nil and r.fate==nil and r.notice==0 and R.valid(r),"no new draw, still a whole rival with its meal, no day or fate, a good record")
 -- it is not a free catch or a new rival: it goes on as one rival
 local arrivals=0
 s.hour=12
 for _=1,60*4 do R.step(r,1/60,s,clear) end
 check(r.state=="patrol" or r.state=="stalk" or r.state=="windup","three seconds on it patrols again")
 s.day=9;s.hour=7.2;R.step(r,1/60,s,clear)
 check(r.state~="dormant" and r.food==R.FOOD and r.contests==c,"the next morning it is the same rival (not renewed, not dormant)")
 -- it can be caught again, and the second fight is its own
 local r2,s2=held(8);fight(r2,s2,0,10)
 r2.position=s2.position+Vector3.xAxis*.2;r2.previous=r2.position
 s2.striking=true;s2.previous=s2.position
 check(R.step(r2,1/60,s2,clear)=="captured" and R.struggling(r2),"a recovering rival can be caught again (recover is a free catch, ROBLOX-73), and it fights again")
 -- tearing free never harms the spider: no event of harm, whatever the mode
 for _,gentle in {false,true} do
  local g1,g2=held(10,gentle)
  local harmed=false
  local grip=Grip.new()
  for _=1,600 do
   local e=R.step(g1,1/60,g2,clear);if e=="caught" or e=="touch" or e=="counter" then harmed=true end
   local ge=Grip.step(grip,g1,1/60,g2);if ge=="tore" then break end
  end
  check(not harmed and g1.state=="recover",`tearing free harms nothing (gentle {tostring(gentle)})`)
 end
end
do -- the same encounter fights the same way (a stream of its own from the world's seed, the day and the rival's contest count)
 local a,sa=held(11);local b,sb=held(11)
 local o1,t1=fight(a,sa,3.6,30);local o2,t2=fight(b,sb,3.6,30)
 check(o1==o2 and t1==t2,"the same day and count: the same fight")
 local diff=false
 for day=12,30 do local c,sc=held(day);local _,tc=fight(c,sc,3.6,30);if tc~=t1 then diff=true end end
 check(diff,"another day is another fight")
end
do -- records and old records
 local r=R.new();r.state="captured";check(R.valid(r) and not R.struggling(r),"a held rival with no flag (an older record) is good and is eaten as it always was")
 r.subdued=false;check(R.valid(r) and R.struggling(r),"a held, struggling rival is a good record")
 for _,bad in {1,"yes",0} do local b=R.new();b.state="captured";b.subdued=bad;check(not R.valid(b),`a subdued of {tostring(bad)} is refused`) end
 local used=R.new();used.state="consumed";used.subdued=true;R.renew(used);check(used.subdued==nil and used.state=="dormant","a new rival has no flag")
 -- an old captured record: eaten without a fight
 local o=R.new();o.state="captured";local s=player();s.position=Vector3.new(24,.31,8);s.previous=s.position
 local total=0
 for _=1,400 do local _,n=R.step(o,1/60,s,clear);total+=n end
 check(math.abs(total-.7)<1e-8 and o.state=="consumed","an older held rival is eaten with no struggle")
 -- a restored held-and-fighting record has no grip behind it: whoever finds it begins a fresh one (the grip is scratch, never recorded)
 local rec=R.new();rec.state="captured";rec.subdued=false;local s2=player();local g=Grip.new()
 check(Grip.step(g,rec,1/60,s2)=="begin" and Grip.active(g),"a held rival not yet subdued begins a fresh grip")
 rec.state="patrol";rec.subdued=nil
 check(Grip.step(g,rec,1/60,s2)=="" and not Grip.active(g),"and the grip lets go if the rival is no longer held")
end
do -- the words
 check(string.find(RivalText.CAPTURED,"fights back",1,true)~=nil and string.find(RivalText.CAPTURED,"Tap",1,true)~=nil,"the catch line tells the player to tap")
 check(string.find(RivalText.SUBDUED,"Stay still to eat",1,true)~=nil and string.find(RivalText.SUBDUED,"two housefly meals",1,true)~=nil,"the subdued line has the old eating words")
 check(RivalText.tore(false)==RivalText.TORE and RivalText.tore(true)==RivalText.TORE_GENTLE and string.find(RivalText.TORE_GENTLE,"safe in this mode",1,true)~=nil,"tearing free: gentle says you are safe")
 check(RivalText.struggle("Space")=="Holding the rival — tap Space to keep your grip","the status line has the fly's words for the rival")
end
print(`RIVAL passed={passed} failed={failed}`)
if failed>0 then error("rival tests failed") end
