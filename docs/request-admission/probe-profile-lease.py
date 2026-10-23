"""Expose a missing typed switch-lease lane after old aggregate debt ages out."""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,sys,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
def build(before):
 s=importlib.util.spec_from_file_location('profile_lease_masked_probe',H/'run-profile.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
 bundle,paths=m.build(True,'lease' if before else None)
 old='for _=1,16 do f.tick();check(f.b.requests==before,"profile switch lease started storage without capacity") end'
 assert bundle.count(old)==1
 # Both implementations run the identical70-second observation. The original
 #16-second case sees old aggregate throttling before it reaches its lane check.
 return bundle.replace(old,old.replace('1,16','1,70'),1),paths
def main():
 before=sys.argv[1]=='before';assert sys.argv[1] in ['before','fixed'];prefix=sys.argv[2];out=H/(prefix+'-output.txt');assert not out.exists()
 bundle,paths=build(before);inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 with tempfile.TemporaryDirectory(prefix='windowsill-profile-lease-probe-') as tmp:
  p=Path(tmp)/'run.luau';p.write_text(bundle,encoding='utf8',newline='\n')
  r=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(p)],cwd=ROOT,capture_output=True,text=True)
 assert inputs=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 output=r.stdout+r.stderr;out.write_text(output,encoding='utf8',newline='\n')
 expected='profile switch lease started storage without capacity'
 receipt=dict(before_fix=before,observation_seconds=70,inputs=inputs,bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),exit_code=r.returncode,
  expected_failure=expected if before else None,test_change='Same70-second capacity denial in both variants, allowing prior aggregate history to age naturally',
  implementation_change='Remove fourth lane argument only from switch lease construction' if before else None,native_verified=False,published=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
 print(output[-2000:])
 if before:assert r.returncode!=0 and expected in output
 else:assert r.returncode==0 and 'PROFILE_ADMISSION passed=4280 failed=0 groups=10' in output
 print('PROFILE LEASE LONG-WAIT PROOF',sys.argv[1])
if __name__=='__main__':main()
