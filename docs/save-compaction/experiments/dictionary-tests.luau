local Codec=require("../src/Shared/Persistence/RestCodec")
local Json=require("../src/Shared/Persistence/Json")
local passed=0
local function check(ok,why) assert(ok,why);passed+=1 end
local function roundtrip(v)
 local before=assert(Json.canonical(v))
 local packed=assert(Codec.encode(v))
 local plain,why=Codec.decode(packed)
 assert(why==nil and plain~=nil,why)
 check(assert(Json.canonical(plain))==before,"round-trip changed the record")
 check(assert(Json.canonical(Codec.encode(plain)))==assert(Json.canonical(packed)),"encoding is not deterministic")
 check(assert(Json.canonical(v))==before,"source mutated")
 return packed
end
local graph={hello="world",objects={{c="Fly",e={{"seed",914},{"next",{["$o"]=1}}}}}}
for _,v in {true,false,0,-1,-1.25,1e-20,-1e20,"",'\"\\\n\000',"mÃ©tamorphose",{}, {false,0,-2,""},graph} do roundtrip(v) end
local a={z=3,a=1,m={"same","same"}}
local b={m={"same","same"},a=1,z=3}
check(assert(Json.canonical(Codec.encode(a)))==assert(Json.canonical(Codec.encode(b))),"map insertion order leaked")
local sample={}
for i=1,1000 do sample[i]={id=i,state="PERCHED",energy=-.015,remaining=12.3,position={x=-5,y=3,z=0},reference={["$o"]=i}} end
local packed=roundtrip(sample)
check(#assert(Json.canonical(packed))<#assert(Json.canonical(sample)),"repetition was not compacted")
local function refused(v)
 local ok,result,why=pcall(Codec.decode,v)
 check(ok and result==nil and type(why)=="string","malformed compact record accepted or raised")
end
refused({})
refused({format=Codec.FORMAT,strings={},numbers={},root={9}})
refused({format=Codec.FORMAT,strings={},numbers={},root=-1})
refused({format=Codec.FORMAT,strings={"a","a"},numbers={},root=1})
refused({format=Codec.FORMAT,strings={"a"},numbers={1},root={1,1,0,1,1}})
refused({format=Codec.FORMAT,strings={},numbers={},root={2,0}})
refused({format=Codec.FORMAT,strings={},numbers={},root={2,-math.huge}})
refused({format=Codec.FORMAT,strings={},numbers={},root={0},extra=true})
refused({format=Codec.FORMAT,strings={},numbers={},root={[1]=0,[3]=1}})
local cycle={0};cycle[2]=cycle
refused({format=Codec.FORMAT,strings={},numbers={},root=cycle})
for _,v in {math.huge,0/0,setmetatable({},{}),function()end,{[2]=1},{[1]=1,x=2}} do
 local ok,result,why=pcall(Codec.encode,v)
 check(ok and result==nil and why~=nil,"invalid input accepted or raised")
end
local repeated={};check(Codec.encode({repeated,repeated})==nil,"repeated table accepted")
local deep={};local at=deep
for i=1,Codec.MAX_DEPTH+1 do at[1]={};at=at[1] end
check(Codec.encode(deep)==nil,"encoder depth limit ignored")
local nested={0};at=nested
for i=1,Codec.MAX_DEPTH+1 do at[2]={0};at=at[2] end
refused({format=Codec.FORMAT,strings={},numbers={},root=nested})
local oldNodes,oldStrings=Codec.MAX_NODES,Codec.MAX_EXPANDED_STRING_BYTES
Codec.MAX_NODES=5
check(Codec.encode({1,2,3,4,5})==nil,"encoder node limit ignored")
refused({format=Codec.FORMAT,strings={},numbers={1,2,3,4,5},root={0,1,2,3,4,5}})
Codec.MAX_NODES=oldNodes;Codec.MAX_EXPANDED_STRING_BYTES=10
check(Codec.encode({"abcdef","abcdef"})==nil,"expanded string encode limit ignored")
refused({format=Codec.FORMAT,strings={"abcdef"},numbers={},root={0,-1,-1}})
Codec.MAX_EXPANDED_STRING_BYTES=oldStrings
print(`REST_CODEC passed={passed} failed=0`)
