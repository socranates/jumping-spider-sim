do
local Reader=__offerReaderPrototype
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local SaveSession=require("../src/Shared/Persistence/SaveSession")
local Work=require("../src/Shared/Persistence/SaveWork")
local count=0
local function check(ok,why) assert(ok,why);count+=1 end
local function artifacts(a)
 return {progress={format=__archiveStorePrototype.FORMAT,version=1,owner="46001",index=a.index,progress=a.entries.progress},
 main=a.entries.main,free=a.entries.free,easy=a.entries.easy,index={format=__archiveStorePrototype.FORMAT,version=1,owner="46001",complete=true,index=a.index}}
end
local parts=artifacts(archive)
local originalSource=Json.canonical(source)
local currentMap=WorldMap.regions()
local cold=assert(Reader.prepare("46001","main",rest,nil,{},codec,fresh))
check(not cold.pending and cold.protected and cold.identity.checksum==rest.checksum and cold.identity.life==source.save_life,"cold original offer differs")
local compressed=codec:encode(rest)
local compressedOffer=assert(Reader.prepare("46001","main",compressed,nil,{},codec,fresh))
check(Json.canonical(compressedOffer.record)==Json.canonical(cold.record),"compressed original view changed")
local bad=Json.copy(rest);bad.checksum="corrupt"
check(Reader.prepare("46001","main",bad,nil,{},codec,fresh)==nil,"corrupt primary silently selected backup")
check(assert(Reader.prepare("46001","main",bad,nil,{},codec,fresh,"backup")).identity.kind=="backup","explicit valid backup not offered")
check(Reader.prepare("46001","main",Envelope.make(SaveRest.SPECS.main,template,100,nil),nil,{},codec,fresh)==nil,"ordinary Preserve save became a legacy import")
for _,raw in {rest,anchor.target} do
 local pending=assert(Reader.prepare("46001","main",raw,anchor,parts,codec,fresh))
 check(pending.pending and pending.archivePlan.index.checksum==archive.index.checksum and pending.identity.checksum==rest.checksum,"pending original/target discovery failed")
end
check(Reader.prepare("46001","main",second.target,anchor,parts,codec,fresh)==nil,"different opaque target accepted as persisted proposal")
check(Reader.prepare("other","main",anchor.target,anchor,parts,codec,fresh)==nil,"foreign owner proposal exposed")
check(Reader.prepare("46001","free",anchor.target,anchor,parts,codec,fresh)==nil,"foreign slot proposal exposed")
check(Reader.prepare("46001","main",anchor.target,anchor,parts,codec,fresh,"backup")==nil,"pending primary changed to another backup selection")
for _,field in {"index","main","progress","free","easy"} do
 local changed=Json.copy(parts);changed[field]={future=true}
 check(Reader.prepare("46001","main",anchor.target,anchor,changed,codec,fresh)==nil,"invalid complete archive artifact accepted: "..field)
end
local missing=Json.copy(parts);missing.index=nil
check(Reader.prepare("46001","main",anchor.target,anchor,missing,codec,fresh)==nil,"missing complete index repaired by read-only discovery")
local function fixture(raw,pending,id)
 local b=Memory.new();b.readRawFresh=b.read;b.readFresh=b.read;b.updateRaw=b.update
 b:poke("P_46001",Json.copy(rawProgress));b:poke("R_46001_main",Json.copy(raw or rest))
 if pending then
  b:poke(anchor.id,Json.copy(anchor));for key,value in parts do b:poke("A1_46001_"..key,Json.copy(value)) end
 end
 local clock={now=200};local emitted=0
 local s=SaveSession.new({backend=b,userId=46001,sessionId=id or "offer-A",now=function() return clock.now end,onOffer=function() emitted+=1 end})
 assert(s:load()=="active");s:enableOffers()
 local r=Reader.new(s,codec,fresh,{work={now=function() return 0 end}});local j=assert(r:begin("main"))
 return b,clock,s,r,j,function() return emitted end
