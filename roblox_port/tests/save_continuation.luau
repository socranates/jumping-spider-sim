-- Scripted protocol3 transport; no native or online evidence.
local Continuation=require("../src/Client/SaveContinuation")
local Rules=require("../src/Shared/Data/SaveRules")
local Json=require("../src/Shared/Persistence/Json")
local passed,failed=0,0
local function check(ok,why) if ok then passed+=1 else failed+=1;print("FAIL CONTINUATION "..why) end end
local function setup(extra)
 local restored,sent={},{}
 local cfg={rules=Rules,copy=Json.copy,validate=function(mode,r,retired)
  return type(r)=="table" and ((r.save_retired==true and retired) or r.mode==mode and type(r.value)=="number")
 end,onRestore=function(mode,r) table.insert(restored,{mode=mode,record=r}) end}
 for k,v in extra or {} do cfg[k]=v end
 return Continuation.new(cfg),restored,sent,function(msg) table.insert(sent,msg) end
end
local function offer(mode,id,value) return {id=id,protected=false,record={mode=mode,value=value}} end
local function loaded(c,seq,mode,value,status)
 return c:receive({kind="loaded",v=3,epoch="one",sequence=seq,status=status or "saved",offers={[mode]=offer(mode,"a",value)}})
end
local function decision(c,mode,seq,rev,state,credential)
 local r=c.requests[mode]
 return c:receive({kind="decision",epoch="one",sequence=seq,decision={mode=mode,kind=r.kind,serial=r.serial,
  offerId=r.offerId,revision=rev,state=state,credential=credential,life="life"}})
end
local function receipt(c,mode,seq,kind,serial,credential,ticket)
 return c:receive({kind=kind,epoch="one",sequence=seq,mode=mode,serial=serial,credential=credential,restSerial=ticket,
  reason=if kind=="refused" then "invalid_checkpoint" else nil})
