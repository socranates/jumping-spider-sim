drive(function() return client.newLifeEnabled and not client:offerPending() and d.session.started and client:offerInfo("easy")~=nil end)
d.session.started=false;d.openMenu(true);holdAck=false
local function has(id) for _,choice in d.menu.choices do if choice.id==id then return true end end;return false end
local function originals()
 local rows={};for key,value in b.data do if string.sub(key,1,3)=="A1_" or string.sub(key,1,3)=="M1_" then rows[key]=value end end
 return Json.canonical(rows)
end
local function begin(mode)
 drive(function() return not client:offerPending(mode) and client:offerInfo(mode)~=nil end)
 d.openMenu(true);local choice=if mode=="main" then "New" elseif mode=="free" then "NewFree" else "Easy"
 check(d.menu:choose(choice),"fault fixture lacked actual New choice")
 if app.phase~="new" then check(d.menu:choose(choice),"fault fixture lacked actual confirmation") end
 check(app.phase=="new" and app:held(),"fault fixture did not hold actual New")
end
local function exit()
 local old=owners[#owners];local epoch=client.bound.epoch
 check(d.menu:choose("RecoveryExit"),"New fault screen lost actual exit")
 drive(function() return app.phase=="menu" and client.transition==nil end)
 check(old:replacementClosed() and client.bound.epoch~=epoch and app:held() and not d.session.started,"New fault exit overlapped owners or silently reset world")
end
-- Exit before the first new-life request has even reached the server.
begin("main");exit()
for _,mode in Rules.MODES do check(Json.canonical(b.data["R_46001_"..mode])==oldBytes[mode] and b.data["A1_46001_"..mode]==nil,"early actual New exit changed original") end
-- Lose requests and the first verified reply. Retries must not start a second
-- retirement transaction or release the paused world without verified closure.
local priorSend=toServer.FireServer;local droppedRequests,droppedVerified=0,0
rawset(toServer,"FireServer",function(self,msg)
 if msg.kind=="new_life_request" and droppedRequests<2 then droppedRequests+=1;return end
 return priorSend(self,msg)
end)
local priorReply=server.send
server.send=function(who,msg)
 if msg.kind=="new_life_state" and msg.state=="verified" and droppedVerified<1 then droppedVerified+=1;return end
 return priorReply(who,msg)
end
begin("main");local old=owners[#owners];local epoch=client.bound.epoch
drive(function() return app.phase=="menu" and client.transition==nil and client.bound.epoch~=epoch end)
check(droppedRequests==2 and droppedVerified==1 and old:replacementClosed() and old.newLifeJob.state=="verified","lost New packets did not recover through one owner")
local writes=0;for _,row in b.log do if row.op=="update" and row.key=="R_46001_main" and row.ok and not row.cancelled then writes+=1 end end
check(writes==1 and app:held() and not d.session.started,"retry duplicated retirement or started a life implicitly")
-- A competing raw rest change must be refused, surfaced by the real screen,
-- retained byte-for-byte, and followed by acknowledged owner closure.
begin("free")
drive(function() local job=owners[#owners].newLifeJob;return job and job.phase=="write" end)
local foreign=Json.copy(b.data.R_46001_free);foreign.session="synthetic-concurrent";b:poke("R_46001_free",foreign)
local kept=originals();drive(function() return app.phase=="failed" end)
check(app:held() and d.menu:isShowing() and has("RecoveryExit") and Json.canonical(b.data.R_46001_free)==Json.canonical(foreign)
 and originals()==kept and client:decision("free").credential==nil,"concurrent New conflict lost original, granted, or hid its safe exit")
exit();check(originals()==kept and Json.canonical(b.data.R_46001_free)==Json.canonical(foreign),"conflict exit overwrote foreign rest or immutable archive")
-- A persisted schema3 retirement is New-only. Recover and retire Easy through
-- the real owning route, replace the session, then use the actual New UI.
drive(function() return not client:offerPending("easy") and client:offerInfo("easy")~=nil end)
d.openMenu(true);check(d.menu:choose("ContinueEasy"),"retired-source fixture lacked actual Continue")
drive(function() return app.phase=="playing" end)
local owner=owners[#owners];local r=owner.session.intents.requests.easy
check(owner.runtime:retireRecovered("easy",r.serial,r.credential,r.life,1,r.serial+1),"actual recovered Easy retirement refused")
drive(function() return owner.runtime.phase=="retired" end)
d.openMenu(true);check(d.menu:choose("Easy") and app.phase=="replacing","retired playing world skipped owner replacement")
drive(function() return app.phase=="menu" and client.transition==nil end)
drive(function() return not client:offerPending("easy") and client:offerInfo("easy")~=nil end)
d.openMenu(true);check(not client:offerInfo("easy").playable and client:offerInfo("easy").protected and not has("ContinueEasy") and has("Easy"),"persisted retirement was offered as Continue")
kept=originals();begin("easy");epoch=client.bound.epoch
drive(function() return app.phase=="menu" and client.transition==nil and client.bound.epoch~=epoch end)
check(originals()==kept and app:held(),"retired New UI changed original/proposal or released world early")
drive(function() return not client:offerPending("easy") and client:offerInfo("easy")~=nil end)
d.openMenu(true);check(d.menu:choose("Easy"),"fresh Easy choice missing after interrupted retirement")
if app:choosing() then check(d.menu:choose("Easy"),"fresh Easy confirmation missing") end
drive(function() local q=client:decision("easy");return q and q.state=="writable" end)
check(app.phase=="playing" and not app:held() and client:decision("easy").credential~=nil and originals()==kept,"retired New UI did not obtain a real new life")
check(#errors==0,"hidden failure-fixture service error: "..tostring(errors[1]))
server:removePlayer(player);check(b.data.P_46001.lock==nil,"failure fixture retained final lease")
catalog:close()
print("NEW_APPLICATION_FAILURE passed="..count.." failed=0")
end
runNewApplicationFailureChecks()
end
