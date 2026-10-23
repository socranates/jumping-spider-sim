local now=200
local available={read=20,write=20}
local function config()
 return {now=function() return now end,available=function() return available end,actorRead=7,actorWrite=4,serverRead=20,serverWrite=15,headroom=1,maxActors=16,maxPending=64}
end
local a,b=Old.new(config()),Next.new(config())
local scopes,tickets={},{}
local count,startedA,startedB=0,0,0
local function check(ok,why) assert(ok,why);count+=1 end
for i=1,8 do
 local user=tostring(i);local sa,sb=assert(a:open(user,"1")),assert(b:open(user,"1"));scopes[i]={sa,sb,epoch=1}
 local history={};for j=1,i%5 do table.insert(history,199) end
 check(a:importLegacy(sa,history)==b:importLegacy(sb,history),"seed difference")
end
local rng=9173
local function choose(n) rng=(rng*48271)%2147483647;return 1+rng%n end
local function inspect()
 local x,y=a:inspect(),b:inspect()
 for k,v in x do check(y[k]==v,"aggregate state difference: "..k) end
 check(startedA==startedB,"provider start difference")
end
for step=1,1200 do
 now+=choose(3)-1;available.read=choose(25)-1;available.write=choose(25)-1
 local action=choose(6);local actor=choose(8);local s=scopes[actor]
 if action==1 or action==2 then
  local kind=({"read","write","update"})[choose(3)]
  local ta,tb=a:request(s[1],kind),b:request(s[2],kind)
  check((ta~=nil)==(tb~=nil),"request difference")
  if ta then table.insert(tickets,{ta,tb}) end
 elseif action==6 then
  check(a:close(s[1])==b:close(s[2]),"close difference")
  s.epoch+=1;local sa,sb=a:open(tostring(actor),tostring(s.epoch)),b:open(tostring(actor),tostring(s.epoch))
  check((sa~=nil)==(sb~=nil),"open difference");s[1],s[2]=sa,sb
 elseif #tickets>0 then
  local pair=tickets[choose(#tickets)]
  if action==3 then check(a:reserve(pair[1])==b:reserve(pair[2]),"reservation difference")
  elseif action==4 then check(a:cancel(pair[1])==b:cancel(pair[2]),"cancel difference")
  else
   local calledA=a:dispatch(pair[1],function() startedA+=1;return step end)
   local calledB=b:dispatch(pair[2],function() startedB+=1;return step end)
   check(calledA==calledB,"dispatch difference")
  end
 end
 inspect()
end
print("ADMISSION_LEDGER_EQUIVALENCE passed="..count.." failed=0 steps=1200 provider_starts="..startedA)
