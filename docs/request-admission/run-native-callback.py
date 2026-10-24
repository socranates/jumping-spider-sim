"""Reproduce Roblox's distinct UpdateAsync callback coroutine in actual service New."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,subprocess,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
p=argparse.ArgumentParser();p.add_argument('prefix');p.add_argument('--before-fix',action='store_true');a=p.parse_args()
assert a.prefix.replace('-','').isalnum()
out=H/(a.prefix+'-output.txt');assert not out.exists()
spec=importlib.util.spec_from_file_location('callback_service',H/'run-service.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
bundle,paths=m.build(True)
if a.before_fix:
 new='if j.state~="pending" or j.writeState~=evidence or not scope(self,j) then evidence.rejected="New write scope ended";return nil end'
 old='if not scope(self,j) or not s.backend:permitted(j.held) then evidence.rejected="New write scope ended";return nil end'
 assert bundle.count(new)==1
 bundle=bundle.replace(new,old)
needle='local ok,value,why=f.b:update(key,fn);if not ok then error(why) end'
assert bundle.count(needle)==5 # four preceding fixtures plus this service fixture
replacement='''local callback=fn
  if f.crossThreadUpdate then
   if string.sub(key,1,2)=="R_" and f.owner.newLifeJob and f.owner.newLifeJob.phase=="write" then
    f.retirementCallback=fn;f.retirementKey=key
    if f.cancelRetirement then
     f.cancelRetirement=false
     assert(f.owner.newLifePolicy:cancel(f.owner.newLifeJob))
     f.cancelledRetirement=true
    end
   end
   callback=function(old)
    local caller=coroutine.running()
    local co=coroutine.create(function()
     assert(coroutine.running()~=caller,"callback must have its own coroutine")
     f.crossThreadCallbacks=(f.crossThreadCallbacks or 0)+1
     return fn(old)
    end)
    local result=table.pack(coroutine.resume(co))
    assert(result[1],result[2]);assert(coroutine.status(co)=="dead","storage transform yielded")
    return result[2]
   end
  end
  local ok,value,why=f.b:update(key,callback);if not ok then error(why) end'''
before,sep,after=bundle.rpartition(needle);assert sep
bundle=before+replacement+after
tests=(H/'service-new-tests.luau').read_text(encoding='utf8')
tests=tests.replace('actual-protected-new-and-fresh-checkpoint-','native-callback-protected-new-and-fresh-checkpoint-')
tests=tests.replace('f.offers();local info=', 'f.offers();f.crossThreadUpdate=true;local info=')
tests=tests.replace('f.drive(function() return f.newState=="verified" end)', '''f.drive(function()
   assert(f.newState~="refused","native callback New refused: "..tostring(f.owner.newLifeJob and f.owner.newLifeJob.problem))
   return f.newState=="verified"
  end)
  check(f.retirementCallback~=nil and f.retirementCallback(Json.copy(f.b.data[f.retirementKey]))==nil,"completed retirement callback replay remained authorized")''')
tests=tests.replace('  f.server:removePlayer(f.player);closed(f)','  check((f.crossThreadCallbacks or 0)>0,"no separate callback was exercised")\n  f.server:removePlayer(f.player);closed(f)')
tests+='''
for _,mode in Rules.MODES do
 test("native-callback-cancelled-retirement-"..mode,function()
  local f=fixture({newLife=true});f.offers();f.crossThreadUpdate=true;f.cancelRetirement=true
  local before=Json.canonical(f.b.data["R_46001_"..mode])
  assert(f.client:prepareNewLife(mode,f.client:offerInfo(mode).id))
  f.drive(function() return f.newState=="refused" end)
  check(f.cancelledRetirement and f.retirementCallback~=nil,"cancellation did not reach native callback")
  check(Json.canonical(f.b.data["R_46001_"..mode])==before,"cancelled callback changed selected rest")
  check(f.retirementCallback(Json.copy(f.b.data[f.retirementKey]))==nil,"cancelled callback replay returned data")
  check(Json.canonical(f.b.data["A1_46001_"..mode].raw)==before,"cancelled New lost original archive")
  check(f.client.newLife.request.credential==nil,"cancelled New granted gameplay")
  f.server:removePlayer(f.player);closed(f)
 end)
end
'''
marker='print("ACCOUNT_SERVICE passed="..count.." failed=0 groups="..groups)'
assert bundle.count(marker)==1
bundle=bundle.replace(marker,tests+'\n'+marker,1)
sha=lambda b:hashlib.sha256(b).hexdigest()
inputs={str(x.relative_to(ROOT)):sha(x.read_bytes()) for x in paths}
with tempfile.TemporaryDirectory(prefix='windowsill-native-callback-') as temp:
 path=Path(temp)/'run.luau';path.write_text(bundle,encoding='utf8',newline='\n')
 r=subprocess.run(['C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(path)],capture_output=True,text=True)
text=r.stdout+r.stderr;out.write_text(text,encoding='utf8',newline='\n')
receipt=dict(exit_code=r.returncode,inputs=inputs,before_fix=a.before_fix,bundle_sha256=sha(bundle.encode()),output_sha256=sha(text.encode()),
 provider='memory-injected-DataStoreBackend-distinct-callback-coroutine',online_verified=False,published=False)
(H/(a.prefix+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8')
if r.returncode:(H/(a.prefix+'-bundle.luau')).write_text(bundle,encoding='utf8',newline='\n')
print(text[-6000:]);raise SystemExit(r.returncode)
