"""Probe expiry of a retry load inside the polled ordinary driver."""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,sys,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
def build():
 s=importlib.util.spec_from_file_location('service_retry_timeout',H/'run-service.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
 bundle,paths=m.build(True);start=bundle.index('local function runAccountServiceChecks()')
 a=bundle.index('test("initial-owner-and-normal-removal-use-one-account-lane"',start);b=bundle.index('print("ACCOUNT_SERVICE passed="',a)
 probe=H/'service-retry-timeout-test.luau'
 return bundle[:a]+probe.read_text(encoding='utf8')+'\n'+bundle[b:],list(dict.fromkeys(paths+[probe]))
def main():
 prefix=sys.argv[1];out=H/(prefix+'-output.txt');assert not out.exists();bundle,paths=build();inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 with tempfile.TemporaryDirectory(prefix='windowsill-service-retry-timeout-') as tmp:
  p=Path(tmp)/'run.luau';p.write_text(bundle,encoding='utf8',newline='\n')
  r=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(p)],cwd=ROOT,capture_output=True,text=True)
 assert inputs=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths}
 output=r.stdout+r.stderr;out.write_text(output,encoding='utf8',newline='\n')
 receipt=dict(inputs=inputs,bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),exit_code=r.returncode,
  issue_fixed=r.returncode==0,expected_failure='polled admission timeout left retry loading without retry',native_verified=False,published=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output[-1800:]);raise SystemExit(r.returncode)
if __name__=='__main__':main()
