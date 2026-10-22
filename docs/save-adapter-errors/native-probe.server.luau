-- Local diagnostic only. Never publish this helper or its synthetic fixture.
if not game:GetService("RunService"):IsStudio() or game.PlaceId~=0 or workspace:GetAttribute("RetirementProbe")~=true then return end
print("[CHET_ADAPTER_NATIVE_READY]","e50104232f063255");task.wait(2)
local ok,err=pcall(function()
 local Shared=game.ReplicatedStorage.Shared
 require(Shared.World.WorldMap).use("preserve")
 local C=require(game.ServerScriptService.Server.RestCompression)
 local B=require(game.ServerScriptService.Server.DataStoreBackend)
 local S=require(Shared.Persistence.SaveSession)
 local E=require(Shared.Persistence.SaveEnvelope)
 local R=require(Shared.Persistence.SaveRest)
 local J=require(Shared.Persistence.Json)
 local http=game:GetService("HttpService");local codec=C.engine()
 local fixture=http:JSONDecode(game.ServerStorage.ChetRetirementFixture.Value)
 local original=codec:decode(fixture)
 local opened=E.open(R.SPECS.main,original)
 assert(opened.status=="migrated" or opened.status=="ok","old native checkpoint invalid")
 local record=opened.payload
 task.wait()
 local function copy(v) return if v~=nil then http:JSONDecode(http:JSONEncode(v)) else nil end
 local ds={data={R_native_retirement_main=fixture}}
 function ds:GetAsync(key) return copy(self.data[key]) end
 function ds:UpdateAsync(key,fn)
  local nextValue=fn(copy(self.data[key]))
  if nextValue~=nil then self.data[key]=copy(nextValue) end
  return copy(self.data[key])
 end
 local backend=B.new(ds,codec);local now=10000;local ack={}
 local function visit(id)
  return S.new({backend=backend,userId="native_retirement",sessionId=id,now=function() return now end,
   sleep=function(dt) now+=dt;task.wait() end,onLife=function(mode,serial,token) table.insert(ack,{mode,serial,token}) end})
 end
 local a=visit("native_A");assert(a:load()=="active");task.wait()
 assert(a:beginLife("main",1) and #ack==0 and a:snapshot().rests.main==nil)
 assert(not a:setRest("main",record),"old life queued after New Life")
 a:step();task.wait()
 assert(#ack==1 and a.lifeRequests.main.done,"durable retirement not acknowledged")
 local retired=codec:decode(ds.data.R_native_retirement_main)
 assert(retired.payload.save_retired and retired.backup,"retirement did not retain checkpoint backup")
 local previous={format=retired.format,kind=retired.kind}
 for k,v in retired.backup do previous[k]=v end
 local prior=E.open(R.SPECS.main,previous)
 assert(prior.status=="ok" or prior.status=="migrated","native backup invalid")
 assert(J.canonical(prior.payload)==J.canonical(record),"retirement changed old checkpoint")
 task.wait();a:flush();task.wait();now+=40
 local b=visit("native_B");assert(b:load()=="active" and b:snapshot().rests.main==nil,"rejoin revived retired life")
 local token=b.lifeTokens.main;assert(token==ack[1][3])
 assert(not b:setRestForLife("main",record,"wrong"),"foreign life accepted")
 task.wait();assert(b:setRestForLife("main",record,token));task.wait()
 b:step();task.wait();b:flush();task.wait()
 local final=codec:decode(ds.data.R_native_retirement_main)
 local current=E.open(R.SPECS.main,final)
 assert(current.status=="ok" and current.payload.save_life==token)
 local restored=copy(current.payload);restored.save_life=nil
 assert(J.canonical(restored)==J.canonical(record),"new life metadata changed simulation fields")
 print("[CHET_ADAPTER_NATIVE_PASS]",#assert(J.canonical(record)),#http:JSONEncode(ds.data.R_native_retirement_main),"native codec; local memory backend; retirement backup; quit/rejoin; stale rest refused; exact checkpoint")
end)
if not ok then warn("[CHET_ADAPTER_NATIVE_FAIL]",tostring(err)) end
