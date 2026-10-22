-- Borrowed vs owned delivery, bounded preparation, independent protocol channels.
local Continuation=require("../src/Client/SaveContinuation")
local Work=require("../src/Shared/Persistence/SaveWork")
local Json=require("../src/Shared/Persistence/Json")
local Rules=require("../src/Shared/Data/SaveRules")
local passed,failed=0,0
local function check(ok,why) if ok then passed+=1 else failed+=1;print("FAIL SAVE_OFFERS "..why) end end
local function offer(mode,id,value,big)
 local record={mode=mode,value=value,items={}}
 if big then for i=1,1000 do record.items[i]={id=i} end end
 return {id=id,protected=false,record=record}
end
local function fixture()
 local clock=0;local counts={validate=0,offers=0,loaded=0}
 local cfg={rules=Rules,copy=Json.copy,offerWork={new=Work.new,options={budget=.001,maxSeconds=1000,now=function() clock+=.001;return clock end}},
  validate=function(mode,r)
   counts.validate+=1
   return type(r)=="table" and r.mode==mode and type(r.value)=="number" and Json.canonical(r)~=nil
  end,
  onLoaded=function() counts.loaded+=1 end,
  onOffer=function(_,info) counts.offers+=1;check(info==nil or info.record==nil,"offer callback carries metadata only") end}
 return Continuation.new(cfg),counts,cfg
end
local function loaded(c,offers,owned,epoch)
 local msg={kind="loaded",v=3,epoch=epoch or "one",sequence=1,status="saved",offers=offers or {}}
 return if owned then c:receiveOwned(msg) else c:receive(msg)
end
local function deliver(c,mode,seq,value,epoch)
 return c:receiveOwned({kind="offer",epoch=epoch or "one",sequence=seq,mode=mode,offer=value})
end
local function finish(c)
 for _=1,10000 do if not c:offerPending() then break end;c:stepOffers() end
 check(not c:offerPending(),"bounded offer preparation terminates")
