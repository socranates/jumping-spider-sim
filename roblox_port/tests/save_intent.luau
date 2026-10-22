local Intent=require("../src/Shared/Persistence/SaveIntent")
local Rules=require("../src/Shared/Data/SaveRules")
local passed,failed=0,0
local function check(ok,why) if ok then passed+=1 else failed+=1;print("FAIL INTENT "..why) end end
for _,mode in Rules.MODES do
 local messages={};local a=Intent.new("owner",function(m) table.insert(messages,m) end)
 local r,created=a:choose(mode,"continue",1,"observed")
 check(r and created and #messages==0,"choosing alone emits no premature restoration decision")
 a:notify(r);check(messages[1].state=="readonly" and messages[1].credential==nil,"initial view grants no credential")
 check(not a:authorized(mode,1,nil,nil),"nil legacy identity never authorizes a nil credential")
 check(a:grant(r,nil),"validated legacy identity can receive a separate credential")
 local credential=r.credential;local revision=r.revision
 check(a:authorized(mode,1,credential,nil),"current independent credential authorizes its exact intent")
 messages[#messages].credential="tampered"
 check(a:authorized(mode,1,credential,nil),"callback table cannot mutate private credential")
 local same,new=a:choose(mode,"continue",1,"observed")
 check(same==r and not new and r.credential==credential,"duplicate does not mint another credential")
 check(a:choose(mode,"new",1,"observed")==nil,"same serial cannot change intent kind")
 a:readonly(r,"ownership_lost")
 check(not a:authorized(mode,1,credential,nil) and r.revision>revision,"revocation invalidates older credential and advances ordering")
 check(a:grant(r,nil) and r.credential~=credential,"recovery issues a new credential")
 check(not a:authorized(mode,1,credential,nil),"old acknowledgement stays invalid after recovery")
 local nextIntent=a:choose(mode,"new",2,nil)
 check(nextIntent~=nil and not a:grant(r,nil),"superseded request cannot grant after a delayed read")
 check(not a:authorized(mode,1,r.credential,nil),"supersession invalidates the old current-state authorization")
 a:changed(nextIntent,"rest_changed")
 check(not a:grant(nextIntent,"life"),"changed observation cannot be promoted by a delayed result")
 check(a:choose(mode,"continue",1,"observed")==nil,"older choice cannot roll back supersession")
end
do
 local a=Intent.new("owner");local main=a:choose("main","new",1,nil);local free=a:choose("free","new",1,nil)
 a:grant(main,"life");a:grant(free,"life")
 check(not a:authorized("free",1,main.credential,"life"),"credential cannot cross slots")
 check(not a:authorized("main",1,main.credential,"other"),"life identity remains independently checked")
 for _,serial in {0,-1,1.1,math.huge,0/0,Rules.MAX_LIFE_SERIAL+1,"2",{}} do check(a:choose("main","new",serial,nil)==nil,"invalid serial rejected") end
 check(a:choose("unknown","new",2,nil)==nil and a:choose("main","continue",2,nil)==nil,"unknown slot and unbound Continue refused")
 check(a:choose("main","new",2,string.rep("x",Rules.MAX_LIFE_TOKEN_CHARS+1))==nil,"oversized offer refused")
end
print(`SAVE_INTENT passed={passed} failed={failed}`)
if failed>0 then error("save intent checks failed") end
