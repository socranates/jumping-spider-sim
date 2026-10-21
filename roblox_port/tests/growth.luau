local Growth=require("../src/Shared/Life/Growth")
local LifeLoop=require("../src/Shared/Life/LifeLoop")
local Needs=require("../src/Shared/Life/NeedsModel")
local Session=require("../src/Shared/Life/LifeSession")
local Rig=require("../src/Shared/Rig/SpiderRig")
local Dance=require("../src/Shared/Rig/PeacockDance")
local Camera=require("../src/Client/SpiderCamera")
local OldSkins=require("../src/Client/OldSkins")
local Soundscape=require("../src/Client/Soundscape")
local reference=require("./growth_reference")
local passed,failed=0,0
local function check(v,msg) if v then passed+=1 else failed+=1;print("FAIL GROWTH "..msg) end end
local function same(a,b): boolean
 if type(a)~="table" then return if type(a)=="number" and type(b)=="number" then math.abs(a-b)<1e-8 else a==b end
 if type(b)~="table" then return false end
 for k,v in a do if not same(v,b[k]) then return false end end
 return true
end
local g=Growth.new()
do
 local text=require("../src/Shared/UI/ControlText")
 for _,device in {"keyboard","gamepad","touch"} do
  check(not string.find(string.lower(text.helpCard(device,false)),"run",1,true),device.." controls do not spoil run")
  check(string.find(string.lower(text.helpCard(device,true)),"run",1,true)~=nil,device.." acquired controls include run")
  check(string.find(text.runUnlocked(device),text.name(device,"run"),1,true)~=nil,device.." unlock explains correct control")
 end
 text.setPadStyle("playstation")
 check(string.find(text.runUnlocked("gamepad"),"L2",1,true)~=nil,"PlayStation unlock names L2")
 check(string.find(text.lockUnlocked("gamepad"),"L1",1,true)~=nil,"PlayStation lock unlock names L1")
 text.setPadStyle("xbox")
 for _,device in {"keyboard","gamepad","touch"} do
  check(not string.find(string.lower(text.helpCard(device,false,false)),"lock",1,true),device.." controls do not spoil lock")
 end
 local young=Growth.new()
 check(not young:canRun(),"new spider cannot sprint")
 check(not young:canLock(),"new spider cannot lock")
 young:eat(Growth.READY_FOOD)
 check(young.ready and not young:canRun(),"food alone does not unlock sprint")
 assert(young:beginMoult())
 young:passHours(Growth.MOULT_HOURS-.01,Vector3.zero)
 check(not young:canRun(),"unfinished first moult cannot sprint")
 young:passHours(.02,Vector3.zero)
 check(young.stage==1 and young:isSoft() and young:canRun(),"completed first moult unlocks sprint even while soft")
 check(not young:canLock(),"first moult does not unlock lock")
 check(young:speedFactor()==Growth.SOFT_SPEED,"unlock retains soft cuticle speed penalty")
 local loaded=Growth.new();assert(loaded:load(young:toRecord()))
 check(loaded:canRun(),"saved first instar retains sprint without unlock flag")
 loaded:eat(Growth.READY_FOOD);assert(loaded:beginMoult())
 check(not loaded:canRun(),"later moult immobilizes sprint too")
 check(not Growth.new():canRun(),"next generation starts without sprint")
end
for i,r in reference do
 local a=r.action;local result=nil
 if a.kind=="eat" then result=g:eat(a.n)
 elseif a.kind=="begin" then result=g:beginMoult()
 elseif a.kind=="hours" then result=g:passHours(a.n,Vector3.new(-25.5,.31,6))
 else local record=g:toRecord();g=Growth.new();assert(g:load(record)) end
 check(result==r.result,`golden {i} result`)
 check(same(g:toRecord(),r.record),`golden {i} state`)
 check(same(g:reachFactor(),r.reach) and same(g:softness(),r.softness) and g:stageName()==r.name,`golden {i} presentation`)
end
for _,n in {0/0,math.huge,-math.huge,-1,0} do
 local before=g:toRecord();g:eat(n);g:passHours(n,Vector3.zero)
 check(same(g:toRecord(),before),"invalid inputs do nothing")
