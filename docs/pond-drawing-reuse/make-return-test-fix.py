"""A stronger snapshot oracle for the client smoke return case, private until tested."""
from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
p=ROOT/'roblox_port/tests/client_smoke.luau';original=p.read_bytes();text=original.decode()
old='\tlocal energy, hour, tick = needs.energy, life.clock.hour, prey.tick'
assert text.count(old)==1
new=''' -- Saving prepares asynchronously while the life continues. The oracle is
 -- the immutable kept snapshot, not a later live sample after preparation.
 local Checkpoint=require("../src/Shared/Persistence/Checkpoint")
 local ObjectRecord=require("../src/Shared/Persistence/ObjectRecord")
 local kept=driver.currentStore():loadBest()
 assert(kept.ok,"no kept snapshot")
 local decoded,why=ObjectRecord.decode(kept.record.world,Checkpoint.CLASSES,Checkpoint.refs(driver))
 assert(decoded,table.concat(why or {},"; "))
 local snapshot=decoded.roots
 local energy,hour,tick=snapshot.needs.energy,snapshot.life.clock.hour,snapshot.prey.tick
 -- Cross a 2Hz reserve update before returning, so a later-live-value oracle
 -- would fail even though the actual snapshot restore is correct.
 frames(29)
 assert(math.abs(needs.energy-energy)>1e-6,"delay did not exercise hunger after the snapshot")'''
text=text.replace(old,new)
old='key("Reset", true); frames(1); key("Reset", false); awaitReturn(ClientStubs.driver,function() frame(0) end); frames(2)'
assert text.count(old)==2
start=text.index('check("Backspace returns to the checkpoint kept by a rest')
end=text.index('check("sound pauses with the menu',start)
case=text[start:end]
assert case.count(old)==1
case=case.replace(old,old.removesuffix('; frames(2)'))
case=case.replace('key("Reset", true); frames(1); key("Reset", false);','key("Reset", true); key("Reset", false);')
case=case.replace('assert(driver.lifeSpider().inRetreat and life.resting, "not back resting in the crack")','assert(Layout.inRetreat(driver.motor.pos) and life.resting, "not back resting in the crack")')
oldAssertion='assert(math.abs(life.clock.hour - hour) < 0.01 and prey.tick < tick + 10, `not the checkpoint\'s time (hour {life.clock.hour}, tick {prey.tick})`)'
assert case.count(oldAssertion)==1
case=case.replace(oldAssertion,'assert(life.clock.hour == hour and prey.tick == tick, `not the checkpoint\'s exact time (hour {life.clock.hour}, tick {prey.tick})`)')
marker='\t-- (ROBLOX-113: the return\'s explanation'
assert case.count(marker)==1
case=case.replace(marker,'\tframes(2) -- only resume after checking the atomic restored state\n\tassert(driver.lifeSpider().inRetreat,"derived retreat state did not refresh")\n'+marker)
text=text[:start]+case+text[end:]
(HERE/'client-smoke-snapshot-candidate.luau').write_text(text,encoding='utf8',newline='\n')
(HERE/'return-test-candidate.json').write_text(json.dumps(dict(original_sha256=hashlib.sha256(original).hexdigest(),candidate_sha256=hashlib.sha256(text.encode()).hexdigest(),runtime_changed=False,adopted=False),indent=2)+'\n',encoding='utf8',newline='\n')
print('Private snapshot-oracle candidate generated.')
