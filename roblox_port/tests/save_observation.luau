-- Private observation catalog invariants; no claim about leases or transport.
local Observation=require("../src/Shared/Persistence/SaveObservation")
local Rules=require("../src/Shared/Data/SaveRules")
local Json=require("../src/Shared/Persistence/Json")
local passed,failed=0,0
local function check(ok,why) if ok then passed+=1 else failed+=1;print("FAIL OBSERVATION "..why) end end
local function identity(label,life,kind)
 return {checksum=Json.checksum(label),updatedAt=123,life=life,kind=kind or "primary"}
end
local function record(value,life) return {save_life=life,world={population={value=value}}} end
local function canonical(v) return assert(Json.canonical(v)) end
for _,mode in Rules.MODES do
 local c=Observation.new("isolated-session")
 local original=record(7);local stamp=identity("original")
 local offer=c:publish(mode,original,stamp)
 original.world.population.value=99;stamp.updatedAt=999
 offer.record.world.population.value=101
 check(c:offer(mode).record.world.population.value==7,mode..": input and outgoing tables cannot mutate private snapshot")
 local chosen,why=c:select(mode,1,offer.id)
 check(chosen and why==nil and chosen.record.world.population.value==7,mode..": explicit selection uses the displayed immutable snapshot")
 chosen.identity.updatedAt=0;chosen.record.world.population.value=0
 check(c:matches(mode,identity("original")),mode..": selection consumer cannot mutate accepted identity")
 local nextOffer=c:publish(mode,record(8),identity("changed-at-same-time"))
 check(nextOffer.id~=offer.id and c:selection(mode).record.world.population.value==7,mode..": latest update cannot silently rebase a selected world")
 check(not c:matches(mode,identity("changed-at-same-time")) and not c:matches(mode,identity("original")),mode..": equal time/nil life cannot authorize changed checksum")
 local repeated=c:select(mode,1,offer.id)
 check(repeated and repeated.record.world.population.value==7,mode..": duplicate old intent is idempotent after latest changes")
 local wrong,reason=c:select(mode,1,nextOffer.id)
 check(wrong==nil and reason=="stale",mode..": one serial cannot select two records")
 local accepted=c:select(mode,2,nextOffer.id)
 check(accepted and accepted.record.world.population.value==8 and c:matches(mode,identity("changed-at-same-time")),mode..": only a new explicit choice selects the new observation")
 check(c:select(mode,1,offer.id)==nil and c:selection(mode).serial==2,mode..": old intent cannot roll back newer selection")
 c:withdraw(mode)
 check(c:offer(mode)==nil and not c:matches(mode,identity("changed-at-same-time")) and c:selection(mode).record.world.population.value==8,mode..": missing latest disables agreement without erasing played snapshot")
end

do
 local c=Observation.new("protection")
 local offer=c:publish("main",record(1,"life"),identity("a","life"))
 c:select("main",1,offer.id)
 local changed=c:publish("main",record(1,"life"),identity("a","life"),true)
 check(changed.id~=offer.id and not c:matches("main",identity("a","life")),"new protection revokes identity agreement even without changed checksum")
 c:select("main",2,changed.id)
 check(not c:matches("main",identity("a","life")),"selected protected record cannot become a writable agreement")
 local backup=c:publish("main",record(1,"life"),identity("a","life","backup"))
 c:select("main",3,backup.id)
 check(not c:matches("main",identity("a","life","primary")),"backup selection cannot authorize replacing a primary")
 check(not c:matches("main",identity("a","another-life","backup")),"life identity is part of agreement")
 check(not c:matches("main",{checksum=Json.checksum("a"),updatedAt=124,life="life",kind="backup"}),"updatedAt is part of agreement")
end

do
 local c=Observation.new("slots");local a=c:publish("main",record(1),identity("a"));local b=c:publish("free",record(2),identity("b"))
 check(c:select("free",1,a.id)==nil and c:selection("main")==nil,"another slot's id never selects or mutates its source slot")
 check(c:select("free",2,b.id)~=nil,"a fresh intent can recover after refusing a wrong offer")
 for _,value in {0,-1,1.5,math.huge,0/0,Rules.MAX_LIFE_SERIAL+1,"3",{}} do
  check(c:select("free",value,b.id)==nil,"invalid intent serial refused")
 end
 check(c:select("unknown",3,b.id)==nil and c:select("free",3,string.rep("a",Rules.MAX_LIFE_TOKEN_CHARS+1))==nil,"unknown mode and oversized offer id refused")
 check(c:publish("main",record(1,"one"),identity("a","two"))==nil,"record and observation life identities cannot disagree")
 local old=c:offer("main");c:select("main",1,old.id)
 for i=1,1000 do c:publish("main",record(i),identity(tostring(i))) end
 check(c:selection("main").record.world.population.value==1,"rapid refresh leaves the selected snapshot intact")
 local count=0;local seen={}
 for _,group in {c.latest,c.choices} do for _,item in group do local value=item.offer or item;if value.record and not seen[value] then seen[value]=true;count+=1 end end end
 check(count<=4,"two slots retain at most one latest and one selected record each")
 check(c:select("main",2,old.id)==nil and c:selection("main")==nil,"stale displayed offer is refused rather than rebound to a refresh")
end
print(`SAVE_OBSERVATION passed={passed} failed={failed}`)
if failed>0 then error("save observation checks failed") end
