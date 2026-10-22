-- Cooperative preparation plumbing; no game/menu worker is enabled by this test.
local Work=require("../src/Shared/Persistence/SaveWork")
local Json=require("../src/Shared/Persistence/Json")
local passed,failed=0,0
local function check(ok,why) if ok then passed+=1 else failed+=1;print("FAIL SAVE_WORK "..why) end end
local function options(extra)
 local clock=0
 local cfg={now=function() clock+=.001;return clock end,budget=.004,maxSeconds=1000,maxResumes=10000}
 for k,v in extra or {} do cfg[k]=v end
 return cfg
end
local function finish(job)
 for _=1,10000 do if job.state~="pending" then break end;job:step() end
 check(job.state=="done","bounded cooperative operation finishes")
 return assert(job:take())
end
check(Work.pulse()==nil,"ordinary code has no worker context")
local record={name="a quoted \"name\"",items={}}
for i=1,3000 do record.items[i]={id=i,tag="entry_"..i,value=i/17} end
local expected=assert(Json.canonical(record));local checksum=Json.checksum(expected)
local job=Work.new(function()
 check(Work.pulse()~=nil,"worker owns its pulse context")
 local copy=Json.copy(record)
 local text=assert(Json.canonical(copy))
 return text,Json.checksum(text),nil,copy
end,options())
job:step()
check(job.state=="pending" and job:take()==nil,"partial work publishes no result")
local result=finish(job)
check(result.n==4 and result[1]==expected and result[2]==checksum and result[3]==nil,"yielded JSON/hash bytes and nil return positions match synchronous output")
check(result[4]~=record and result[4].items[1]~=record.items[1],"yielded copy retains private table boundaries")
check(job.resumes>10,"large operations are actually split over multiple resumes")
check(job:take()==nil and job.state=="consumed","results transfer only once")
check(Work.pulse()==nil,"completed context does not leak to caller")
local text=""
for i=1,20000 do text..=string.char(i%256) end
local expectedHash=Json.checksum(text)
local hashJob=Work.new(function() return Json.checksum(text) end,options())
local hash=finish(hashJob)
check(hash[1]==expectedHash and hashJob.resumes>1,"checksum yields between byte blocks without changing either lane")
local cancelled=Work.new(function() return Json.copy(record) end,options())
cancelled:step();check(cancelled.state=="pending","cancellable work really paused")
check(cancelled:cancel() and cancelled.state=="cancelled","cancellation is terminal")
check(not cancelled:step() and cancelled:take()==nil and cancelled.thread==nil,"cancelled work cannot resume or retain a publishable result")
local done=Work.new(function() return "discard me" end,options())
done:step();check(done.state=="done" and done:cancel() and done:take()==nil,"completed unconsumed result may still be discarded")
local broken=Work.new(function() assert(Work.pulse());error("synthetic preparation error") end,options())
broken:step()
check(broken.state=="failed" and string.find(broken.problem,"synthetic preparation error",1,true) and broken:take()==nil,"errors cannot produce a result")
check(Work.pulse()==nil,"failed work clears context")
local stranger=Work.new(function() coroutine.yield("not a worker checkpoint");return "bad" end,options())
stranger:step()
check(stranger.state=="failed" and stranger.problem=="unexpected preparation yield" and stranger:take()==nil,"arbitrary yields are rejected")
local limited=Work.new(function() return Json.copy(record) end,options({maxResumes=1}))
limited:step();limited:step()
check(limited.state=="failed" and limited:take()==nil,"resume budget cannot silently publish incomplete work")
local clock=0
local late=Work.new(function() clock=100;return "too late" end,{now=function() return clock end,budget=.004,maxSeconds=1})
late:step();check(late.state=="failed" and late:take()==nil,"overrun result is discarded even when native/uncooperative work cannot be preempted")
local selfCancelled
selfCancelled=Work.new(function() selfCancelled:cancel();return "obsolete" end,options())
selfCancelled:step()
check(selfCancelled.state=="cancelled" and selfCancelled:take()==nil,"reentrant cancellation cannot be overwritten by coroutine completion")
for _,cfg in {{budget=0},{budget=0/0},{maxResumes=1.5},{maxSeconds=math.huge}} do
 check(not pcall(Work.new,function() end,options(cfg)),"invalid worker bound refused")
end
local first=Work.new(function() return Json.checksum(expected) end,options())
local second=Work.new(function() return assert(Json.canonical({separate=true})) end,options())
first:step();local small=finish(second);local large=finish(first)
check(small[1]=='{"separate":true}' and large[1]==checksum,"interleaved workers keep independent scopes and values")
local acrossPcall=Work.new(function() return pcall(function() return Json.checksum(expected) end) end,options())
local pc=finish(acrossPcall)
check(pc[1]==true and pc[2]==checksum and acrossPcall.resumes>1,"validation pcall boundaries allow cooperative yields")
local ObjectRecord=require("../src/Shared/Persistence/ObjectRecord")
local mt={};mt.__index=mt
local shared=setmetatable({tag="shared"},mt)
local root={items={},alias=shared};root.self=root
for i=1,1000 do root.items[i]={index=i,shared=shared,parent=root} end
local roots={world=root};local classes={Shared=mt}
local original=assert(ObjectRecord.capture(roots,classes,{}))
local graphJob=Work.new(function() return ObjectRecord.capture(roots,classes,{}) end,options())
local encoded=finish(graphJob)
check(graphJob.resumes>1 and Json.canonical(encoded[1])==Json.canonical(original),"yielded graph capture is byte-identical with cycles and aliases")
local decodeJob=Work.new(function() return ObjectRecord.decode(encoded[1],classes,{}) end,options())
decodeJob:step()
check(decodeJob.state=="pending" and root.alias==shared and root.self==root,"partial decode does not change live graph")
local decoded=finish(decodeJob)[1]
local fresh=decoded.roots.world
check(fresh~=root and fresh.self==fresh and fresh.items[1000].parent==fresh,"yielded decode keeps cycles private")
check(fresh.alias==fresh.items[1].shared and fresh.alias==fresh.items[1000].shared and getmetatable(fresh.alias)==mt,"yielded decode preserves aliases and class identity")
local cancelDecode=Work.new(function() return ObjectRecord.decode(original,classes,{}) end,options())
cancelDecode:step();cancelDecode:cancel()
check(root.alias==shared and root.items[1000].parent==root and cancelDecode:take()==nil,"cancelled graph preparation leaves original world untouched")
local commitJob=Work.new(function() return ObjectRecord.commit(decoded,roots) end,options())
local committed=finish(commitJob)
check(committed[1]==true and commitJob.resumes==1 and root.self==root and root.items[1000].parent==root,"live graph commit stays atomic and preserves live root references")
print(`SAVE_WORK passed={passed} failed={failed}`)
assert(failed==0,"save work checks failed")
