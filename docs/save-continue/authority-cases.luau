-- Appended to default state.luau; real checkpoints and scripted store failures.
local function authorityFixture(uid,mode,foreign,legacy)
 local e=newEnv();local owner=newSession(e,uid,"original-owner");assert(owner:load()=="active")
 if mode=="easy" then owner:setProgress(prog({},{finished=true})) end
 if not legacy then owner:beginLife(mode,1);run(e,owner,15) end
 assert(owner:setRestForLife(mode,realRest(120,mode),owner.lifeTokens[mode]));run(e,owner,15)
 if not foreign then owner:flush(e.t+20) end
 local decisions={};local s=newSession(e,uid,"bound-visitor",{onDecision=function(value) table.insert(decisions,value) end})
 s:load();s:enableOffers();run(e,s,3)
 assert(s:offer(mode),"fixture requires an actual observed rest")
 return e,s,owner,decisions
end
local function grantContinue(e,s,mode,serial)
 local offer=assert(s:offer(mode));assert(s:requestLife("continue",mode,serial,offer.id));run(e,s,2)
 local r=assert(s.intents.requests[mode]);assert(r.state=="writable","fixture did not grant continuation")
 return r
end

case("bound Continue requires a separate acknowledged credential in all slots",function()
 for i,mode in SaveRules.MODES do
  local e,s,_,decisions=authorityFixture(1400+i,mode,false,false);local offer=s:offer(mode)
  local before=canon(e.backend.data[s.rkey[mode]])
  check(not s:setRestForLife(mode,realRest(240,mode),offer.record.save_life) and not s:beginLife(mode,1),mode..": persisted identity cannot use legacy write/retirement paths")
  check(s:requestLife("continue",mode,1,offer.id),mode..": exact displayed choice is accepted")
  check(decisions[#decisions].state=="readonly" and decisions[#decisions].credential==nil,mode..": choice alone grants no write credential")
  check(not s:setRestForIntent(mode,realRest(240,mode),offer.record.save_life,1,nil),mode..": nil acknowledgement never authorizes")
  check(canon(e.backend.data[s.rkey[mode]])==before,mode..": pre-validation messages do not write")
  run(e,s,2);local r=s.intents.requests[mode]
  check(r.state=="writable" and type(r.credential)=="string" and r.credential~=r.life,mode..": validation issues a separate credential")
  check(not s:setRestForIntent(mode,realRest(240,mode),r.life,1,"stale"),mode..": wrong credential refused")
  check(s:setRestForIntent(mode,realRest(240,mode),r.life,1,r.credential),mode..": exact credential queues a valid rest")
  run(e,s,15)
  check(e.backend.data[s.rkey[mode]].checksum==r.expected.checksum and canon(e.backend.data[s.rkey[mode]])~=before,mode..": stored revision follows the acknowledged world")
 end
end)

case("read-only Continue promotes only an unchanged foreign rest after recovery",function()
 for i,changed in {false,true} do
  local e,s,owner=authorityFixture(1410+i,"main",true,false);local offer=s:offer("main")
  assert(s:requestLife("continue","main",1,offer.id));local r=s.intents.requests.main
  check(r.state=="readonly" and not s:setRestForIntent("main",realRest(240,"main"),offer.record.save_life,1,"guess"),"leased play has no permission")
  if changed then owner:beginLife("main",2);run(e,owner,15);owner:setRestForLife("main",realRest(240,"main"),owner.lifeTokens.main);run(e,owner,15) end
  owner:flush(e.t+20);local before=canon(e.backend.data[s.rkey.main]);run(e,s,70)
  if changed then
   check(r.state=="changed" and r.credential==nil and not s.canRetry,"changed recovery needs a fresh explicit choice")
   check(canon(e.backend.data[s.rkey.main])==before,"foreign rest and backup never rebased or overwritten")
   check(e.backend.data[s.pkey].lock==nil,"refused recovery releases only its acquired lease")
  else check(r.state=="writable" and r.life==offer.record.save_life,"unchanged recovery is acknowledged") end
 end
end)

case("New Life is writable only after durable retirement and recovers without a second retirement",function()
 local e,s=authorityFixture(1420,"main",false,false);local offer=s:offer("main");local original=e.backend.data[s.rkey.main]
 assert(s:requestLife("new","main",1,offer.id));local r=s.intents.requests.main
 run(e,s,1)
 check(r.state=="readonly" and r.credential==nil and r.retireReady,"validated intent still waits for its durable marker")
 run(e,s,1);local marker=e.backend.data[s.rkey.main]
 check(r.state=="writable" and marker.payload.save_retired and marker.backup.checksum==original.checksum,"marker and previous rest precede acknowledgement")
 local credential=r.credential;local writes=e.backend.writes;s:requestLife("new","main",1,offer.id)
 check(r.credential==credential and e.backend.writes==writes,"duplicate intent neither mints permission nor rewrites backup")
 assert(s:setRestForIntent("main",realRest(240,"main"),r.life,1,credential));run(e,s,15)
 local before=canon(e.backend.data[s.rkey.main]);s:demote("other_session",true)
 check(not s:setRestForIntent("main",realRest(240,"main"),r.life,1,credential),"ownership loss revokes the old credential immediately")
 s:load();run(e,s,70)
 check(r.state=="writable" and r.credential~=credential,"established New Life receives a fresh continuation credential")
 check(canon(e.backend.data[s.rkey.main])==before and not e.backend.data[s.rkey.main].payload.save_retired,"recovery never retires the already played life again")
end)

case("empty-only New cannot retire an unseen record, but a missing slot and observed marker work",function()
 local e,s=authorityFixture(1421,"main",false,false);local before=canon(e.backend.data[s.rkey.main])
 assert(s:requestLife("new","main",1,nil));run(e,s,2)
 check(s.intents.requests.main.state=="changed" and canon(e.backend.data[s.rkey.main])==before,"no offer means physically missing only")
 e=newEnv();s=newSession(e,1422,"empty");s:load();s:enableOffers();run(e,s,3)
 assert(s:requestLife("new","main",1,nil));run(e,s,2)
 check(s.intents.requests.main.state=="writable" and e.backend.data[s.rkey.main].payload.save_retired,"genuinely missing slot can acknowledge New")
 local markerOffer=s:offer("main");assert(markerOffer and markerOffer.record.save_retired)
 check(s:requestLife("continue","main",2,markerOffer.id) and s.intents.requests.main.state=="changed","retirement marker is not a playable Continue")
 assert(s:requestLife("new","main",3,markerOffer.id));run(e,s,70)
 check(s.intents.requests.main.state=="writable" and s.lifeRequests.main.serial==3,"explicit New can bind an observed nonplayable marker")
end)

case("delayed validation cannot grant an intent superseded during its read",function()
 local e,s,_,decisions=authorityFixture(1430,"main",false,false);local offer=s:offer("main")
 assert(s:requestLife("continue","main",1,offer.id));local read=e.backend.read;local injected=false
 e.backend.read=function(self,key)
  if key==s.rkey.main and not injected then injected=true;assert(s:requestLife("new","main",2,offer.id)) end
  return read(self,key)
 end
 run(e,s,1);e.backend.read=read
 local stale=false;for _,d in decisions do if d.serial==1 and d.state=="writable" then stale=true end end
 check(injected and not stale,"old read completion emits no stale writable decision")
 run(e,s,70)
 check(s.intents.requests.main.serial==2 and s.intents.requests.main.state=="writable","only newer New intent can finish")
end)

case("atomic callback retries recheck the current selected intent",function()
 local e,s=authorityFixture(1431,"main",false,false);local r=grantContinue(e,s,"main",1)
 assert(s:setRestForIntent("main",realRest(240,"main"),r.life,1,r.credential))
 local before=canon(e.backend.data[s.rkey.main]);local update=e.backend.update;local injected=false
 e.backend.update=function(self,key,transform)
  if key==s.rkey.main and not injected then
   injected=true;assert(transform(Json.copy(self.data[key]))~=nil)
   assert(s:requestLife("new","main",2,s:offer("main").id))
  end
  return update(self,key,transform)
 end
 run(e,s,1);e.backend.update=update
 check(injected and canon(e.backend.data[s.rkey.main])==before,"discarded speculative callback cannot commit old rest after a newer choice")
 check(s.intents.requests.main.serial==2 and s.intents.requests.main.state=="readonly","old callback cannot acknowledge newer intent")
end)

case("commit before revocation preserves the authored revision without resurrecting permission",function()
 local e,s=authorityFixture(1432,"main",false,false);local r=grantContinue(e,s,"main",1);local credential=r.credential
 assert(s:setRestForIntent("main",realRest(240,"main"),r.life,1,credential))
 local update=e.backend.update;local revoked=false
 e.backend.update=function(self,key,transform)
  local ok,value,err=update(self,key,transform)
  if key==s.rkey.main and not revoked then revoked=true;s:demote("other_session",true) end
  return ok,value,err
 end
 run(e,s,1);e.backend.update=update
 check(revoked and r.state=="readonly" and r.credential==nil,"late successful response never restores permission after loss")
 local before=canon(e.backend.data[s.rkey.main]);s:load();run(e,s,70)
 check(r.state=="writable" and r.credential~=credential and canon(e.backend.data[s.rkey.main])==before,"fresh revalidation can recover our confirmed authored checkpoint")
end)

case("lost write response can advance to a newer queued checkpoint without rebasing foreign data",function()
 local e,s=authorityFixture(1433,"main",false,false);local r=grantContinue(e,s,"main",1)
 assert(s:setRestForIntent("main",realRest(240,"main"),r.life,1,r.credential))
 e.backend:fail({op="update",key=s.rkey.main,times=1,afterWrite=true,message="lost response"})
 run(e,s,1);local newer=realRest(360,"main")
 assert(s:setRestForIntent("main",newer,r.life,1,r.credential));run(e,s,5)
 local expected=Json.copy(newer);expected.save_life=r.life
 check(r.state=="writable" and canon(e.backend.data[s.rkey.main].payload)==canon(expected),"only our known authored ambiguous revision permits advancing a newer queued rest")
 check(r.expected.checksum==e.backend.data[s.rkey.main].checksum and r.ambiguous==nil,"successful retry settles exact revision")
end)

case("missing and equal-time foreign records cannot pass an acknowledged write callback",function()
 for i,missing in {false,true} do
  local e,s=authorityFixture(1440+i,"main",false,false);local r=grantContinue(e,s,"main",1)
  assert(s:setRestForIntent("main",realRest(240,"main"),r.life,1,r.credential))
  local old=e.backend.data[s.rkey.main];local replacement=nil
  if not missing then
   local payload=realRest(360,"main");payload.save_life=r.life
   replacement=SaveEnvelope.make(SaveRest.SPECS.main,payload,old.updatedAt,old,{session="foreign"})
  end
  e.backend:poke(s.rkey.main,replacement);local before=canon(replacement);run(e,s,1)
  check(r.state=="changed" and r.credential==nil,"changed revision revokes current authority")
  check(canon(e.backend.data[s.rkey.main])==before,"callback cannot recreate a deleted rest or replace an equal-time foreign revision")
 end
end)

case("protected backups and legacy nil identity never bypass the new credential gate",function()
 local e,s=authorityFixture(1450,"main",false,false);local old=e.backend.data[s.rkey.main]
 local raw=SaveEnvelope.make(SaveRest.SPECS.main,realRest(240,"main"),e.t,old,{session="foreign"});raw.checksum="damaged"
 e.backend:poke(s.rkey.main,raw);s.previewPending.main=true;s:step()
 local offer=s:offer("main");assert(offer and offer.protected);local before=canon(raw)
 assert(s:requestLife("continue","main",1,offer.id));run(e,s,15)
 check(s.intents.requests.main.state=="readonly" and canon(e.backend.data[s.rkey.main])==before,"readable backup stays temporary and preserves damaged primary")
 e,s=authorityFixture(1451,"main",false,true);local r=grantContinue(e,s,"main",1)
 check(r.life==nil and not s:setRestForIntent("main",realRest(240,"main"),nil,1,nil),"legacy nil life identity alone remains powerless")
 check(s:setRestForIntent("main",realRest(240,"main"),nil,1,r.credential),"legacy life can continue with an independent acknowledgement")
end)

case("validation is budgeted, backs off and respects Easy unlock",function()
 local e,s=authorityFixture(1452,"main",false,false);local offer=s:offer("main")
 check(not s:requestLife("new","easy",1,nil),"locked Easy cannot request a new authority")
 assert(s:requestLife("continue","main",1,offer.id));local r=s.intents.requests.main
 s.sched.started=table.create(SaveRules.REQUESTS_PER_MINUTE,e.t);local requests=e.backend.requests;s:step()
 check(e.backend.requests==requests and r.state=="readonly","budget exhaustion cannot grant or start a validation read")
 s.sched.started={};e.backend:fail({op="read",key=s.rkey.main,times=1,message="offline"});s:step()
 requests=e.backend.requests;s:step()
 check(e.backend.requests==requests and r.needsCheck and r.credential==nil,"failed validation backs off without permission")
 run(e,s,3);check(r.state=="writable","later successful read can acknowledge the same explicit observation")
end)

case("departure validates New before durable acknowledgement",function()
 local e,s=authorityFixture(1453,"main",false,false);local offer=s:offer("main")
 assert(s:requestLife("new","main",1,offer.id));s:flush(e.t+20)
 check(s.closed and e.backend.data[s.rkey.main].payload.save_retired and s.lifeRequests.main.done,"departure stores only a validated explicit retirement")
end)
