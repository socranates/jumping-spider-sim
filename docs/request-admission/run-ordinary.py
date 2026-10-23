"""Ordinary Session override, all earlier private regressions and real API cases."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess,sys,tempfile,time
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def load(name,path):
 s=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def replacement():
 r=load('ordinary_core_runner',ROOT/'roblox_port/tests/run.py')
 facade='(function()\n'+(H/'worker-facade.luau').read_text(encoding='utf8')+'\nend)()'
 operation='(function()\n'+(H/'operation.luau').read_text(encoding='utf8').replace('require("./worker-facade")',facade)+'\nend)()'
 io='(function()\n'+r.requires(r.strict((H/'ordinary-io.luau').read_text(encoding='utf8').replace('require(script.Parent.RecoveryOperationAdmission)',operation)))+'\nend)()'
 original=r.requires(r.strict((ROOT/'roblox_port/src/Shared/Persistence/SaveSession.luau').read_text(encoding='utf8')))
 candidate=r.requires(r.strict((H/'ordinary-session.luau').read_text(encoding='utf8').replace('require(script.Parent.OrdinaryRequestAdmission)',io)))
 return r,original,candidate
def build(focused=False):
 base=load('ordinary_held',H/'run-held.py');bundle,inputs=base.build();r,before,after=replacement()
 assert bundle.count(before)==1;bundle=bundle.replace(before,after)
 def runtime(path):
  text=path.read_text(encoding='utf8')
  for name,var in {'RecoveryProgressBaselinePrototype':'__progressBaselinePrototype','RecoveryOfferReaderPrototype':'__offerReaderPrototype','RecoveryPipelinePrototype':'__pipelinePrototype',
   'RecoveryIdlePrototype':'__idlePrototype','RecoveryDeparturePrototype':'__departurePrototype','RecoveryReadLeasePrototype':'__readLeasePrototype'}.items():text=text.replace('require(script.Parent.'+name+')',var)
  return r.requires(r.strict(text))
 before=runtime(H/'runtime-held.luau');assert bundle.count(before)==1;bundle=bundle.replace(before,runtime(H/'runtime-ordinary.luau'))
 gate='(function()\n'+(H/'worker-admission.luau').read_text(encoding='utf8')+'\nend)()'
 tests=(H/'ordinary-tests.luau').read_text(encoding='utf8').replace('__ordinaryGate',gate)
 source=ROOT/'docs/save-slot-isolation/recovery-save-loop-tests.luau';profile=source.read_text(encoding='utf8').split('for _,mode in Rules.MODES do',1)[0]
 profile=profile.replace('runSaveLoopChecks','runOrdinaryRuntimeChecks',1)
 marker='local clock={now=200};local stored,refused=0,0';assert profile.count(marker)==1
 profile=profile.replace(marker,marker+'''
 local gate=Gate.new({now=function() return clock.now end,available=function() return {read=1000,write=1000} end,actorRead=160,actorWrite=160,serverRead=320,serverWrite=320,headroom=0})
 local scope=assert(gate:open("46001","routine-"..mode));assert(gate:importLegacy(scope,{}));local lane={gate=gate,scope=scope}
''')
 marker='local function runOrdinaryRuntimeChecks()';assert profile.count(marker)==1;profile=profile.replace(marker,marker+'\nlocal Gate='+gate)
 profile=profile.replace('onStored=function() stored+=1 end,','admission=lane,onStored=function() stored+=1 end,',1)
 profile=profile.replace('context=context,stored=function()', 'context=context,gate=gate,scope=scope,lane=lane,stored=function()',1)
 profile=profile.replace('check(#f.s.sched.started<=Rules.REQUESTS_PER_MINUTE,','check(f.lane~=nil or #f.s.sched.started<=Rules.REQUESTS_PER_MINUTE,',1)
 profile+=(H/'ordinary-runtime-tests.luau').read_text(encoding='utf8')
 assert bundle.endswith('end\n');bundle=bundle[:-4]+'\n;(function()\n'+r.requires(tests)+'\nend)()\n'+r.requires(profile)+'\nend\n'
 if focused:bundle=re.sub(r'\n(run\w+Checks)\(\)\nend',lambda m:'\n-- focused: skip '+m[1]+'\nend' if m[1]!='runOrdinaryRuntimeChecks' else m[0],bundle)
 return bundle,list(dict.fromkeys(inputs+[source,H/'ordinary-session.luau',H/'ordinary-io.luau',H/'runtime-ordinary.luau',H/'ordinary-tests.luau',H/'ordinary-runtime-tests.luau']))
def main():
 prefix=sys.argv[1];assert re.fullmatch('[a-z][a-z0-9-]*',prefix);out=H/(prefix+'-output.txt');assert not out.exists()
 focused='--focused' in sys.argv;bundle,paths=build(focused);sha=lambda b:hashlib.sha256(b).hexdigest()
 inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths};started=time.time()
 with tempfile.TemporaryDirectory(prefix='windowsill-ordinary-') as tmp:
  p=Path(tmp)/'run.luau';p.write_text(bundle,encoding='utf8',newline='\n')
  result=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(p)],cwd=ROOT,capture_output=True,text=True)
 assert inputs=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 output=result.stdout+result.stderr;out.write_text(output,encoding='utf8',newline='\n')
 if result.returncode:(H/(prefix+'-bundle.luau')).write_text(bundle,encoding='utf8',newline='\n')
 receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),inputs=inputs,
  bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),exit_code=result.returncode,elapsed_seconds=time.time()-started,focused=focused,
  ordinary_Session_typed=True,service_lanes_installed=False,provider='memory',clock='synthetic',normal_startup_installed=False,native_verified=False,online_verified=False,published=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
if __name__=='__main__':main()
