-- Rare encounters: real modules in the CLI box-world, not native Studio evidence.
local Ledger=require("../src/Shared/Life/RareLedger")
local Director=require("../src/Shared/Life/RareDirector")
local Catalog=require("../src/Shared/Data/RareSightings")
local Environment=require("../src/Shared/World/Environment")
local Progress=require("../src/Shared/Persistence/SaveProgress")
local ObjectRecord=require("../src/Shared/Persistence/ObjectRecord")
local Body=require("../src/Client/RareBody")
local Book=require("../src/Shared/Learning/FieldNotebook")
local passed,failed=0,0
local function check(ok,msg) if ok then passed+=1 else failed+=1;print("FAIL RARE "..msg) end end
local function life() return {clock={day=1,hour=9},generation=0,lifeOver=false} end
local function eligible()
 for serial=1,200 do
  local plan=Director.plan(914,serial,1)
  if plan then
   local w=Environment.sample(plan.day,plan.hour,914)
   if w.temperature>=Catalog.luna.minTemperature and w.rain<=Catalog.luna.maxRain then return serial,plan end
  end
 end
 error("no fixture in search bound")
end
local serial,plan=eligible()
local history=Ledger.new();history.serial=serial-1
local spider=life();Director.beginLife(history,spider)
check(spider.rareSerial==serial and history.serial==serial,"new life allocates one identity")
local same=Director.plan(914,serial,1)
check(same and same.day==plan.day and same.hour==plan.hour,"plan deterministic")
check(Director.step(history,spider,914)==nil,"no early appearance")
spider.clock.day=plan.day;spider.clock.hour=plan.hour-.001
check(Director.step(history,spider,914)==nil,"no appearance just before appointment")
spider.clock.hour=plan.hour
local visitor=Director.step(history,spider,914)
check(visitor~=nil and history.claimed.luna_moth==serial,"scheduled warm dry night arrives")
local again=Director.step(history,spider,914)
check(again and again.serial==visitor.serial and spider.rareVisit.serial==serial,"ticks maintain same animal")
check(#Director.problems(spider)==0,"valid optional checkpoint fields")
local record=ObjectRecord.capture({life=spider},{},{})
-- Plain record serialization is exercised below via Json as well as graph encode/decode.
local Json=require("../src/Shared/Persistence/Json")
local encoded=Json.canonical(record)
check(type(encoded)=="string" and #encoded>0,"visit fits checkpoint graph JSON")
local decoded,decodeErrors=ObjectRecord.decode(record,{},{})
check(decoded and #decodeErrors==0 and decoded.roots.life.rareVisit.serial==serial,"checkpoint graph decodes visit identity")
local restored=life()
check(ObjectRecord.commit(decoded,{life=restored}) and Director.step(history,restored,914).serial==serial,"graph commit resumes same animal")
local snap=Progress.snapshot({opened={},eye_seconds=0},false,nil,{},nil,nil,history)
local errors,clean=Progress.sanitize(snap)
check(#errors==0 and clean.rare.claimed.luna_moth==serial,"history survives progress sanitize")
history.claimed.luna_moth=serial+1
check(snap.rare.claimed.luna_moth==serial,"snapshot does not alias live history")
history.claimed.luna_moth=serial
local old=life();old.rareSerial=serial;old.rareBorn=1;old.rareGeneration=0
old.clock.day=plan.day;old.clock.hour=plan.hour
check(Director.step(history,old,914)==nil,"rewound pre-arrival rest cannot roll another moth")
local loaded=table.clone(spider);loaded.clock=table.clone(spider.clock)
check(Director.step(history,loaded,914).serial==serial,"rest during visit reconstructs same identity")
loaded.clock.day=plan.day+1;loaded.clock.hour=6
check(Director.step(history,loaded,914)==nil,"dawn ends scheduled window")
loaded.clock.day=plan.day+5;loaded.clock.hour=21
check(Director.step(history,loaded,914)==nil,"skipping past night does not spawn late")
local legacy=life();Director.ensureLife(history,legacy)
check(legacy.rareSerial==serial and history.serial==serial,"legacy rest does not allocate another draw")
legacy.generation=1;Director.ensureLife(history,legacy)
check(legacy.rareSerial==serial+1,"next generation gets fresh identity")
local invalid=table.clone(spider);invalid.rareVisit={id="made_up",serial=serial,day=1,hour=21}
check(#Director.problems(invalid)>0,"unknown checkpoint visit refused")
invalid=life();invalid.rareVisit={}
check(#Director.problems(invalid)>0,"visit without identity refused")
for _,raw in {{serial=-1,claimed={},once={}},{serial=1,claimed={x=2},once={}},{serial=1,claimed={},once={x=false}},
 {serial=0/0,claimed={},once={}},{serial=1,claimed={},once={},blocked="yes"}} do
 check(Ledger.clean(raw)==nil,"malformed history refused")
end
local a,b=Ledger.new(),Ledger.new();a.serial=3;b.serial=5;a.claimed.luna_moth=3;b.claimed.luna_moth=5;a.once.atlas_moth=true
local merged=Ledger.merge(a,b)
check(merged.serial==5 and merged.claimed.luna_moth==5 and merged.once.atlas_moth,"merge keeps high-water marks and once-per-save claims")
check(Ledger.same(merged,Ledger.merge(b,a)),"merge order independent")
check(not Ledger.same(a,b) and Ledger.same(nil,Ledger.new()),"same preserves legacy empty record")
local oldSignature=Ledger.signature(merged);merged.claimed.luna_moth+=1
check(Ledger.signature(merged)~=oldSignature,"claim dirties progress even when page unseen")
for i=1,64 do a.once["a"..i]=true;b.once["b"..i]=true end
a.once.atlas_moth=nil
local overflow=Ledger.merge(a,b)
check(overflow.blocked and Ledger.clean(overflow)~=nil,"merge overflow stays bounded and fails closed")
overflow.serial=serial;local blocked=life();blocked.rareSerial=serial;blocked.rareGeneration=0;blocked.rareBorn=1
blocked.clock.day=plan.day;blocked.clock.hour=plan.hour
check(Director.step(overflow,blocked,914)==nil,"overflow cannot replay a discarded visit")
local base=Progress.default();local combined=Progress.merge(base,snap,1,0)
check(combined.rare.claimed.luna_moth==serial and not Progress.same(base,combined),"server merge keeps rare history from older packet")
check(Progress.same(base,Progress.snapshot({opened={},eye_seconds=0},false,nil,{})),"old callers keep old save shape")
-- One attempt per life, never a per-tick probability or weather reroll.
local rejected,dry=0,0
for index=1,240 do
 local seed=index*104729
 local h=Ledger.new();h.serial=index-1;local l=life();Director.beginLife(h,l)
 local p=Director.plan(seed,index,1)
 if p then
  l.clock.day=p.day;l.clock.hour=p.hour
  local w=Environment.sample(p.day,p.hour,seed)
  local v=Director.step(h,l,seed)
  check((v~=nil)==(w.temperature>=16 and w.rain<=.08),"weather gate follows scheduled front")
  if v then dry+=1 else rejected+=1 end
  l.clock.hour=23.9
  check((Director.step(h,l,seed)~=nil)==(v~=nil),"later weather cannot reroll arrival")
 end
end
check(dry>0 and rejected>0,`fixture covers arrival and weather refusal ({dry}/{rejected})`)
local winter=life();winter.clock.day=100;Director.beginLife(Ledger.new(),winter)
local wp=Director.plan(914,winter.rareSerial,100)
if wp then winter.clock.day=wp.day;winter.clock.hour=wp.hour end
check(Director.step(Ledger.new(),winter,914)==nil,"winter window cannot host luna")
-- Real drawer: no prey registration, bounded parts, safe wings and sight-gated notebook.
workspace:ClearAllChildren()
local root=Instance.new("Folder");root.Parent=workspace
local body=Body.new(root);local at=Catalog.luna.at
visitor.ageHours=0;body:update(visitor,.1,at+Vector3.new(30,0,0),false,false)
check(body.model and #body.parts==24 and #body.supports:GetChildren()==2,"bounded 24-part animal and two supports")
for _,part in body.supports:GetChildren() do check(not part.CanQuery and not part.CanCollide,"arrival supports inactive") end
visitor.ageHours=1;body:update(visitor,.1,at,false,false)
for _,part in body.supports:GetChildren() do check(part.CanQuery and part.CanCollide and not part.CanTouch,"settled wings support motor and silk") end
for _,part in body.parts do check(not part.CanQuery and not part.CanCollide and not part.CastShadow,"drawing cannot become prey or cast small shadows") end
local book=Book.new();check(book:view("rare_luna_moth")==nil,"no undiscovered page or checklist")
local camera=workspace.CurrentCamera;camera.CFrame=CFrame.lookAt(at+Vector3.new(0,4,12),at)
body:observe(.5,camera,at,book);check(not book:isOpen("rare_luna_moth"),"brief glance insufficient")
local wall=Instance.new("Part");wall.Size=Vector3.new(20,10,1);wall.Position=at+Vector3.new(0,1,6);wall.Parent=root
body:observe(1,camera,at,book);check(not book:isOpen("rare_luna_moth") and body.seen==0,"wall blocks discovery and resets gaze")
wall:Destroy();body:observe(.8,camera,at,book)
check(book:isOpen("rare_luna_moth"),"continuous unobstructed look opens page")
local inherited=Book.new();inherited:load(book:toRecord());check(inherited:isOpen("rare_luna_moth"),"page persists to next generation")
body:update(nil,4,at,true,false);check(body.model~=nil and body.leaving==0,"departure waits for spider or silk on wing")
body:update(nil,1,at+Vector3.new(30,0,0),false,true)
for _,part in body.supports:GetChildren() do check(not part.CanQuery,"departure removes abandoned supports") end
body:update(nil,3,at+Vector3.new(30,0,0),false,true)
check(body.model==nil and #root:GetChildren()==0,"departure cleans all presentation and supports")
visitor.ageHours=1;body:update(visitor,.1,at,false,true);body:clear()
check(body.model==nil and body.seen==0,"new life/rest can clear presentation")
-- Actual preserve client: fresh identities, dirty progress and modal pause.
local Map=require("../src/Shared/World/WorldMap")
local Build=require("../src/Shared/World/WorldBuild")
workspace:ClearAllChildren();workspace:SetAttribute("World","preserve");Map.use("preserve")
Build.world(workspace,Map.SEED,{})
local saveFolder=Instance.new("Folder");saveFolder.Name="SaveRemotes";saveFolder.Parent=game:GetService("ReplicatedStorage")
local callbacks={};local toClient=Instance.new("RemoteEvent");toClient.Name="ToClient";toClient.Parent=saveFolder
rawset(toClient,"OnClientEvent",{Connect=function(_,fn) table.insert(callbacks,fn) end})
local toServer=Instance.new("RemoteEvent");toServer.Name="ToServer";toServer.Parent=saveFolder
rawset(toServer,"FireServer",function() end)
local loaded,loadError=pcall(function() require("../src/Client/SpiderClient.client") end)
assert(loaded,loadError)
local d=assert(ClientStubs.driver);local frame=assert(ClientStubs.renderSteps.SpiderSim)
for _=1,5 do frame(1/60) end
check(d.fresh("free",false),"preserve client starts new life")
local n=d.life.rareSerial;check(n and d.rareHistory.serial==n,"fresh wired to rare history")
d.rareHistory.serial=serial-1;d.rareDirector.beginLife(d.rareHistory,d.life)
d.life.clock.day=plan.day;d.life.clock.hour=plan.hour+.1
d.place(Catalog.luna.at+Vector3.new(0,1,0))
for _=1,3 do frame(1/60) end
check(d.rareBody.model~=nil and d.rareHistory.claimed.luna_moth==serial,"real client draws scheduled encounter")
check(d.prey.feeding.held==nil,"ambient moth never enters feeding")
local bodyAge=d.rareBody.age;d.openMenu()
for _=1,3 do frame(1/60) end
check(d.rareBody.age==bodyAge,"menu freezes animal animation and observation")
check(d.fresh("free",false) and d.life.rareSerial==serial+1 and d.rareBody.model==nil,"next life clears visit without erasing history")
local identity=d.rareHistory;local incoming=Progress.default();incoming.rare=Ledger.new();incoming.rare.serial=1000;incoming.rare.claimed.luna_moth=1000
for _,fn in callbacks do fn({kind="loaded",status="saved",progress=incoming,rests={}}) end
check(#callbacks>0 and d.rareHistory==identity and identity.serial==1000 and identity.claimed.luna_moth==1000,"late progress merge preserves live history identity")
check(d.fresh("free",false) and d.life.rareSerial==1001,"next life advances beyond late-loaded high-water mark")
print(`RARE passed={passed} failed={failed}`)
if failed>0 then error("rare sightings failed") end
