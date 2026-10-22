-- Isolated native codec/session diagnostic; never publish. No real DataStore calls.
if not game:GetService("RunService"):IsStudio() or game.PlaceId~=0 or workspace:GetAttribute("SlotIsolationProbe")~=true then return end
print("[CHET_SLOT_NATIVE_READY]","1984fdd8e8dee0ad")
task.wait(2)
local ok,err=pcall(function()
 local Shared=game.ReplicatedStorage.Shared
 require(Shared.World.WorldMap).use("preserve")
 local C=require(game.ServerScriptService.Server.RestCompression)
 local B=require(game.ServerScriptService.Server.DataStoreBackend)
 local S=require(Shared.Persistence.SaveSession)
 local E=require(Shared.Persistence.SaveEnvelope)
 local R=require(Shared.Persistence.SaveRest)
 local P=require(Shared.Persistence.SaveProgress)
 local J=require(Shared.Persistence.Json)
 local http=game:GetService("HttpService");local codec=C.engine()
 local fixture=http:JSONDecode(game.ServerStorage.ChetSlotFixture.Value)
 local original=codec:decode(fixture)
 local op=E.open(R.SPECS.main,original);assert(op.status=="migrated" or op.status=="ok")
 local record=op.payload;local recordText=assert(J.canonical(record));task.wait()
 local function copy(value) return if value~=nil then http:JSONDecode(http:JSONEncode(value)) else nil end
 local cases,checks=0,0
 local function check(value,why) assert(value,why);checks+=1 end
 for _,mode in {"main","easy","free"} do
  for _,damage in {"corrupt","invalid","newer"} do
   local id="slot_native_"..mode.."_"..damage;local key="R_"..id.."_"..mode
   local env
   if mode=="main" then
    local previous=E.make(R.SPECS.main,record,10,nil,{session="OLD"})
    env=E.make(R.SPECS.main,record,11,previous,{session="OLD"})
   else env=E.make(R.SPECS[mode],{invalid=true},11,nil,{session="OLD"}) end
   if damage=="corrupt" then env.checksum="deliberately-damaged"
   elseif damage=="newer" then env.schema=99
   else env=E.make(R.SPECS[mode],{invalid=true},11,if mode=="main" then env else nil,{session="OLD"}) end
   local ds={data={}};ds.data[key]=codec:encode(env);local before=assert(J.canonical(ds.data[key]));task.wait()
   function ds:GetAsync(k) return copy(self.data[k]) end
   function ds:UpdateAsync(k,fn) local v=fn(copy(self.data[k]));if v~=nil then self.data[k]=copy(v) end;return copy(self.data[k]) end
   local now,acks=10000,0;local backend=B.new(ds,codec)
   local function visit(session)
    return S.new({backend=backend,userId=id,sessionId=session,now=function() return now end,sleep=function(dt) now+=dt;task.wait() end,onLife=function() acks+=1 end})
   end
   local a=visit("A");check(a:load()=="active" and a.lockHeld,"unreadable rest stopped notebook ownership");task.wait()
   check(a.restProtected[mode]==(if damage=="newer" then "newer" else "corrupt"),"slot was not protected")
   check(not a:beginLife(mode,1) and not a:setRest(mode,record),"protected slot accepted replacement")
   if mode=="main" and damage~="newer" then check(assert(J.canonical(a.rests.main))==recordText,"valid full-world backup changed") end
   task.wait()
   local progress=P.default();progress.notebook.opened={"p1"};check(a:setProgress(progress),"notebook update refused")
   local healthy=if mode=="main" then "free" else "main"
   if healthy=="main" then check(a:setRest("main",record),"healthy full-world rest refused") else check(a:beginLife("free",1),"healthy retirement refused") end
   task.wait();a:flush();task.wait()
   check(J.canonical(ds.data[key])==before,"damaged compressed bytes changed on flush")
   check(E.open(P.SPEC,codec:decode(ds.data["P_"..id])).payload.notebook.opened[1]=="p1","independent notebook did not persist")
   if healthy=="free" then check(acks==1,"healthy-slot retirement not acknowledged exactly once") else check(acks==0,"protected intent incorrectly acknowledged") end
   now+=40;local rejoin=visit("B");check(rejoin:load()=="active" and rejoin.restProtected[mode]~=nil,"session rejoin lost protection")
   check(rejoin.progress.notebook.opened[1]=="p1","session rejoin lost notebook")
   if healthy=="main" then check(assert(J.canonical(rejoin.rests.main))==recordText,"healthy full-world rest changed") else check(rejoin.lifeTokens.free~=nil and rejoin.rests.free==nil,"healthy retirement lost on rejoin") end
   task.wait();rejoin:flush();task.wait()
   check(J.canonical(ds.data[key])==before,"session rejoin replaced damaged bytes")
   cases+=1;print("[CHET_SLOT_NATIVE_CASE]",mode,damage,"pass",checks)
  end
 end
 print("[CHET_SLOT_NATIVE_PASS]",cases,checks,#recordText,"native engine codec; local synthetic backend; no real datastore; session-level rejoin")
end)
if not ok then warn("[CHET_SLOT_NATIVE_FAIL]",tostring(err)) end
