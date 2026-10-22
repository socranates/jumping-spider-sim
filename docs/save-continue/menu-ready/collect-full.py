from pathlib import Path
import hashlib,io,json,re,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
SOURCE='ac898f40e84916ce0862214eb607cbbfba14034d'
p=HERE/'windows-full-process.json';assert p.exists(),'poll exec63820; only its terminal process writes this receipt'
v=json.loads(p.read_text());assert v['source']==SOURCE and v['exit_code']==0
raw=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src','roblox_port/tests'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as tree:files={t.name:tree.extractfile(t).read() for t in tree if t.isfile()}
sha=lambda b:hashlib.sha256(b).hexdigest()
for name,digest in v['inputs'].items():assert sha(files[name])==digest,name
b=(HERE/'windows-full.txt').read_bytes();rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',b.decode(),re.M)
assert len(rows)==69 and sum(int(r[1]) for r in rows)==444367 and all(int(r[2])==0 for r in rows)
r=dict(source=SOURCE,suites=69,passed=444367,failed=0,exit_code=0,elapsed_seconds=v['elapsed_seconds'],log_sha256=sha(b),inputs_verified=True,native=False,published=False,scope='Windows CLI full gate for menu integration predecessor ac898f4 only; newer cost-reduction source is separate')
(HERE/'windows-full-receipt.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