end
local function step(b,clock,s,r,j)
 local before=b.requests;r:step(j)
 check(b.requests-before<=1,"offer reader issued more than one request")
 check(#s.sched.started<=10,"offer reader exceeded shared quota")
 clock.now+=1
end
local function drive(b,clock,s,r,j,hook)
 for tick=1,900 do if j.state~="pending" then return end;if hook then hook(tick) end;step(b,clock,s,r,j) end
 error("offer reader did not settle")
end
do
 local b,clock,s,r,j,emitted=fixture();local before=Json.canonical(b.data);local writes=b.writes;drive(b,clock,s,r,j)
 check(j.state=="offered" and j.requests==2 and j.offer.protected and not j.pending,"cold async offer failed: "..tostring(j.problem))
 check(b.writes==writes and Json.canonical(b.data)==before and emitted()==1,"read-only reader wrote/emitted incorrectly")
 check(s.intents.requests.main==nil and s.lifeTokens.main==nil,"reader granted a life/intent")
 local originalLife=s:offer("main").record.save_life;j.offer.record.save_life="forged-public"
 check(s:offer("main").record.save_life==originalLife,"public offer mutation changed server observation")
end
do
 local b,clock,s,r,j=fixture(anchor.target,true,"pending-reader");local before=Json.canonical(b.data);drive(b,clock,s,r,j)
 check(j.state=="offered" and j.pending and j.requests==7 and j.archivePlan~=nil,"pending raw target failed discovery: "..tostring(j.problem))
 check(Json.canonical(b.data)==before,"pending reader modified save/archive/proposal")
 assert(s:requestLife("continue","main",1,j.offer.id))
 local c=__commitControllerPrototype.new(s,codec,b,template,fresh,{work={now=function() return 0 end}})
 local commit=assert(c:begin("main",1,j.offer.id,j.archivePlan));drive(b,clock,s,c,commit)
 check(commit.state=="verified" and not commit.result.gameplayAuthorized,"reader-based resumed commit failed: "..tostring(commit.problem))
end
for _,raw in {rest,compressed} do
 local b,clock,s,r,j=fixture(raw,false,"cold-reader");drive(b,clock,s,r,j);assert(j.state=="offered",j.problem)
 assert(s:requestLife("continue","main",1,j.offer.id))
 local c=__archiveControllerPrototype.new(s,{restCodec=codec,work={now=function() return 0 end}})
 local a=assert(c:begin("main",1,j.offer.id,"reader-cold-source"));drive(b,clock,s,c,a)
 check(a.state=="ready","actual cold archive admission failed: "..tostring(a.problem))
 local commit=__commitControllerPrototype.new(s,codec,b,template,fresh,{work={now=function() return 0 end}})
 local job=assert(commit:begin("main",1,j.offer.id,a.plan));drive(b,clock,s,commit,job)
 check(job.state=="verified" and s.intents.requests.main.credential==nil,"actual reader/archive/commit pipeline failed: "..tostring(job.problem))
 print("RECOVERY_OFFER_READER cold_reads="..j.requests.." archive_requests="..a.requests.." commit_requests="..job.requests)
end
do
 local b,clock,s,r,j=fixture();b:fail({op="read",key="R_46001_main",times=1,message="503: read unavailable"});drive(b,clock,s,r,j)
 check(j.state=="offered" and j.requests==3,"failed read defaulted/refused retry")
end
do
 local b,clock,s,r,j=fixture();local before=Json.canonical(b.data)
 drive(b,clock,s,r,j,function() if j.phase=="prepare" then assert(s:requestLife("new","main",1,nil)) end end)
 check(j.state=="cancelled" and s:offer("main")==nil and Json.canonical(b.data)==before,"higher intent did not cancel discovery")
end
do
 local b,clock,s,r,j=fixture();local read=b.readRawFresh;local nested=false
 b.readRawFresh=function(self,key) local before=self.requests;nested=s:step()==false and self.requests==before;s._loadSerial+=1;return read(self,key) end
 step(b,clock,s,r,j)
 check(nested and j.state=="cancelled" and s:offer("main")==nil,"superseded load/reentrant ordinary worker published stale offer")
end
do
 local b,clock,s,r,j=fixture();assert(r:cancel(j));local before=b.requests;r:step(j)
 check(j.state=="cancelled" and b.requests==before,"cancelled reader resurrected")
end
local ticks=0;local function now() ticks+=.000001;return ticks end
local worker=Work.new(function() return Reader.prepare("46001","main",anchor.target,anchor,parts,codec,fresh) end,{now=now,budget=.000001,maxSeconds=100,maxResumes=20000})
local suspensions=0
while worker.state=="pending" do worker:step();if worker.state=="pending" then suspensions+=1 end end
local prepared=worker:take();check(prepared and prepared[1] and prepared[1].pending and suspensions>0,"cooperative pending offer preparation failed")
check(Json.canonical(source)==originalSource and WorldMap.regions()==currentMap,"reader changed original/live map")
print("RECOVERY_OFFER_READER passed="..count.." failed=0 suspensions="..suspensions)
end
