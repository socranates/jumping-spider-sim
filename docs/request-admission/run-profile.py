"""Actual all-slot Profile admission over the qualified ordinary cohort."""
from pathlib import Path
import hashlib, importlib.util, json, re, subprocess, sys, tempfile, time
H=Path(__file__).resolve().parent;ROOT=H.parents[1]

def load(name,path):
 s=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m

def build(focused=False,baseline=None):
 old=load('profile_ordinary',H/'run-ordinary.py');bundle,paths=old.build();r,_,_=old.replacement()
 options='(function()\n'+(H/'profile-options.luau').read_text(encoding='utf8')+'\nend)()'
 def code(path):
  text=path.read_text(encoding='utf8').replace('require(script.Parent.RecoveryProfileAdmissionOptions)',options)
  for name,var in {'RecoveryServiceOwnerPrototype':'__serviceOwnerPrototype','RecoveryPipelinePrototype':'__pipelinePrototype','RecoveryReadLeasePrototype':'__readLeasePrototype'}.items():
   text=text.replace('require(script.Parent.'+name+')',var)
  return r.requires(r.strict(text))
 original=ROOT/'docs/save-slot-isolation/recovery-profile-owner-prototype.luau'
 before=code(original);after=code(H/'profile-owner.luau');assert bundle.count(before)==1
 if baseline=='profile':after=before
 if baseline=='lease':
  marker='end, s.backend.held, s.ordinaryAdmission)';assert after.count(marker)==1;after=after.replace(marker,'end, s.backend.held)',1)
 bundle=bundle.replace(before,after)
 # New policy already exists in the ordinary bundle; replace its body using
 # the exact same dependency substitutions as the lifecycle runner.
 facade='(function()\n'+(H/'worker-facade.luau').read_text(encoding='utf8')+'\nend)()'
 op='(function()\n'+(H/'operation.luau').read_text(encoding='utf8').replace('require("./worker-facade")',facade)+'\nend)()'
 def policy(path):
  text=path.read_text(encoding='utf8')
  for name,var in {'RecoverySessionFencePrototype':'__sessionFence','RecoveryControllerPrototype':'__archiveControllerPrototype','RecoveryArchiveStorePrototype':'__archiveStorePrototype',
   'RecoveryOfferReaderPrototype':'__offerReaderPrototype','RecoveryReadLeasePrototype':'__readLeasePrototype','RecoveryRoutineProgressPrototype':'__routineProgressPrototype'}.items():
   text=text.replace('require(Shared.Persistence.'+name+')',var).replace('require(script.Parent.'+name+')',var)
  return r.requires(r.strict(text.replace('require(Shared.Persistence.RecoveryOperationAdmission)',op)))
 before=policy(H/'new-policy.luau');assert bundle.count(before)==1
 bundle=bundle.replace(before,before if baseline=='new' else policy(H/'new-policy-profile.luau'))
 fixture=ROOT/'docs/save-slot-isolation/recovery-profile-owner-tests.luau'
 text=fixture.read_text(encoding='utf8').split('-- All slots become visible',1)[0]
 assert text.endswith(' return f\nend\n')
 text=text.replace('runProfileOwnerChecks','runProfileAdmissionChecks',1)
 gate='(function()\n'+(H/'worker-admission.luau').read_text(encoding='utf8')+'\nend)()'
 text=text.replace('local count=0','local Gate='+gate+'\nlocal count=0',1)
 marker=' local owner=__profileOwnerPrototype.new(';assert text.count(marker)==1
 text=text.replace(marker,''' f.budget={read=1000,write=1000}
 f.g=Gate.new({now=function() return clock.now end,available=function() return f.budget end,actorRead=160,actorWrite=160,serverRead=320,serverWrite=320,headroom=0})
 f.scope=assert(f.g:open("46001","profiles-A"));assert(f.g:importLegacy(f.scope,{}));f.lane={gate=f.g,scope=f.scope}
 f.common=common
 if options.configureCommon then options.configureCommon(common,f) end
'''+marker,1)
 marker='sessionId="profiles-A",now=';assert text.count(marker)==1;text=text.replace(marker,'sessionId="profiles-A",admission=f.lane,now=',1)
 marker=' f.owner=owner;f.s=owner.session;f.rt=owner.runtime';assert text.count(marker)==1
 text=text.replace(marker,marker+'\n if options.newLifeFactory then owner:installNewLifeFactory(options.newLifeFactory) end',1)
 text=text.replace('check(#f.s.sched.started<=Rules.REQUESTS_PER_MINUTE,','check(f.lane~=nil or #f.s.sched.started<=Rules.REQUESTS_PER_MINUTE,',1)
 marker='  check(not owner.busy and not f.rt.busy and not f.s.busy,"profile worker retained busy lock")';assert text.count(marker)==1
 text=text.replace(marker,marker+'\n  check(f.s.counters.requests==b.requests,"profile/session provider accounting differs")',1)
 text+=(H/'profile-tests.luau').read_text(encoding='utf8')
 assert bundle.endswith('end\n');bundle=bundle[:-4]+'\n'+r.requires(text)+'\nend\n'
 if focused:bundle=re.sub(r'\n(run\w+Checks)\(\)\nend',lambda m:'\n-- focused: skip '+m[1]+'\nend' if m[1]!='runProfileAdmissionChecks' else m[0],bundle)
 return bundle,list(dict.fromkeys(paths+[H/'profile-options.luau',H/'profile-owner.luau',H/'new-policy-profile.luau',fixture,H/'profile-tests.luau']))

def main():
 prefix=sys.argv[1];assert re.fullmatch('[a-z][a-z0-9-]*',prefix);out=H/(prefix+'-output.txt');assert not out.exists()
 focused='--focused' in sys.argv;bundle,paths=build(focused);sha=lambda b:hashlib.sha256(b).hexdigest();inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths};started=time.time()
 with tempfile.TemporaryDirectory(prefix='windowsill-profile-') as tmp:
  p=Path(tmp)/'run.luau';p.write_text(bundle,encoding='utf8',newline='\n')
  result=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(p)],cwd=ROOT,capture_output=True,text=True)
 assert inputs=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 output=result.stdout+result.stderr;out.write_text(output,encoding='utf8',newline='\n')
 if result.returncode:(H/(prefix+'-bundle.luau')).write_text(bundle,encoding='utf8',newline='\n')
 receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),inputs=inputs,
  bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),exit_code=result.returncode,elapsed_seconds=time.time()-started,focused=focused,
  profile_lane_from_constructor=True,service_lanes_installed=False,provider='memory',clock='synthetic',normal_startup_installed=False,native_verified=False,online_verified=False,published=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
if __name__=='__main__':main()
