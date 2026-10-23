"""Differential admission trace against the preserved pre-optimization candidate."""
from pathlib import Path
import hashlib,json,subprocess,tempfile,sys
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
TOOLS=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau')
def build():
 paths=[H/'workers-before-ledger-admission.luau',H/'worker-admission.luau',H/'ledger-tests.luau']
 bundle='local Old=(function()\n'+paths[0].read_text()+'\nend)()\nlocal Next=(function()\n'+paths[1].read_text()+'\nend)()\n'+paths[2].read_text()
 return bundle,paths
def main():
 prefix=sys.argv[1];out=H/(prefix+'-output.txt');assert not out.exists()
 bundle,paths=build();sha=lambda b:hashlib.sha256(b).hexdigest()
 with tempfile.TemporaryDirectory(prefix='windowsill-ledger-') as tmp:
  path=Path(tmp)/'run.luau';path.write_text(bundle,encoding='utf8',newline='\n')
  r=subprocess.run([str(TOOLS/'luau.exe'),str(path)],cwd=ROOT,capture_output=True,text=True)
 text=r.stdout+r.stderr;out.write_text(text,encoding='utf8',newline='\n')
 receipt=dict(inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths},bundle_sha256=sha(bundle.encode()),output_sha256=sha(text.encode()),exit_code=r.returncode,clock='synthetic',native_verified=False)
 (H/(prefix+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(text);raise SystemExit(r.returncode)
if __name__=='__main__':main()
