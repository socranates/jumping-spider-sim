local Json=require("../src/Shared/Persistence/Json")
local Memory=require("../src/Shared/Persistence/MemoryBackend")
local Collector=__collectorPrototype
local b=Memory.new();b.readRawFresh=function(self,key) return self:read(key) end
for _,key in {"P_12345","R_12345_main"} do
 local items={};for i=1,160 do items[i]="opaque" end
 b:poke(key,{items=items})
end
local before=assert(Json.canonical(b.data))
local c=Collector.new(b,"12345",nil,{nodes=500},{now=function() return 0 end})
local j=c:begin("bounded raw collection",function() return true end)
for _=1,20 do
 if j.state~="pending" or (j.phase=="collect" and j.cursor>=3) then break end
 c:step(j)
end
local function nodes(value)
 local n=1
 if type(value)=="table" then for key,child in value do n+=nodes(key)+nodes(child) end end
 return n
end
local retained=0;for _,source in j.sources do retained+=nodes(source.value) end
assert(b.writes==0 and Json.canonical(b.data)==before and j.plan==nil,"node bound probe changed sources or published a partial plan")
if EXPECTED_BOUNDED then
 assert(j.state=="refused" and retained<=500,"collector retained copies beyond its aggregate node allowance")
else assert(j.state=="pending" and retained>500,"baseline aggregate copy overrun did not reproduce") end
print("RECOVERY_SOURCE_AGGREGATE passed=2 failed=0 retained_nodes="..retained.." allowance=500 bounded="..tostring(EXPECTED_BOUNDED))
