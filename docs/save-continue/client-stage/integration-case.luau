case("actual client and service preserve temporary play then confirm a retried durable checkpoint",function()
 local SaveClient=require("../src/Client/SaveClient")
 for i,mode in SaveRules.MODES do
  local e=newEnv();local uid=1700+i;local owner=newSession(e,uid,"owner")
  owner:load();local progress=prog({});progress.finished_main=true;owner:setProgress(progress)
  assert(owner:setRest(mode,realRest(120,mode)));run(e,owner,15)
  local original=canon(e.backend.data[owner.rkey[mode]])
  local srv=newServer(e);local p=player(uid);srv.service:addPlayer(p)
  local receiver;local cursor=0;local restores=0;local lostReceipt=false;local loadedCount=0
  local remotes={client={OnClientEvent={Connect=function(_,fn) receiver=fn end}},server={FireServer=function(_,msg) srv.service:onMessage(p,msg) end}}
  local client=SaveClient.new({rules=SaveRules,now=e.now,findRemotes=function() return remotes end,
   continuation={copy=Json.copy,validate=function(m,r,allowRetired)
    if allowRetired and SaveRest.isRetired(r) then return SaveRest.bounded(r,10,3)==nil and SaveRest.validLife(r.save_life) end
    return #SaveRest.check(m,r)==0
   end,onRestore=function(m,r) assert(m==mode and #SaveRest.check(m,r)==0);restores+=1 end},
   onLoaded=function() loadedCount+=1 end,onRest=function() error("bound route used legacy callback") end,onStatus=function() end,build=function() return prog({}) end})
  local function pump()
   local list=srv.sent[p] or {}
   while cursor<#list do
    cursor+=1;local msg=list[cursor]
    if msg.kind=="stored" and not lostReceipt then lostReceipt=true else receiver(msg) end
   end
  end
  local function step(n)
   for _=1,n do e.t+=1;client:update();srv.service:step();pump() end
  end
  client:update();pump();step(5)
  check(loadedCount==1 and client:status()=="session",mode..": live owner yields temporary connection")
  local offered=assert(client:offer(mode));check(client:continueLife(mode,offered.id) and restores==1,mode..": explicit actual checkpoint restoration")
  local localRest=realRest(240,mode);check(client:sendRest(mode,localRest),mode..": real candidate held while readonly")
  step(5)
  check(canon(e.backend.data[owner.rkey[mode]])==original and restores==1,mode..": temporary play cannot overwrite owner or rewind")
  owner:flush();step(100)
  local stored=SaveEnvelope.open(SaveRest.SPECS[mode],e.backend.data[owner.rkey[mode]] or {})
  local expected=Json.copy(localRest);expected.save_life=client.bound.requests[mode].life
  check(stored.status=="ok" and type(stored.payload.snapshot_tick)=="number" and canon(stored.payload)==canon(expected),mode..": unchanged ownership recovery stores the entire held world exactly")
  check(lostReceipt and client:status()=="saved",mode..": retry recovers a deliberately dropped durable receipt")
  check(restores==1,mode..": load/recovery/ack replies never restore twice")
  check(srv.count(p,"life")==0 and srv.count(p,"rest")==0,mode..": negotiated route exposes no legacy credentials/rests")
 end
end)

