"""Controlled service-hook, dispatch and cancelled-import counterexamples."""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,sys,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
CASES={
 'load-hook':('if target.cancelLoading then target:cancelLoading() end','', 'removed deferred load started storage'),
 'dispatch':(' and not entry.working','', 'service queued duplicate per-actor workers'),
 'import':('if v.seeding then v.cancelled=true else finish(self,v,false,"constructor cancelled") end','finish(self,v,false,"constructor cancelled")','cancelled seed lost complete known debt or built an owner')}
def build(case):
 s=importlib.util.spec_from_file_location('service_counterexample',H/'run-service.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
 bundle,paths=m.build(True);before,after,_=CASES[case];assert bundle.count(before)==1
 return bundle.replace(before,after,1),paths
def main():
 case,prefix=sys.argv[1:3];out=H/(prefix+'-output.txt');assert not out.exists()
 bundle,paths=build(case);inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 with tempfile.TemporaryDirectory(prefix='windowsill-service-negative-') as tmp:
  p=Path(tmp)/'run.luau';p.write_text(bundle,encoding='utf8',newline='\n')
  r=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(p)],cwd=ROOT,capture_output=True,text=True)
 assert inputs=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 output=r.stdout+r.stderr;out.write_text(output,encoding='utf8',newline='\n');expected=CASES[case][2]
 receipt=dict(case=case,inputs=inputs,bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),exit_code=r.returncode,
  expected_failure=expected,only_mutation=dict(before=CASES[case][0],after=CASES[case][1]),native_verified=False,published=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
 print(output[-1700:]);assert r.returncode!=0 and expected in output;print('EXPECTED SERVICE FAILURE CONFIRMED',case)
if __name__=='__main__':main()
