"""Protected New policy through real Session/Service/Client and prior cohort."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess,sys,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1];P=ROOT/'docs/save-slot-isolation'
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def build(focused=False,cancel_only=False,baseline=False):
 prior=load('application_new_base',ROOT/'docs/recovery-application/run.py');runner=load('new_game_runner',ROOT/'roblox_port/tests/run.py')
 bundle,inputs=prior.build();assert bundle.endswith('end\n');bundle=bundle[:-4]
 path=H/('before-cancel-fence-new-life-policy.luau' if baseline else 'new-life-policy-prototype.luau');code=path.read_text(encoding='utf8')
 for name,var in {'RecoverySessionFencePrototype':'__sessionFence','RecoveryControllerPrototype':'__archiveControllerPrototype','RecoveryArchiveStorePrototype':'__archiveStorePrototype','RecoveryOfferReaderPrototype':'__offerReaderPrototype','RecoveryReadLeasePrototype':'__readLeasePrototype','RecoveryRoutineProgressPrototype':'__routineProgressPrototype'}.items():
  code=code.replace('require(Shared.Persistence.'+name+')',var).replace('require(script.Parent.'+name+')',var)
 bundle+='local __newLifePolicy=(function()\n'+runner.requires(runner.strict(code))+'\nend)()\n'
 body=(P/'replacement-tests.luau').read_text(encoding='utf8')
 prefix=body.split('-- A player can leave before a cooperative initial factory',1)[0]
 assert prefix!=body and prefix.endswith(' return f\nend\n')
 prefix=prefix.replace('runReplacementChecks','runProtectedNewChecks',1)
 # Match the production SpiderClient's retired-record validator. The older
 # replacement-only fixture never exercised minimal ordinary retirement rows.
 anchor='validate=function(mode,record)\n'
 assert prefix.count(anchor)==1
 prefix=prefix.replace(anchor,'validate=function(mode,record,retired)\n   if retired and SaveRest.isRetired(record) then return SaveRest.bounded(record,10,3)==nil and #SaveRest.SPECS[mode].validate(record)==0 end\n',1)
 anchor=' local ds={}\n'
 assert prefix.count(anchor)==1
 ordinary=''' if options.ordinaryMode then
  local mode=options.ordinaryMode;local w=newWorld();w.garden={};w.life.mode=if mode=="free" then "free" else "main"
  w.life.rules=if mode=="main" then "standard" else "gentle";w.needs.gentle=mode~="main"
  f.b:poke("R_46001_"..mode,codec:encode(Envelope.make(SaveRest.SPECS[mode],assert(Checkpoint.capture(w,100)),100,nil)))
 end
'''
 prefix=prefix.replace(anchor,ordinary+anchor,1)
 prefix=prefix.replace(' local ds={}\n',' if options.seedStore then f.b.data=Json.copy(options.seedStore) end\n local ds={}\n',1)
 prefix=prefix.replace('  requested()\n  check(opts==nil', '  requested()\n  if f.pauseReadKey==key then f.pauseReadKey=nil;coroutine.yield("new-provider-paused") end\n  check(opts==nil',1)
 prefix=prefix.replace('   f.clock.now+=dt\n','   f.clock.now+=dt\n   if f.resumeRead and coroutine.status(f.resumeRead)=="suspended" then local ok,why=coroutine.resume(f.resumeRead);assert(ok,why) end\n',1)
 prefix=prefix.replace('currentFormat=__restFormatPrototype,entryFactory=', 'currentFormat=__restFormatPrototype,freshWriterFactory=__currentWriterPrototype,entryFactory=',1)
 prefix=prefix.replace(' function ds:UpdateAsync(key,fn)\n',' function ds:UpdateAsync(key,fn)\n  if f.pauseUpdateKey==key then f.pauseUpdateKey=nil;coroutine.yield("new-write-paused") end\n',1)
 test=H/'tests.luau';extra=H/'cancel-write-tests.luau';test_code=test.read_text(encoding='utf8');cancel_code=extra.read_text(encoding='utf8')
 marker='print("PROTECTED_NEW passed="..count.." failed=0")'
 assert test_code.count(marker)==1
 if cancel_only:
  test_code=test_code.split('for _,mode in Rules.MODES do',1)[0]+cancel_code+'\n'+marker+'\nend\nrunProtectedNewChecks()\nend\n'
 else:test_code=test_code.replace(marker,cancel_code+'\n'+marker,1)
 bundle+=runner.requires(prefix+test_code)+'\nend\n'
 if focused:bundle=re.sub(r'\n(run\w+Checks)\(\)\nend',lambda m:'\n-- focused: skip '+m[1]+'\nend' if m[1]!='runProtectedNewChecks' else m[0],bundle)
 return bundle,list(dict.fromkeys(inputs+[path,test,extra]))
def main():
 prefix=sys.argv[1];assert prefix.replace('-','').isalnum();focused='--focused' in sys.argv[2:];cancel_only='--cancel-only' in sys.argv[2:];baseline='--baseline-cancel' in sys.argv[2:]
 assert not baseline or focused and cancel_only,'Negative baseline requires the bounded focused cancellation test'
 out=H/(prefix+'-output.txt');assert not out.exists(),'Preserve prior evidence'
 bundle,inputs=build(focused,cancel_only,baseline);sha=lambda b:hashlib.sha256(b).hexdigest()
 hashes={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in inputs}
 production={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for folder in ['roblox_port/src','roblox_port/tests'] for p in (ROOT/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts}
 with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(bundle);path=Path(f.name)
 try:result=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(path)],capture_output=True,text=True)
 finally:path.unlink(missing_ok=True)
 assert hashes=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in inputs}
 assert production=={p:sha((ROOT/p).read_bytes()) for p in production}
 output=result.stdout+result.stderr;out.write_text(output,encoding='utf8',newline='\n')
 r=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),focused=focused,cancel_only=cancel_only,baseline_cancel=baseline,exit_code=result.returncode,inputs=hashes,production_inputs=production,bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),native_verified=False,real_datastore_verified=False,published=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(output,flush=True);raise SystemExit(result.returncode)
if __name__=='__main__':main()
