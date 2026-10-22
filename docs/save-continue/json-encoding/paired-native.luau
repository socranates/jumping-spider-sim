-- Isolated byte/error equivalence and cooperative encoder cost. Never publish.
local Run=game:GetService("RunService")
local Shared=game.ReplicatedStorage.Shared
local Original=require(Shared.Persistence.Json)
local Candidate=require(script.Parent.JsonCandidate)
local Work=require(Shared.Persistence.SaveWork)
local Map=require(Shared.World.WorldMap)
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("JsonEncodingProbe")==true)
 local id=tostring(DateTime.now().UnixTimestampMillis)
 local checks=0
 local function check(ok,why) checks+=1;assert(ok,why) end
 local function differential()
-- Private differential/CPU probe; production still uses the original Json module.
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
print("[NATIVE_ENCODING_DIFFERENTIAL_PASS]",id,checks)


 return checks
 end
 local ok,problem=xpcall(function()
  print("[NATIVE_ENCODING_BEGIN]",id)
  local deadline=os.clock()+90
  while game.Players.LocalPlayer:GetAttribute("TitleReady")~=true and os.clock()<deadline do Run.Heartbeat:Wait() end
  check(game.Players.LocalPlayer:GetAttribute("TitleReady")==true,"startup failed")
  d.title.seen=true;d.session.finishedMain=true;check(d.fresh("main",false,nil),"fresh refused")
  d.place(Vector3.new(-25.5,.31,6));for _=1,6 do Run.Heartbeat:Wait() end;d.openMenu()
  checks+=differential()
  local attempts=0
  for _,region in Map.regions() do
   d.world.prey:directors(region.id);d.world.prey:bugs(region.id);d.world.prey:ambient(region.id)
   attempts+=1;if attempts%4==0 then Run.Heartbeat:Wait() end
  end
  d.place(Vector3.new(-25.5,.31,6));d.motor.vel=Vector3.zero;d.needs.energy=.9;d.life.clock.hour=12
  local token=d.life.save();check(token.pending,"baseline capture failed")
  deadline=os.clock()+120
  while token.pending and os.clock()<deadline do Run.Heartbeat:Wait() end
  check(not token.pending and token.ok,"baseline rest failed")
  local best=d.currentStore():loadBest();check(best.ok,"baseline rest invalid")
  local record=best.record;local text=assert(Original.canonical(record))
  check(#text>1000000 and attempts==233,"large fixture missing")
  print("[NATIVE_ENCODING_RECORD]",id,#text,attempts,"resident_regions_unmeasured")
  local function measure(fn,label,round)
   local work=Work.new(function() return fn(record) end,{budget=.002,maxSeconds=120})
   local steps,total,worst,gap=0,0,0,0
   local before=gcinfo();local peak=before;local start=os.clock()
   while work.state=="pending" do
    gap=math.max(gap,Run.Heartbeat:Wait())
    local at=os.clock();work:step();local cost=os.clock()-at
    total+=cost;worst=math.max(worst,cost);steps+=1;peak=math.max(peak,gcinfo())
   end
   check(work.state=="done",tostring(work.problem))
   local result=work:take();check(result[1]==text and result[2]==nil,"preserve output changed")
   print("[NATIVE_ENCODING_CPU]",id,label,round,#text,steps,string.format("%.3f",total*1000),string.format("%.3f",worst*1000),string.format("%.3f",gap*1000),string.format("%.3f",(os.clock()-start)*1000),string.format("%.3f",peak-before))
  end
  for round=1,4 do
   if round%2==0 then measure(Candidate.canonical,"candidate",round);measure(Original.canonical,"original",round)
   else measure(Original.canonical,"original",round);measure(Candidate.canonical,"candidate",round) end
  end
  print("[NATIVE_ENCODING_PASS]",id,checks,"paired_encode_cpu_not_fps")
 end,debug.traceback)
 if not ok then warn("[NATIVE_ENCODING_FAIL]",id,tostring(problem)) end
end