end
for _,mode in Rules.MODES do
 local c,restored,sent,send=setup()
 check(not c:choose(mode,"new"),mode.." no pre-handshake retirement")
 check(loaded(c,1,mode,7),mode.." handshake")
 local preview=c:offer(mode);preview.record.value=999
 check(c:offer(mode).record.value==7,mode.." private offer")
 check(c:choose(mode,"continue","a") and #restored==1,mode.." explicit Continue restores once")
 restored[1].record.value=500
 check(c.requests[mode].selected.value==7,mode.." callback cannot mutate selected record")
 c:receive({kind="offer",epoch="one",sequence=4,mode=mode,offer=offer(mode,"b",8)})
 c:receive({kind="status",epoch="one",sequence=3,status="session",reason="other_session"})
 check(c:status()=="session" and c:offer(mode).id=="b",mode.." later offer does not discard independent loss status")
 decision(c,mode,5,1,"readonly")
 check(#restored==1 and c.requests[mode].selected.value==7,mode.." decisions cannot rebase or rewind")
 local candidate={mode=mode,value=9};check(c:checkpoint(mode,candidate),mode.." checkpoint while temporary")
 candidate.value=777;c:update(0,send)
 check(#sent==1 and sent[1].kind=="life_intent",mode.." temporary sends intent only")
 decision(c,mode,6,2,"writable","grant1")
 c:receive({kind="status",epoch="one",sequence=7,status="saved"})
 check(c:status()=="saving",mode.." generic Saved insufficient")
 c:update(5,send);local p=sent[#sent]
 check(p.kind=="rest" and p.record.value==9 and p.credential=="grant1",mode.." sends held immutable candidate")
 p.record.value=200
 check(c.requests[mode].candidate.record.value==9,mode.." transport cannot mutate ticket")
 local s=c.requests[mode].serial;local ticket=c.requests[mode].candidate.serial
 receipt(c,mode,8,"stored",s,"wrong",ticket);receipt(c,mode,9,"stored",s,"grant1",ticket+1)
 check(c:status()=="saving",mode.." unknown credential and ticket refused")
 c:update(10,send)
 check(sent[#sent].restSerial==ticket and sent[#sent].record.value==9,mode.." lost receipt retries same ticket")
 receipt(c,mode,10,"stored",s,"grant1",ticket)
 check(c:status()=="saved",mode.." durable receipt enables Saved")
 c:checkpoint(mode,{mode=mode,value=10});c:update(15,send);local newer=sent[#sent].restSerial
 receipt(c,mode,11,"stored",s,"grant1",ticket)
 check(c:status()=="saving",mode.." old receipt cannot clear newer checkpoint")
 receipt(c,mode,12,"refused",s,"grant1",newer)
 local st,why=c:status();check(st=="saving" and why=="rest_refused",mode.." ticket-specific refusal")
 local n=#sent;c:update(20,send);check(#sent==n,mode.." refused ticket stops retrying")
 check(c:checkpoint(mode,{mode=mode,value=11}),mode.." valid candidate after refusal")
 c:update(25,send);local final=sent[#sent].restSerial
 c:receive({kind="status",epoch="one",sequence=15,status="session",reason="other_session"})
 check(c.requests[mode].credential==nil and c.requests[mode].candidate.record.value==11,mode.." loss retains world and revokes permission")
 decision(c,mode,16,3,"writable","grant2");c:update(30,send)
 receipt(c,mode,17,"stored",s,"grant1",final)
 check(not c.requests[mode].candidate.stored,mode.." revoked credential cannot acknowledge")
 c:receive({kind="loaded",v=3,epoch="one",sequence=20,status="saved",offers={[mode]=offer(mode,"c",30)},
  decisions={[mode]={mode=mode,kind="continue",serial=s,offerId="a",revision=3,state="writable",credential="grant2",life="life"}}})
 receipt(c,mode,19,"stored",s,"grant2",final)
 check(c:status()=="saved" and #restored==1,mode.." loaded has no receipt floor and never restores again")
 decision(c,mode,21,4,"changed");decision(c,mode,22,5,"writable","forbidden")
 check(c.requests[mode].state=="changed" and c.requests[mode].credential==nil,mode.." changed is terminal")
 check(not c:choose(mode,"continue","a"),mode.." stale displayed id refused")
 check(c:choose(mode,"new","c"),mode.." New supersedes Continue")
 receipt(c,mode,23,"stored",s,"grant2",final)
 check(c.requests[mode].kind=="new" and c.requests[mode].candidate==nil,mode.." superseded queues stay discarded")
 check(not c:receive({kind="status",epoch="other",sequence=999,status="saved"}),mode.." other epoch refused")
end
local function permute(xs,fn,k)
 k=k or 1;if k>#xs then fn(xs);return end
 for i=k,#xs do xs[k],xs[i]=xs[i],xs[k];permute(xs,fn,k+1);xs[k],xs[i]=xs[i],xs[k] end
end
permute({1,2,3},function(order)
 local c=setup();local messages={
  {kind="loaded",v=3,epoch="one",sequence=1,status="saved",offers={main=offer("main","a",1)}},
  {kind="status",epoch="one",sequence=2,status="session",reason="other_session"},
  {kind="offer",epoch="one",sequence=3,mode="main",offer=offer("main","b",2)}}
 for _,i in order do c:receive(messages[i]);c:receive(messages[i]) end
 check(c:status()=="session" and c:offer("main").id=="b","delivery permutations converge despite duplicates")
end)
do
 local c,_,sent,send=setup();loaded(c,1,"main",1)
 for _,mode in Rules.MODES do
  if mode~="main" then c:receive({kind="offer",epoch="one",sequence=2,mode=mode,offer=offer(mode,"a",1)}) end
  c:choose(mode,"continue","a");c:refresh(mode)
 end
 for t=0,25,5 do c:update(t,send) end
 local counts={};for _,m in sent do local k=m.kind..":"..m.mode;counts[k]=(counts[k] or 0)+1 end
 for _,mode in Rules.MODES do check(counts["life_intent:"..mode]==1 and counts["refresh_offer:"..mode]==1,"fair lifecycle queue "..mode) end
end
do
 local c;local restores=0
 c=setup({onRestore=function(mode,_r) restores+=1;c:choose(mode,"new","a") end})
 loaded(c,1,"main",1);c:choose("main","continue","a")
 check(restores==1 and c.requests.main.kind=="new" and c.requests.main.serial==2,"reentrant selection supersedes outer Continue")
end
do
 local c=setup();loaded(c,1,"main",1);c:choose("main","continue","a")
 c:receive({kind="status",epoch="one",sequence=5,status="session",reason="other_session"})
 decision(c,"main",4,1,"writable","old")
 check(c.requests.main.credential==nil,"old grant cannot defeat newer loss status")
 c:receive({kind="offer",epoch="one",sequence=6,mode="main",offer={id="marker-a",protected=false,record={save_retired=true,save_life="marker"}}})
 check(not c:choose("main","continue","marker-a") and c:choose("main","new","marker-a"),"marker permits deliberate New only")
end
-- Exercise the actual SaveClient adapter with callback reentrancy and legacy fallback.
do
 local SaveClient=require("../src/Client/SaveClient")
 for _,oldPeer in {false,true} do
  local now=0;local wire={};local receive;local loads=0;local restores=0;local client
  local opts={copy=Json.copy,validate=function(mode,r,retired) return type(r)=="table" and r.mode==mode and type(r.value)=="number" end,
   onRestore=function(_mode,r) restores+=1;r.value=800 end}
  local remotes={client={OnClientEvent={Connect=function(_self,fn) receive=fn end}},server={FireServer=function(_self,msg) table.insert(wire,msg) end}}
  client=SaveClient.new({rules=Rules,now=function() return now end,findRemotes=function() return remotes end,continuation=opts,
   onLoaded=function(_msg) loads+=1;check(not client:waiting(),"adapter publishes ready state before callback") end,
   onRest=function() error("bound messages must not use legacy rest callback") end,onStatus=function() end,build=function() return {intro_seen=true} end})
  client:markDirty();client:update()
  check(#wire==1 and wire[1].kind=="hello" and wire[1].v==3,"explicit adapter negotiates3 without premature progress upload")
  if oldPeer then
   receive({kind="loaded",v=2,status="saved",rests={main={mode="main",value=1}},progress={}})
   check(loads==1 and client:status()=="session","old peer fallback is temporary")
   check(not client:beginLife("main") and not client:sendRest("main",{mode="main",value=2}),"fallback refuses retirement and rest uploads")
   now=5;client:update()
   check(#wire==2 and wire[2].kind=="progress","fallback still merges bounded notebook progress")
  else
   receive({kind="loaded",v=3,epoch="adapter",sequence=1,status="saved",offers={main=offer("main","a",1)},progress={}})
   check(loads==1 and client:connected(),"bound adapter receives coherent handshake")
   check(not client:beginLife("main"),"New must receive the displayed id rather than silently adopting the latest offer")
   check(client:continueLife("main","a") and restores==1,"bound adapter explicit restoration")
   check(client:sendRest("main",{mode="main",value=2}),"bound adapter holds temporary checkpoint")
   now=5;client:update();local intent=wire[#wire]
   check(intent.kind=="life_intent" and intent.intent=="continue","bound adapter routes explicit intent")
   receive({kind="decision",epoch="adapter",sequence=2,decision={mode="main",kind="continue",serial=intent.serial,offerId="a",revision=1,state="writable",credential="grant",life="life"}})
   now=10;client:update();local rest=wire[#wire]
   check(rest.kind=="rest" and rest.restSerial==1 and rest.credential=="grant" and client:status()=="saving","adapter requires durable ticket receipt")
   receive({kind="stored",epoch="adapter",sequence=3,mode="main",serial=intent.serial,credential="grant",restSerial=1})
   check(client:status()=="saved" and restores==1,"adapter receipt confirms without repeating restoration")
  end
 end
end
do
 local c=setup()
 for n=1,100 do
  for _,mode in Rules.MODES do c:receive({kind="offer",epoch="one",sequence=n+1,mode=mode,offer=offer(mode,"latest",n)}) end
 end
 local count=0;for _ in c.buffer do count+=1 end
 check(count==3,"pre-handshake offer flood retains at most one bounded record per slot")
 loaded(c,1,"main",1)
 check(c:offer("main").record.value==100 and next(c.buffer)==nil,"handshake drains newest matching offers without retaining old buffer")
 local before=c:offer("main").id
 c:receive({kind="offer",epoch="one",sequence=200,mode="main",offer={id="bad",protected=false,record={mode="wrong",value=4}}})
 check(c:offer("main").id==before,"invalid preview cannot replace the displayed snapshot")
 c:receive({kind="offer",epoch="one",sequence=201,mode="main",offer=nil})
 check(c:offer("main")==nil and not c:choose("main","continue",before),"withdrawal prevents selection of a vanished offer")
end
do
 local c=setup();loaded(c,1,"main",1);c:choose("main","continue","a")
 decision(c,"main",2,1,"writable","grant");c:checkpoint("main",{mode="main",value=2})
 local serial=c.requests.main.serial
 c:update(0,function(msg)
  if msg.kind=="rest" then receipt(c,"main",3,"stored",serial,"grant",msg.restSerial) end
 end)
 check(c:status()=="saved","synchronous receipt sees committed issued ticket")
 c:checkpoint("main",{mode="main",value=3})
 c:update(5,function(msg)
  if msg.kind=="rest" then
   c:checkpoint("main",{mode="main",value=4})
   receipt(c,"main",4,"stored",serial,"grant",msg.restSerial)
  end
 end)
 check(c:status()=="saving" and c.requests.main.candidate.record.value==4,"reentrant new capture cannot be cleared by outer send acknowledgement")
 c:update(10,function(msg)
  if msg.kind=="rest" then receipt(c,"main",5,"stored",serial,"grant",msg.restSerial) end
 end)
 check(c:status()=="saved","reentrant newer candidate eventually receives its own receipt")
end
do
 for _,throws in {false,true} do
  local c=setup({onRestore=function() if throws then error("restore failed") end;return false end})
  loaded(c,1,"main",1)
  check(not c:choose("main","continue","a") and c:decision("main")==nil,"failed restore abandons new permission path")
  local packets=0;c:update(0,function() packets+=1 end)
  check(packets==0,"failed restore sends no continuation or checkpoint")
 end
 local c=setup();loaded(c,1,"main",1)
 local info=c:offerInfo("main");info.id="mutated"
 check(c:offerInfo("main").id=="a" and c:offerInfo("main").record==nil,"menu metadata is private and carries no full world copy")
end
do
 local copies,validations,events=0,0,0
 local c=Continuation.new({rules=Rules,copy=function(v) copies+=1;return Json.copy(v) end,
  validate=function(mode,r) validations+=1;return type(r)=="table" and r.mode==mode and type(r.value)=="number" end,
  onOffer=function(mode,info) if info then events+=1;check(mode=="main" and info.record==nil and info.playable,"offer callback carries metadata, not an unused full world copy") end end})
 loaded(c,1,"main",7)
 check(copies==1 and validations==1,"new offer is validated and privately copied once")
 local n=copies;local v=validations
 c:receive({kind="offer",epoch="one",sequence=5,mode="main",offer=offer("main","a",999)})
 check(copies==n and validations==v and c:offerInfo("main").id=="a","repeat id reuses validated private observation without extra work")
 check(c:offer("main").record.value==7,"changed repeat body cannot mutate immutable accepted offer")
 c:receive({kind="offer",epoch="one",sequence=4,mode="main",offer=nil})
 check(c:offerInfo("main")~=nil and events==1,"repeat watermark rejects stale withdrawal without repaint")
 local clash=offer("main","a",9);clash.protected=true
 c:receive({kind="offer",epoch="one",sequence=6,mode="main",offer=clash})
 check(not c:offerInfo("main").protected,"conflicting protection cannot redefine the same immutable id")
end
do
 local SaveClient=require("../src/Client/SaveClient")
 local function peer(enabled)
  local f={now=0,wire={},entries={},selected=0,restored=0,loaded=0};local deliver;local client
  local remotes={client={OnClientEvent={Connect=function(_self,fn) deliver=fn end}},server={FireServer=function(_self,msg) table.insert(f.wire,msg) end}}
  client=SaveClient.new({rules=Rules,now=function() return f.now end,findRemotes=function() return remotes end,
   continuation={copy=Json.copy,validate=function(mode,r) return type(r)=="table" and r.mode==mode and type(r.value)=="number" end,
    onRestore=function() f.restored+=1;return true end},
   recovery=if enabled then {onSelected=function(mode,serial) f.selected+=1;return if f.whenSelected then f.whenSelected(client,mode,serial) else true end,onEntry=function(o,epoch,sequence) table.insert(f.entries,{offer=o,epoch=epoch,sequence=sequence}) end} else nil,
   onLoaded=function() f.loaded+=1;f.readyInCallback=client:recoveryReady() end,onRest=function() error("legacy restore callback") end,onStatus=function() end,build=function() return {} end})
  f.client=client;f.deliver=function(msg) deliver(msg) end
  function f.load(cap,protected)
   f.deliver({kind="loaded",v=3,epoch="cap",sequence=10,status="saved",recovery=cap,
    offers={main={id="protected",protected=protected,record={mode="main",value=1}}}})
  end
  function f.entry(sequence)
   return {kind="recovery_entry",epoch="cap",sequence=sequence,offer={v=1,id="entry",epoch="cap",mode="main",serial=client.bound.serial,revision=1,
    identity={checksum="1234567890abcdef",updatedAt=123},checkpoint={}}}
  end
  function f.receipt()
   local o=f.entries[#f.entries].offer
   return {kind="recovery_applied",v=1,id=o.id,epoch=o.epoch,mode=o.mode,serial=o.serial,revision=o.revision,identity=Json.copy(o.identity)}
  end
  client:update();return f
 end
 for _,cap in {false,1,2,"1",{},0/0,math.huge} do
  for _,enabled in {false,true} do
   local f=peer(enabled);local c=f.client
   check(f.wire[1].recovery==(if enabled then 1 else nil),"only clients with both recovery callbacks advertise support")
   f.deliver(f.entry(1));check(#f.entries==0 and not c:recoveryReady(),"entry admitted before matching handshake")
   f.load(if cap~=false then cap else nil,true)
   local accepted=enabled and cap==1
   check(c:recoveryReady()==accepted and f.readyInCallback==accepted,"capability not ready before loaded callback or wrongly enabled")
   check(c:continueLife("main","protected"),"capability changed normal Continue admission")
   check(f.selected==(if accepted then 1 else 0) and f.restored==(if accepted then 0 else 1),"protected recovery restored the preview or old peer lost existing behavior")
   f.deliver(f.entry(11));check(#f.entries==(if accepted then 1 else 0),"entry callback ignored negotiated capability")
   f.deliver({kind="loaded",v=3,epoch="cap",sequence=12,status="saved",recovery=if accepted then nil else 1})
   check(c:recoveryReady()==accepted,"later loaded snapshot changed frozen capability")
  end
 end
 local f=peer(true);local c=f.client
 f.load(1,true);check(c:continueLife("main","protected"),"negotiated selection")
 for _,change in {
  function(m) m.sequence=10 end,function(m) m.sequence=0/0 end,function(m) m.epoch="other" end,
  function(m) m.offer.serial+=1 end,function(m) m.offer.mode="free" end,function(m) m.offer.id=string.rep("x",161) end,
  function(m) m.offer.revision=0 end,function(m) m.offer.identity.checksum="bad" end,function(m) m.offer.identity.updatedAt=math.huge end,
 } do local m=f.entry(20);change(m);f.deliver(m);check(#f.entries==0,"invalid or stale entry reached application") end
 local msg=f.entry(20);f.deliver(msg);f.deliver(msg)
 check(#f.entries==1 and f.entries[1].epoch=="cap" and f.entries[1].sequence==20,"entry sequence watermark not committed before callback")
 local receipt=f.receipt();local n=#f.wire
 for _,field in {"id","epoch","mode","serial","revision"} do local bad=Json.copy(receipt);bad[field]="wrong";check(not c:sendRecoveryApplied(bad) and #f.wire==n,"wrong receipt was forwarded") end
 local bad=Json.copy(receipt);bad.identity.updatedAt+=1;check(not c:sendRecoveryApplied(bad),"different identity receipt admitted")
 receipt.extra={unbounded="must not be forwarded"};check(c:sendRecoveryApplied(receipt),"current bounded receipt refused")
 local sent=f.wire[#f.wire];check(sent.extra==nil and sent.identity~=receipt.identity and sent.identity.checksum==receipt.identity.checksum,"wire receipt retained arbitrary fields or application identity")
 local repeatEntry=f.entry(21);f.deliver(repeatEntry);check(#f.entries==2,"new delivery of same entry must permit an idempotent ACK retry")
 local changed=f.entry(22);changed.offer.identity.updatedAt+=1;f.deliver(changed);check(#f.entries==2,"immutable entry id was redefined")
 check(c:abortContinue("main",c.bound.serial,"cap"),"cancel current recovery selection")
 n=#f.wire;check(not c:sendRecoveryApplied(receipt) and #f.wire==n,"cancelled selection sent a receipt")
 f.deliver(f.entry(23));check(#f.entries==2,"cancelled selection adopted a late entry")
 local normal=peer(true);normal.load(1,false);check(normal.client:continueLife("main","protected") and normal.restored==1 and normal.selected==0,"ordinary compatible checkpoint was deferred as recovery")
 local switched=peer(true);switched.load(1,true);switched.client:continueLife("main","protected");switched.deliver(switched.entry(20));local oldReceipt=switched.receipt()
 check(switched.client:beginLife("free"),"later mode selection did not begin")
 switched.deliver(switched.entry(21));check(#switched.entries==1 and not switched.client:sendRecoveryApplied(oldReceipt),"another mode's new life retained old recovery authority")
 local reentrant=peer(true);reentrant.load(1,true)
 reentrant.whenSelected=function(client) client:beginLife("free");return true end
 check(not reentrant.client:continueLife("main","protected") and reentrant.client.activeSlot=="free","outer selection overwrote reentrant new life")
 reentrant.deliver(reentrant.entry(20));check(#reentrant.entries==0,"reentrant new life accepted superseded entry")
 local cancelled=peer(true);cancelled.load(1,true)
 cancelled.whenSelected=function(client,mode,serial) client:abortContinue(mode,serial,"cap");return true end
 check(not cancelled.client:continueLife("main","protected"),"synchronously cancelled callback reported active recovery")
 local old=peer(true);old.deliver({kind="loaded",v=2,status="saved",rests={main={mode="main",value=1}},progress={}})
 old.deliver(old.entry(20));check(old.client.legacyTemporary and not old.client:recoveryReady() and #old.entries==0,"old server negotiated new recovery")
 local invalid=pcall(function() SaveClient.new({rules=Rules,now=function() return 0 end,recovery={onEntry=function() end}}) end)
 check(not invalid,"incomplete recovery callbacks may not advertise support")
 local copies,selected=0,0
 local bounded=setup({copy=function(value) copies+=1;return Json.copy(value) end,recoveryVersion=1,onProtectedSelected=function() selected+=1;return true end,
  onRestore=function() error("protected preview was copied for restore") end})
 bounded:receive({kind="loaded",v=3,recovery=1,epoch="one",sequence=1,status="saved",offers={main={id="legacy",protected=true,record={mode="main",value=1}}}})
 local before=copies;check(bounded:choose("main","continue","legacy") and selected==1,"protected metadata-only choice was not deferred")
 check(copies==before and bounded.requests.main.selected==nil,"protected choice copied or retained an unused legacy graph")
end
print(`SAVE_CONTINUATION passed={passed} failed={failed}`)
assert(failed==0,"continuation failures")
