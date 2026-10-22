-- Save-format compatibility, exact rejection paths, and private cooperative results.
local Original=require("./studio/LegacyCanonical")
local Candidate=require("../src/Shared/Persistence/Json")
local Work=require("../src/Shared/Persistence/SaveWork")
local checks=0
local function compare(value,label)
 local a,ae=Original.canonical(value)
 local b,be=Candidate.canonical(value)
 checks+=1;assert(a==b and ae==be,"encoding differs: "..label.."; "..tostring(ae).." / "..tostring(be))
 return a
end
for _,v in {true,false,0,-0,1,-1,255,256,-256,2^53-1,2^53,-2^53,1e-300,1e300,math.pi,math.huge,-math.huge,0/0} do compare(v,"number/boolean") end
compare(nil,"nil")
for _,s in {"","plain","quote\"slash\\","\000\001\b\f\n\r\t\127","spider \240\159\149\183","\255\254"} do compare(s,"string") end
compare(function() end,"function");compare(coroutine.create(function() end),"thread");compare(buffer.create(2),"buffer")
for _,v in {{},{1,2,3},{a=1,z=2},{[0]=1},{[2]=2},{[1]=1,[3]=3},{[1.5]=1},{[true]=1},{a=1,[1]=2},setmetatable({a=1},{})} do compare(v,"shape") end
local shared={x=1};compare({a=shared,b=shared},"alias")
local cycle={};cycle.self=cycle;compare({nested={cycle}},"cycle path")
compare({a={b={math.huge}}},"invalid nested number path")
compare({a={b=setmetatable({},{})}},"invalid nested metatable path")
local seed=731991
local function random(n)
 seed=bit32.bxor(seed,bit32.lshift(seed,13));seed=bit32.bxor(seed,bit32.rshift(seed,17));seed=bit32.bxor(seed,bit32.lshift(seed,5))
 return seed%n
end
local function value(depth)
 local kind=random(if depth<4 then 7 else 4)
 if kind==0 then return random(2)==0 end
 if kind==1 then return (random(200001)-100000)/(if random(2)==0 then 1 else 317) end
 if kind==2 then return string.char(random(256)).."\n"..tostring(random(1000)) end
 if kind==3 then return "key"..tostring(random(1000)) end
 local out={}
 for i=1,random(7) do
  if kind==4 then out[i]=value(depth+1) else out["k"..tostring(random(9))]=value(depth+1) end
 end
 return out
end
for i=1,20000 do
 local v=value(0);compare(v,"seeded "..i)
 if type(v)=="table" and i%13==0 then v.invalid=if i%2==0 then math.huge else function() end;compare(v,"seeded rejection "..i) end
end
local deep={};local cursor=deep
for i=1,100 do local child={};cursor.child=child;cursor=child end
compare(deep,"deep valid");cursor.invalid=math.huge;compare(deep,"deep rejection")
local owned={};for i=1,5000 do owned[i]={id=i,name="fly",position={i*.1,0,-i*.3}} end
local expected=assert(compare(owned,"large synthetic"))
local function job(fn,record)
 local clock=0
 return Work.new(function() return fn(record) end,{budget=.001,maxSeconds=10000,now=function() clock+=.0001;return clock end})
end
local a,b=job(Candidate.canonical,owned),job(Candidate.canonical,{other=owned})
a:step();b:step();assert(a.state=="pending" and b.state=="pending" and a:take()==nil and b:take()==nil)
while a.state=="pending" or b.state=="pending" do a:step();b:step() end
assert(a.state=="done" and b.state=="done")
assert(a:take()[1]==expected and b:take()[1]==assert(Original.canonical({other=owned})))
local cancelled=job(Candidate.canonical,owned);cancelled:step();assert(cancelled:cancel() and cancelled:take()==nil and Work.pulse()==nil)
checks+=4
print(`JSON_ENCODING passed={checks} failed=0`)

