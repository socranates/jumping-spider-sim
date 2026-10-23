"""Reproduce each pre-fix Profile admission bypass with identical assertions."""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,sys,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
def build(case):
 s=importlib.util.spec_from_file_location('profile_counterexample_runner',H/'run-profile.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
 assert case in ['profile','lease','new'];return m.build(True,case)
def main():
 case=sys.argv[1];prefix=sys.argv[2];out=H/(prefix+'-output.txt');assert not out.exists()
 expected={'profile':'profile discovery started storage without capacity','lease':'profile switch lease started storage without capacity','new':'New factory did not inherit account lane'}[case]
 bundle,paths=build(case);inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 with tempfile.TemporaryDirectory(prefix='windowsill-profile-negative-') as tmp:
  p=Path(tmp)/'run.luau';p.write_text(bundle,encoding='utf8',newline='\n')
  r=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(p)],cwd=ROOT,capture_output=True,text=True)
 assert inputs=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 output=r.stdout+r.stderr;out.write_text(output,encoding='utf8',newline='\n')
 receipt=dict(case=case,inputs=inputs,bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),exit_code=r.returncode,
  expected_failure=expected,only_mutation={'profile':'Restore original Profile module','lease':'Remove fourth lane argument only from profile switch lease construction','new':'Restore preceding New policy constructor without inherited account lane'}[case],native_verified=False,published=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
 print(output[-1800:]);assert r.returncode!=0 and expected in output;print('EXPECTED PROFILE BYPASS CONFIRMED',case)
if __name__=='__main__':main()