end
local invalid=g:toRecord();invalid.stage=4
check(not g:load(invalid) and g.stage==3,"invalid restore changes nothing")
local s={inRetreat=true,attached=true,still=true,holding=false,feeding=false,position=Vector3.new(-25,.31,6)}
for _,fps in {30,60,144} do
 local n=Needs.new(true,false);local saves=0
 local life=LifeLoop.new(n,function() saves+=1;return {ok=true,message="Checkpoint kept."} end)
 n.grantedTotal+=.9
 life:step(1/fps,s,false,false)
 check(life.growth.ready and not life.resting,`{fps} actual food reaches threshold`)
 local outside=table.clone(s);outside.inRetreat=false
 life:step(1/fps,outside,true,false)
 check(not life.growth:isMoulting(),`{fps} cannot moult outside crack`)
 life:step(1/fps,s,true,false)
 check(life.growth:isMoulting() and saves==1,`{fps} rest starts and saves moult`)
 life:step(1/fps,s,true,true)
 check(life.resting and life.growth:isMoulting(),`{fps} inputs cannot cancel moult`)
 local loopRecord=life:toRecord()
 local restored=LifeLoop.new(n,nil);assert(restored:load(loopRecord))
 check(same(life.growth:toRecord(),restored.growth:toRecord()),`{fps} interrupted moult restored`)
 for _=1,math.ceil(12/1.4*fps) do life:step(1/fps,s,false,false) end
 check(life.growth.stage==1 and #life.growth.exuviae==1 and life.growth:isSoft() and saves==2,`{fps} completes once and saves`)
 check(life.growth:reachFactor()==.7,`{fps} soft reach`)
 life.grantedSeen=n.grantedTotal;life:step(1/fps,s,false,false)
 check(life.growth.fedSinceMoult==0,`{fps} food never counted twice`)
end
for _,mode in {"main","free"} do
 local session=Session.new();session:begin(mode,false)
 check(session:finishAdult(3)==(mode=="main"),"only main standard opens Easy")
 check(not session:finishAdult(3),"adult transition idempotent")
end
local floor=BoxWorld.folder("GrowthFloor",{{name="floor",lo=Vector3.new(-5,-1,-5),hi=Vector3.new(5,0,5),profile="painted_wood_dry"}})
for _,id in {"first_spider","maratus_volans_male"} do
 for _,tier in {"full","low"} do
  local rig=Rig.new(floor,floor,id,tier);rig.reducedMotion=true
  local body=CFrame.new(0,.31,0)
  rig:update(body,1/60,true,false)
  local baseSize=rig.model:FindFirstChild("Cephalothorax").Size
  local rootSize=rig.root.Size
  for stage=0,3 do
   rig:setGrowthStage(stage)
   local anchors={};for i,l in rig._legs do anchors[i]=l.foot end
   rig:update(body,0,true,false)
   for i,l in rig._legs do check((l.foot-anchors[i]).Magnitude<1e-6,"growth keeps planted feet") end
   -- (ROBLOX-114: a look's own growth, SpiderRig.growthScale: Growth.SCALES for the first spider, the peacock spider's to its real adult's 5 mm)
   check((rig.model:FindFirstChild("Cephalothorax").Size-baseSize*rig:growthScale(stage)/rig:growthScale(0)).Magnitude<1e-6,"body scaled per stage")
   check(id~="first_spider" or rig:growthScale(stage)==Growth.SCALES[stage+1],"the first spider grows by Growth's own scales")
   check((rig.root.Position-body.Position).Magnitude<1e-6 and rig.root.Size==rootSize,"collider frame and size unchanged")
   for _=1,15 do rig:update(body,1/30,true,false) end
   for _,l in rig._legs do check(l.planted~=nil and math.abs(l.foot.Y)<1e-5,"feet settle on floor") end
  end
  local head=rig.model:FindFirstChild("Cephalothorax");local color=head.Color
  rig:setSoftness(1);check(head.Color.R>color.R,"pale soft skin")
  rig:setSoftness(0);check(math.abs(head.Color.R-color.R)<1e-6 and math.abs(head.Color.G-color.G)<1e-6 and math.abs(head.Color.B-color.B)<1e-6,"pigment returns")
  rig:setCondition(0);rig:update(body,10,true,false)
  local small=rig.model:FindFirstChild("Abdomen").Size
  rig:setCondition(1);rig:update(body,10,true,false)
  check(rig.model:FindFirstChild("Abdomen").Size.X>small.X*1.3,"abdomen fills independently")
  if id=="maratus_volans_male" then
   rig.dance=Dance.rawPose(5.2,false);rig:update(body,1/60,true,false)
   check(rig._fan.front[1].part.Size.X>.4,"adult fan still opens")
   rig:setEyeView(true)
   check(rig._fan.front[1].part.LocalTransparencyModifier==1,"fan hidden in eye view")
  end
  rig:destroy()
 end
end
local params=RaycastParams.new();params.FilterDescendantsInstances={floor}
local camera={CameraType=nil,FieldOfView=70,CFrame=CFrame.identity,ViewportSize=Vector2.new(1280,720)}
local target={pos=Vector3.new(0,.31,0),drawnUp=Vector3.yAxis,heading=-Vector3.zAxis,cameraScale=.62}
local cam=Camera.new(camera,params,function() return target end,function() end);cam.mouse=false
local zoom=cam.distance
for _=1,120 do cam:tick(1/60) end
check(math.abs(cam:viewDistance()-zoom*.62)<.01 and cam.distance==zoom,"peacock closer without changing manual zoom")
target.cameraScale=1
for _=1,120 do cam:tick(1/60) end
check(math.abs(cam:viewDistance()-zoom)<.01,"first spider framing restored")
local skins=OldSkins.new(floor);skins:draw({Vector3.new(0,.31,0),Vector3.new(1,.31,0)})
check(#skins.folder:GetChildren()==18,"old skins rendered")
skins:draw({});check(#skins.folder:GetChildren()==0,"new life removes old skins")
local sound=Soundscape.new(floor)
check(sound.room.Volume<.12,"room hum quieter")
local LifeText=require("../src/Shared/UI/LifeText")
local progress=Growth.new()
check(string.find(LifeText.growth(progress,Growth.READY_FOOD,.35),"0 of 3 meals",1,true)~=nil,"fresh goal is three full houseflies")
progress:eat(.15);progress:eat(.3)
check(string.find(LifeText.growth(progress,Growth.READY_FOOD,.35),"1.5 of 3 meals",1,true)~=nil,"small prey contributes half a meal")
local restored=Growth.new();restored:load(progress:toRecord())
check(LifeText.growth(progress,.9,.35)==LifeText.growth(restored,.9,.35),"meal progress survives load")
restored:eat(.45)
check(string.find(LifeText.growth(restored,.9,.35),"Ready",1,true)~=nil,"ready gives the rest instruction")
restored.stage=3
check(string.find(LifeText.growth(restored,.9,.35),"Adult",1,true)~=nil,"adults have no further meal goal")
-- ROBLOX-88: the game asks for five housefly-equivalents to a moult (ten small prey), Godot's three stay Growth's defaults.
do
 check(Growth.READY_FOOD==.9 and Growth.game.moultFlies==5 and Growth.FLY_FOOD==.3,"the numbers: Godot's 0.9 for three flies, the game's five, a fly is 0.3")
 local godot,game=Growth.new(),Growth.new();game.stage=2;game:useGameRules()
 check(godot.readyFood==nil and godot.gameRules==nil and godot:mealGoal()==3 and math.abs(godot:readyAt()-.9)<1e-12,"a growth never given the game's rules is Godot's (three flies, 0.9)")
 check(game.gameRules==true and game:mealGoal()==5 and math.abs(game:readyAt()-1.5)<1e-12,"the game's is five flies, 1.5")
 for i=1,3 do godot:eat(.3) end
 check(godot.ready==true,"Godot's: three flies are ready")
 local ready=false
 for i=1,4 do ready=game:eat(.3) end
 check(game.ready==false and ready==false,"the game's: four flies are not ready")
 check(game:eat(.3)==true and game.ready==true,"the fifth is, and says so once")
 check(game:eat(.3)==false,"(and only once)")
 -- small prey count half: ten of them, not nine
 local small=Growth.new();small.stage=2;small:useGameRules()
 for i=1,9 do small:eat(.15) end
 check(small.ready==false,"nine small prey are 4.5 flies: not ready")
 check(small:eat(.15)==true and small.ready==true,"the tenth small prey is")
 -- the words
 local words=Growth.new();words.stage=2;words:useGameRules()
 check(string.find(LifeText.growth(words,Growth.READY_FOOD,.35),"0 of 5 meals",1,true)~=nil,"a fresh moult says 0 of 5 meals")
 words:eat(.3);words:eat(.15)
 check(string.find(LifeText.growth(words,Growth.READY_FOOD,.35),"1.5 of 5 meals",1,true)~=nil,"a fly and a small prey are 1.5 of 5")
 check(string.find(LifeText.growth(words,Growth.READY_FOOD,.35),"2 small prey = 1 housefly",1,true)~=nil,"and the small prey rule is still said")
 words:eat(.3);words:eat(.3);words:eat(.3)
 check(string.find(LifeText.growth(words,Growth.READY_FOOD,.35),"4.5 of 5 meals",1,true)~=nil,"4.5 of 5 before the last half")
 words:eat(.15);check(string.find(LifeText.growth(words,Growth.READY_FOOD,.35),"Ready",1,true)~=nil,"ready at five")
 -- food already eaten is kept when the game's rules arrive: two flies from an old record are 2 of 5, ready stays ready
 local old=Growth.new();old.stage=2;old:eat(.6)
 local rec=old:toRecord();local back=Growth.new();back:load(rec);back:useGameRules()
 check(string.find(LifeText.growth(back,Growth.READY_FOOD,.35),"2 of 5 meals",1,true)~=nil,"a record with two flies eaten reads 2 of 5")
 local was=Growth.new();was:eat(.9);local wrec=was:toRecord();local again=Growth.new();again:load(wrec);again:useGameRules()
 check(again.ready==true and string.find(LifeText.growth(again,Growth.READY_FOOD,.35),"Ready",1,true)~=nil,"a spider already ready stays ready")
 -- the records and goldens are untouched: the threshold is a rule, not data
 check(next(Growth.problems(game:toRecord()))==nil and game:toRecord().readyFood==nil,"the record is the same shape")
 -- the life loop credits the same food: five flies, as the client does (0.3 per fly), grow the spider the same way
 local needs=Needs.new(true);needs.energy=1
 local l=LifeLoop.new(needs);l.growth.stage=2;l.growth:useGameRules()
 for i=1,5 do l.mealFood=.3;l:_stepLife(1/60,Vector3.zero);check(l.growth.ready==(i==5),`the life loop: ready only at the fifth fly (fly {i})`) end
end
-- ROBLOX-91: the gentle modes keep three housefly-equivalents to a moult (Godot's, ROBLOX-61's); the five are the standard rules'. One credit formula for prey and rival.
do
 check(Growth.game.moultFlies==5 and Growth.game.gentleMoultFlies==3,"the numbers: five standard, three gentle")
 local std,gentle=Growth.new(),Growth.new();std.stage=2;gentle.stage=2;std:useGameRules(false);gentle:useGameRules(true)
 check(std:mealGoal()==5 and gentle:mealGoal()==3 and math.abs(std:readyAt()-1.5)<1e-12 and math.abs(gentle:readyAt()-.9)<1e-9,"the thresholds: 1.5 for five flies, 0.9 for three")
 check(Growth.new().readyFood==nil and (function() local g=Growth.new();g.stage=2;g:useGameRules();return g:mealGoal()==5 end)(),"no argument is the standard rules (the client's old call)")
 local ready=false
 for i=1,2 do ready=gentle:eat(.3) end
 check(not gentle.ready and not ready,"gentle: two flies are not ready")
 check(gentle:eat(.3)==true and gentle.ready,"and the third is, once")
 for i=1,3 do std:eat(.3) end
 check(not std.ready,"standard: three are not")
 -- small prey: six in the gentle modes
 local small=Growth.new();small.stage=2;small:useGameRules(true)
 for i=1,5 do small:eat(.15) end
 check(not small.ready and small:eat(.15) and small.ready,"gentle: the sixth small prey")
 -- the words (the HUD's "of N meals")
 local words=Growth.new();words.stage=2;words:useGameRules(true)
 check(string.find(LifeText.growth(words,Growth.READY_FOOD,.35),"0 of 3 meals",1,true)~=nil,"gentle reads 0 of 3 meals")
 words:eat(.3);words:eat(.15)
 check(string.find(LifeText.growth(words,Growth.READY_FOOD,.35),"1.5 of 3 meals",1,true)~=nil,"a fly and a small prey are 1.5 of 3")
 words:eat(.45);check(string.find(LifeText.growth(words,Growth.READY_FOOD,.35),"Ready",1,true)~=nil,"ready at three")
 local sw=Growth.new();sw.stage=2;sw:useGameRules(false);sw:eat(.3)
 check(string.find(LifeText.growth(sw,Growth.READY_FOOD,.35),"1 of 5 meals",1,true)~=nil,"standard reads of 5")
 -- the life loop credits it
 local needs=Needs.new(true,true);needs.energy=1
 local l=LifeLoop.new(needs);l.growth.stage=2;l.growth:useGameRules(needs.gentle)
 for i=1,3 do l.mealFood=.3;l:_stepLife(1/60,Vector3.zero);check(l.growth.ready==(i==3),`gentle life loop: ready only at the third fly (fly {i})`) end
 -- one credit formula: a housefly (0.35) credits 0.3 and a whole rival (0.7) two flies' worth
 check(math.abs(Growth.rivalCredit(.35)-.3)<1e-12 and math.abs(Growth.rivalCredit(.7)-.6)<1e-12 and Growth.rivalCredit(0)==0,"credit: a housefly 0.3, a rival 0.6")
 check(Growth.mealsOf(.7)==2 and Growth.mealsOf(.35)==1 and Growth.mealsOf(.175)==1 and Growth.mealsOf(1.05)==3,"meals of the energy: two for a rival")
 local RivalSpider=require("../src/Shared/Predator/RivalSpider")
 check(Growth.mealsOf(RivalSpider.FOOD)==2 and require("../src/Shared/UI/RivalText").eating(Growth.mealsOf(RivalSpider.FOOD))=="Eating rival — stay still (2 meals)","the status text is derived: (2 meals)")
end
-- First and second moults: Nathan's seven and ten full fly meals, in every game mode.
for _,gentle in {false,true} do
 local growing=Growth.new();growing:useGameRules(gentle)
 for stage,goal in {7,10} do
  check(growing.stage==stage-1 and growing:mealGoal()==goal,"instar-specific meal goal")
  for meal=1,goal-1 do
   growing:eat(Growth.FLY_FOOD)
   check(not growing.ready,`stage {stage-1}: {meal} full flies cannot moult`)
  end
  local restored=Growth.new();assert(restored:load(growing:toRecord()));restored:useGameRules(gentle)
  check(restored:mealGoal()==goal and not restored.ready,"save retains meals and derives the current instar goal")
  check(restored:eat(Growth.FLY_FOOD) and restored.ready,"last whole fly reaches the threshold exactly")
  assert(restored:beginMoult());restored:passHours(Growth.MOULT_HOURS,Vector3.zero)
  check(restored.fedSinceMoult==0 and not restored.ready,"moult resets food before the next threshold")
  check(restored:canLock()==(stage==2),"lock unlocks only at the second completed moult")
  growing=restored
 end
 check(growing:mealGoal()==(if gentle then 3 else 5),"third moult keeps its existing mode-specific requirement")
 local half=Growth.new();half:useGameRules(gentle)
 for _=1,13 do half:eat(Growth.FLY_FOOD/2) end
 check(not half.ready and half:eat(Growth.FLY_FOOD/2),"fourteen half meals count as seven whole flies")
end
print(`GROWTH passed={passed} failed={failed}`)
if failed>0 then error("growth checks failed") end
