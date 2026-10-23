local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Store=__proposalStorePrototype
local count=0
local function check(ok,why) assert(ok,why);count+=1 end
local function fixture()
 local b=Memory.new();b.readRawFresh=function(self,key) return self:read(key) end
 b:poke("R_46001_main",Json.copy(rest));b:poke("P_46001",Json.copy(rawProgress))
 return b,Store.new(b,codec,fresh)
end
local function begin(r,a,f) return assert(r:begin(a or anchor,f or function() return true end)) end
local function step(r,j)
 local before=r.backend.requests;r:step(j)
 check(r.backend.requests-before<=1,"proposal step made more than one request")
end
local function drive(r,j)
 for _=1,20 do if j.state~="pending" then return end;step(r,j) end
 error("proposal store did not settle")
end
do
 local b,r=fixture();local before=Json.canonical(b.data);local j=begin(r);drive(r,j)
 check(j.state=="ready" and j.requests==3 and b.writes==1,"first publication/readback failed")
 check(table.isfrozen(j.anchor) and table.isfrozen(j.anchor.target) and table.isfrozen(j.payload),"published result not frozen")
 local saved=Json.canonical(b.data[anchor.id]);local writes=b.writes
 local again=begin(r,second);drive(r,again)
 check(again.state=="ready" and again.requests==1 and Json.canonical(again.anchor)==saved and b.writes==writes,"restart re-encoded/replaced first proposal")
 check(again.anchor.target.data==anchor.target.data and again.anchor.target.data~=second.target.data,"restart did not retain opaque bytes")
 b.data[anchor.id]=nil
 check(Json.canonical(b.data)==before,"publication touched original keys")
 for _,op in b.log do check(op.key==anchor.id,"publication requested non-M1 key") end
end
for _,after in {false,true} do
 local b,r=fixture();local j=begin(r);step(r,j)
 b:fail({op="update",key=anchor.id,afterWrite=after,message="timeout"});step(r,j);step(r,j)
 if after then check(j.state=="ready" and b.writes==1,"lost ack was not resolved by readback")
 else
  check(j.state=="retry" and b.writes==0,"failed write was claimed durable")
  check(r:retry(j),"write failure could not retry");drive(r,j)
  check(j.state=="ready" and b.writes==1,"retry did not publish")
 end
end
do
 local b,r=fixture();b:fail({op="read",key=anchor.id});local j=begin(r);step(r,j)
 check(j.state=="retry" and b.writes==0,"read failure defaulted to missing")
 check(r:retry(j),"read retry refused");drive(r,j);check(j.state=="ready","read retry failed")
end
do
 local b,r=fixture();local a=begin(r);local c=begin(r,second)
 step(r,a);step(r,c);step(r,a);step(r,c);drive(r,a);drive(r,c)
 check(a.state=="ready" and c.state=="ready" and b.writes==1,"competing publication overwrote first writer")
 check(Json.canonical(a.anchor)==Json.canonical(c.anchor),"competing jobs selected different durable proposals")
end
for _,value in {false,{version=99},brokenTransport} do
 local b,r=fixture();b:poke(anchor.id,value);local before=Json.canonical(value);local j=begin(r);drive(r,j)
 check(j.state=="refused" and b.writes==0 and Json.canonical(b.data[anchor.id])==before,"invalid existing value was overwritten/defaulted")
end
do
 local b,r=fixture();b:poke(anchor.id,anchor);local other=begin(r,wideAnchor);drive(r,other)
 check(other.state=="refused" and b.writes==0,"different archive/source proposal was reused")
 local cycle={};cycle.self=cycle
 check(r:begin(cycle,function() return true end)==nil,"cyclic candidate not bounded before copy")
 b:poke(anchor.id,cycle);local j=begin(r)
 -- MemoryBackend.copy itself cannot read a cycle. Replace this read only to
 -- model a hostile adapter; the publication layer must bound before copying.
 b.readRawFresh=function(self,key) self.requests+=1;return true,cycle,nil end
 drive(r,j);check(j.state=="refused","cyclic readback not bounded")
end
for _,point in {"before","read","write","callback"} do
 local b,r=fixture();local live=true;local j=begin(r,nil,function() return live end)
 if point=="before" then live=false
 elseif point=="read" then b.readRawFresh=function(self,key) live=false;return self:read(key) end
 else
  step(r,j)
  local original=b.update
  b.update=function(self,key,fn)
   if point=="write" then local ok,v,e=original(self,key,fn);live=false;return ok,v,e end
   live=false;return original(self,key,fn)
  end
 end
 drive(r,j)
 check(j.state=="refused" and j.anchor==nil,"revoked publication became visible")
 if point~="write" then check(b.writes==0,"revoked publication wrote") end
end
do
 local b,r=fixture();local j=begin(r);step(r,j)
 local original=b.update;b.update=function(self,key,fn) r:cancel(j);return original(self,key,fn) end
 step(r,j);check(j.state=="cancelled" and b.writes==0 and j.anchor==nil,"reentrant cancellation lost")
 check(not r:retry(j),"cancelled job resurrected")
end
do
 local b,r=fixture();b.update=function(self,key,fn) self.requests+=1;return true,anchor,nil end
 local j=begin(r);drive(r,j)
 check(j.state=="retry" and j.requests==3 and j.anchor==nil,"success ack/candidate was mistaken for durable readback")
end
do
 local b,r=fixture();local mutable=Json.copy(anchor);local j=begin(r,mutable);mutable.target.data="changed-after-begin";drive(r,j)
 check(j.state=="ready" and j.anchor.target.data==anchor.target.data,"caller mutation changed owned proposal")
 local updated=Json.copy(incoming);updated.settings.SoundMuted=true
 local later=assert(__packetPrototype.prepare("46001","main",archive,updated,111,template,fresh,codec,"primary",201))
 local again=begin(r,later);drive(r,again)
 check(again.state=="ready" and again.payload.progressTime==110 and again.payload.progress.settings.SoundMuted==false,"later observations replaced first durable proposal")
end
print("RECOVERY_PROPOSAL_STORE passed="..count.." failed=0")
