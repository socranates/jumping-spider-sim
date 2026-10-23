-- Executed with the exact production DataStoreBackend and an injected store.
local passed,groups=0,0
local function check(v,why) passed+=1;assert(v,why or "backend admission assertion") end
local function group(name,fn) local before=passed;fn();groups+=1;print("ADMISSION_BACKEND_CASE",name,passed-before) end
local function copy(v) if type(v)~="table" then return v end;local out={};for k,x in v do out[k]=copy(x) end;return out end
local function fixture()
 local f={time=0,read=100,write=100,calls=0,callbacks=0,values={R_a_main={original=7,backup={original=3},unknown="retain"}},options=0,afterCallback=nil,beforeRead=nil,afterWrite=nil,fail=nil}
 local gate=Admission.new({now=function() return f.time end,available=function() return {read=f.read,write=f.write} end,actorRead=30,actorWrite=10,serverRead=60,serverWrite=30,headroom=1})
 local scope=assert(gate:open("a","one"));local ds={}
 function ds:GetAsync(key,options)
  check(options and options.UseCache==false,"verification read used a cached path")
  f.calls+=1;f.read-=1;f.options+=1
  if f.beforeRead then f.beforeRead() end
  if f.fail then error(f.fail) end
  return copy(f.values[key])
 end
 function ds:UpdateAsync(key,transform)
  f.calls+=1;f.read-=1;f.write-=1
  if f.fail then error(f.fail) end
  local candidate
  for i=1,2 do f.callbacks+=1;candidate=transform(copy(f.values[key]));if i==1 and f.afterCallback then f.afterCallback() end end
  if candidate~=nil then f.values[key]=copy(candidate) end
  if f.afterWrite then f.afterWrite() end
  return copy(f.values[key])
 end
 local backend=Backend.new(ds);local facade=Facade.new(gate,scope,backend)
 return gate,scope,facade,f,backend
end
group("zero-budget-is-pending-not-provider-failure",function()
 local g,s,io,f=fixture();f.read=0
 local h=assert(io:begin("readRawFresh","R_a_main"))
 for _=1,40 do check(io:step(h)=="waiting") end
 check(f.calls==0 and g:inspect().history==0 and io:inspect().started==0)
 f.read=2;local state,values=io:step(h);check(state=="done" and values[1]==true and values[2].original==7)
 check(f.calls==1 and g:inspect().read==1 and g:inspect().write==0 and io:inspect().jobs==0)
end)
group("fresh-read-and-typed-update-boundaries",function()
 local g,s,io,f,backend=fixture()
 check(io:begin("read","R_a_main")==nil);check(io:begin("update","R_a_main")==nil)
 -- Method identity is captured at facade construction.
 backend.readRawFresh=function() error("method was rebound") end
 for _,method in {"readRawFresh","readFresh"} do
  local state,v=io:step(assert(io:begin(method,"R_a_main")));check(state=="done" and v[1] and v[2].backup.original==3)
 end
 local state,v=io:step(assert(io:begin("update","R_a_main",function(old) old.original=8;return old end)))
 check(state=="done" and v[1] and v[2].original==8 and v[2].backup.original==3 and v[2].unknown=="retain")
 check(f.calls==3 and f.callbacks==2 and g:inspect().read==3 and g:inspect().write==1)
end)
group("cancelled-queued-operation-never-starts",function()
 local g,s,io,f=fixture();f.read=0
 local h=assert(io:begin("update","R_a_main",function() error("cancelled transform ran") end))
 check(io:step(h)=="waiting");check(io:cancel(h));f.read=100
 check(io:step(h)=="ended" and f.calls==0 and g:inspect().history==0)
 check(f.values.R_a_main.original==7 and f.values.R_a_main.unknown=="retain")
end)
group("yielding-read-cannot-return-an-obsolete-result",function()
 local g,s,io,f=fixture();f.beforeRead=function() coroutine.yield("read pending") end
 local h=assert(io:begin("readRawFresh","R_a_main"));local result
 local co=coroutine.create(function() result=table.pack(io:step(h)) end)
 local ok,where=coroutine.resume(co);check(ok and where=="read pending")
 check(io:step(h)=="waiting" and f.calls==1);check(io:cancel(h));check(coroutine.resume(co))
 check(result[1]=="cancelled" and result[2]==nil and io:inspect().jobs==0 and g:inspect().history==1)
end)
group("repeated-update-callback-rechecks-cancellation",function()
 local g,s,io,f=fixture();local h
 h=assert(io:begin("update","R_a_main",function(old) old.original=99;return old end))
 f.afterCallback=function() check(io:cancel(h)) end
 check(io:step(h)=="cancelled");check(f.callbacks==2 and f.calls==1)
 check(f.values.R_a_main.original==7 and f.values.R_a_main.backup.original==3 and f.values.R_a_main.unknown=="retain")
 check(g:inspect().read==1 and g:inspect().write==1 and io:inspect().jobs==0)
end)
group("scope-end-inside-transform-cancels-candidate",function()
 local g,s,io,f=fixture()
 local h=assert(io:begin("update","R_a_main",function(old) g:close(s);old.original=99;return old end))
 check(io:step(h)=="cancelled");check(f.values.R_a_main.original==7 and f.calls==1)
 local nextScope=assert(g:open("a","two"));check(g:live(nextScope) and not g:live(s));check(g:inspect().read==1 and g:inspect().write==1)
end)
group("ambiguous-ack-does-not-refund-or-report-success",function()
 local g,s,io,f=fixture();f.afterWrite=function() coroutine.yield("ack pending") end
 local h=assert(io:begin("update","R_a_main",function(old) old.original=9;return old end));local result
 local co=coroutine.create(function() result=table.pack(io:step(h)) end)
 local ok,where=coroutine.resume(co);check(ok and where=="ack pending" and f.values.R_a_main.original==9)
 check(g:close(s));check(g:open("a","two")==nil);check(coroutine.resume(co))
 check(result[1]=="cancelled" and result[2]==nil)
 check(g:inspect().read==1 and g:inspect().write==1 and f.calls==1)
 check(g:open("a","two")~=nil)
end)
group("actual-backend-errors-retain-provider-result",function()
 local g,s,io,f=fixture();f.fail="synthetic native adapter failure"
 local state,v=io:step(assert(io:begin("readFresh","R_a_main")))
 check(state=="done" and v[1]==false and v[2]==nil and string.find(v[3],f.fail,1,true))
 check(g:inspect().history==1 and f.calls==1 and io:inspect().jobs==0)
end)
check(optionEvents.created==optionEvents.destroyed and optionEvents.created>0,"production backend leaked read options")
print("ADMISSION_BACKEND passed="..passed.." failed=0 groups="..groups.." options="..optionEvents.created)