end
local c,counts,cfg=fixture();local borrowed=offer("main","a",7,true)
loaded(c,{main=borrowed},false);borrowed.record.value=999
check(c:offer("main").record.value==7 and not c:offerPending(),"ordinary receive copies borrowed data before returning")
c,counts,cfg=fixture();local owned=offer("main","a",7,true)
loaded(c,{main=owned},true)
check(c:offer("main")==nil and c:offerPending("main") and counts.loaded==1,"handshake/progress applies while owned record stays private")
check(not c:choose("main","new") and not c:choose("main","continue","a"),"unvalidated observation cannot authorize a choice")
c:stepOffers();check(c:offerPending() and c:offer("main")==nil,"large validation yields before publication")
c:receiveOwned({kind="status",epoch="one",sequence=8,status="session",reason="other_session"})
check(c:status()=="session","independent authority loss applies immediately during preparation")
finish(c)
local view=c:offer("main");view.record.value=800
check(c:offer("main").record.value==7 and c.offers.main.record~=owned.record,"prepared offer is private from delivery and public preview")
check(c:status()=="session","finishing an older offer cannot undo newer authority loss")
deliver(c,"main",9,offer("main","b",9,true));c:stepOffers();deliver(c,"main",10,nil);finish(c)
check(c:offer("main")==nil and c.offerJobs.main==nil and c.offerQueue.main==nil,"withdrawal cancels older work and releases its record")
c,counts,cfg=fixture();loaded(c,{main=offer("main","same",1,true)},true)
deliver(c,"main",2,offer("main","same",200,true));finish(c)
check(c:offer("main").record.value==1 and c.offerSeq.main==2,"queued repeat cannot redefine an immutable id accepted mid-preparation")
local n=counts.validate
for seq=3,8 do deliver(c,"main",seq,offer("main","same",900,true)) end
check(counts.validate==n and not c:offerPending() and c:offer("main").record.value==1,"known immutable repeats do not queue or revalidate")
c,counts,cfg=fixture();loaded(c,{main=offer("main","same",1,true)},true)
local conflict=offer("main","same",2,true);conflict.protected=true;deliver(c,"main",2,conflict);finish(c)
check(not c:offerInfo("main").protected and c:offer("main").record.value==1,"queued protection conflict cannot redefine accepted observation")
c,counts,cfg=fixture();loaded(c,{main=offer("main","old",1)},false)
deliver(c,"main",2,offer("main","valid",2,true))
deliver(c,"main",3,offer("free","invalid",3,true));finish(c)
check(c:offerInfo("main").id=="valid" and c:offer("main").record.value==2,"invalid newer replacement cannot erase a valid active result")
deliver(c,"main",4,offer("main","slow",4,true));c:stepOffers()
c:receive({kind="offer",epoch="one",sequence=20,mode="main",offer=offer("main","newest",20)})
finish(c)
check(c:offerInfo("main").id=="newest" and c.offerJobs.main==nil,"new synchronous observation fences out older worker result")
deliver(c,"main",21,offer("main","slow",21,true));c:stepOffers()
deliver(c,"main",22,offer("main","newest",900));finish(c)
check(c:offerInfo("main").id=="newest" and c:offer("main").record.value==20,"newer known repeat cancels a competing older preparation")
c,counts,cfg=fixture();loaded(c,{},false)
for seq=2,1002 do deliver(c,"main",seq,offer("main","id_"..seq,seq)) end
local retained=0
for _,jobs in {c.offerJobs,c.offerQueue} do for _ in jobs do retained+=1 end end
check(retained==2,"burst retains one active and one latest replacement for a slot")
check(counts.offers<=4,"coalesced burst does not trigger a repaint per packet")
finish(c);check(c:offer("main").record.value==1002,"coalescing eventually presents latest valid observation")
c,counts,cfg=fixture();local values={}
for _,mode in Rules.MODES do values[mode]=offer(mode,mode,1,true) end
loaded(c,values,true)
for _=1,3 do c:stepOffers() end
local resumes=0
for _,mode in Rules.MODES do resumes+=c.offerJobs[mode].work.resumes end
check(resumes==3,"one resume per frame is fairly shared across all three slots")
finish(c)
for _,mode in Rules.MODES do check(c:offer(mode).record.mode==mode,mode..": independent prepared slot") end
c,counts,cfg=fixture();deliver(c,"main",2,offer("main","early",2,true));loaded(c,{},true);finish(c)
check(c:offerInfo("main").id=="early","pre-handshake owned offer survives older empty handshake")
c,counts,cfg=fixture();deliver(c,"main",2,offer("main","foreign",2,true),"foreign")
loaded(c,{main=offer("main","actual",1,true)},true,"actual");finish(c)
check(c:offerInfo("main").id=="actual","old buffered epoch cannot suppress current handshake observation")
c,counts,cfg=fixture();loaded(c,{main=offer("main","old",1)},false)
cfg.offerWork.options.maxResumes=1;deliver(c,"main",2,offer("main","too-long",2,true));finish(c)
check(c:offerInfo("main").id=="old" and c:offerReadProblem(),"exhausted preparation preserves previous validated rest and exposes a truthful read problem")
cfg.offerWork.options.maxResumes=10000;deliver(c,"main",3,offer("main","recovered",3));finish(c)
check(not c:offerReadProblem() and c:offerInfo("main").id=="recovered","successful retry clears the read problem without editing the old rest")
c,counts,cfg=fixture();loaded(c,{main=offer("main","old",1)},false)
deliver(c,"main",2,offer("main","pending",2,true));c:stepOffers();c:closeOffers()
deliver(c,"main",3,offer("main","late",3,true))
check(not c:offerPending() and c.offerJobs.main==nil and c:offerInfo("main").id=="old","closed worker releases pending input and ignores later owned offers")
print(`SAVE_OFFERS passed={passed} failed={failed}`)
assert(failed==0,"offer preparation failures")
