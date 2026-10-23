"""Actual New menus with negotiated private policy and the full recovery cohort."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess,sys,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def build(focused=False):
 prior=load('new_policy_application_base',ROOT/'docs/new-life-policy/run.py');runner=load('new_application_runner',ROOT/'roblox_port/tests/run.py')
 bundle,inputs=prior.build();assert bundle.endswith('end\n');bundle=bundle[:-4]
 source=ROOT/'docs/recovery-application/application-tests.luau';body=source.read_text(encoding='utf8')
 prefix=body.split('drive(function() return client:recoveryReady()',1)[0];assert prefix!=body and prefix.endswith('end\n')
 prefix=prefix.replace('runApplicationGameChecks','runNewApplicationChecks',1)
 prefix=prefix.replace('local remoteFolder=Instance.new("Folder")','local staleRemote=game:GetService("ReplicatedStorage"):FindFirstChild(Rules.REMOTES_NAME);if staleRemote then staleRemote:Destroy() end\nlocal remoteFolder=Instance.new("Folder")',1)
 prefix=prefix.replace('if client.transition and client.transition.stage=="failed" then break end','if app.phase=="failed" or client.transition and client.transition.stage=="failed" then break end',1)
 prefix=prefix.replace('..tostring(client:status()))','..tostring(client:status()).." new="..tostring(owners[#owners].newLifeRequest and owners[#owners].newLifeRequest.state).." problem="..tostring(owners[#owners].newLifeRequest and owners[#owners].newLifeRequest.problem).." phase="..tostring(owners[#owners].newLifeJob and owners[#owners].newLifeJob.phase))',1)
 prefix=prefix.replace(' ownerFactory=function(config,emit)',' newLifeFactory={new=function(rt) return __newLifePolicy.new(rt,{work={now=function() return 0 end}}) end},\n ownerFactory=function(config,emit)',1)
 test=H/'tests.luau';fault=H/'failure-tests.luau'
 bundle+=runner.requires(prefix+test.read_text(encoding='utf8'))+'\n'
 bundle+=runner.requires(prefix.replace('runNewApplicationChecks','runNewApplicationFailureChecks',1)+fault.read_text(encoding='utf8'))+'\nend\n'
 if focused:bundle=re.sub(r'\n(run\w+Checks)\(\)\nend',lambda m:'\n-- focused: skip '+m[1]+'\nend' if m[1] not in {'runNewApplicationChecks','runNewApplicationFailureChecks'} else m[0],bundle)
 return bundle,list(dict.fromkeys(inputs+[source,test,fault]))
def main():
 prefix=sys.argv[1];assert prefix.replace('-','').isalnum();focused='--focused' in sys.argv[2:]
 out=H/(prefix+'-output.txt');assert not out.exists(),'Preserve prior evidence'
 bundle,inputs=build(focused);sha=lambda b:hashlib.sha256(b).hexdigest()
 hashes={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in inputs}
 production={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for folder in ['roblox_port/src','roblox_port/tests'] for p in (ROOT/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts}
 with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(bundle);path=Path(f.name)
 try:result=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(path)],capture_output=True,text=True)
 finally:path.unlink(missing_ok=True)
 assert hashes=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in inputs}
 assert production=={p:sha((ROOT/p).read_bytes()) for p in production}
 output=result.stdout+result.stderr;out.write_text(output,encoding='utf8',newline='\n')
 r=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),source_uncommitted=subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode!=0,focused=focused,exit_code=result.returncode,inputs=hashes,production_inputs=production,bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),native_verified=False,real_datastore_verified=False,published=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(output,flush=True);raise SystemExit(result.returncode)
if __name__=='__main__':main()
