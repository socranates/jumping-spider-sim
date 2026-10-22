from pathlib import Path
import hashlib,io,json,re,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
SOURCE='ac898f40e84916ce0862214eb607cbbfba14034d'
p=HERE/'windows-full-process.json';assert p.exists(),'poll exec63820; only its terminal process writes this receipt'
v=json.loads(p.read_text());assert v['source']==SOURCE and v['exit_code']==1
raw=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src','roblox_port/tests'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as tree:files={t.name:tree.extractfile(t).read() for t in tree if t.isfile()}
sha=lambda b:hashlib.sha256(b).hexdigest()
for name,digest in v['inputs'].items():assert sha(files[name])==digest,name
b=(HERE/'windows-full.txt').read_bytes();rows=re.findall(r'^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)',b.decode(),re.M)
assert len(rows)==69 and sum(int(r[1]) for r in rows)==444365 and sum(int(r[2]) for r in rows)==2
assert [(name,p,f) for name,p,f in rows if f!="0"]==[("RARE","263","2")]
r=dict(source=SOURCE,suites=69,passed=444365,failed=2,exit_code=1,elapsed_seconds=v['elapsed_seconds'],log_sha256=sha(b),inputs_verified=True,native=False,published=False,scope='Failed Windows CLI full gate for ac898f4: only rare-history mock protocol failed; newer sources are separate')
(HERE/'windows-full-failed-receipt.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
