"""Bind the overlay type check to immutable production and private source bytes."""
from pathlib import Path
import hashlib,io,json,subprocess,sys,tarfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
sha=lambda b:hashlib.sha256(b).hexdigest()
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
assert not (H/'private-type-inputs.json').exists(),'Preserve prior evidence'
raw=subprocess.check_output(['git','archive','--format=tar',source,'roblox_port/src','roblox_port/default.project.json'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
 blobs={m.name:archive.extractfile(m).read().replace(b'\r\n',b'\n') for m in archive if m.isfile()}
for name,data in blobs.items():assert (ROOT/name).read_bytes().replace(b'\r\n',b'\n')==data,name
result=subprocess.run([sys.executable,str(ROOT/'docs/save-slot-isolation/check-recovery-service-owner.py'),'capability-types-2'],cwd=ROOT)
for name,data in blobs.items():assert (ROOT/name).read_bytes().replace(b'\r\n',b'\n')==data,name
assert result.returncode==0
receipt=dict(source=source,production_inputs={name:sha(data) for name,data in blobs.items()},
 private_types='docs/save-slot-isolation/capability-types-2-types.json',real_datastore_verified=False,native_verified=False,published=False)
(H/'private-type-inputs.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print('Bound overlay analysis to',len(blobs),'production inputs at',source)
