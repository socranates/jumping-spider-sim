"""Activate the exact qualified source snapshot in this integration checkout."""
from pathlib import Path
import argparse,hashlib,io,json,subprocess,tarfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PORT=ROOT/'roblox_port'
p=argparse.ArgumentParser();p.add_argument('--candidate',type=Path,required=True);a=p.parse_args()
stage=a.candidate.resolve();manifest=json.loads((stage/'manifest.json').read_text())
sha=lambda b:hashlib.sha256(b).hexdigest()
assert manifest['place_sha256']=='64a3ff7e865ce53d401569e8e12605ddff419028ccfd887d518e03e2514b0a6b'
assert sha(Path(manifest['place']).read_bytes())==manifest['place_sha256']
assert manifest['source_count']==273 and not manifest['diagnostics']
branch=subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip()
assert branch=='codex/verified-integration','Use the separate integration checkout; do not mutate historical proof inputs'
files={f.relative_to(stage/'roblox_port/src').as_posix():f.read_bytes()for f in (stage/'roblox_port/src').rglob('*.luau')}
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
def name(rel):
 parts=Path(rel).parts
 return '.'.join([prefix[parts[0]],*parts[1:-1],parts[-1][:-5].removesuffix('.server').removesuffix('.client')])
assert {name(k):sha(v.replace(b'\r\n',b'\n'))for k,v in files.items()}==manifest['sources']
raw=subprocess.check_output(['git','archive','--format=tar','bd67582b5d53473f067244fc1e2e1f94adde173b','roblox_port/src'],cwd=ROOT)
base={}
with tarfile.open(fileobj=io.BytesIO(raw))as archive:
 for member in archive:
  if member.isfile()and member.name.endswith('.luau'):
   base[Path(member.name).relative_to('roblox_port/src').as_posix()]=archive.extractfile(member).read()
current={f.relative_to(PORT/'src').as_posix():f.read_bytes()for f in (PORT/'src').rglob('*.luau')}
normalize=lambda rows:{k:v.replace(b'\r\n',b'\n')for k,v in rows.items()}
assert len(base)==224 and normalize(current)==normalize(base),'Refuse overwriting a changed normal source tree'
assert set(base)<=set(files)
changed=[k for k,v in files.items()if k not in base or normalize({k:v})!=normalize({k:base[k]})]
for rel,data in files.items():
 path=PORT/'src'/rel;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
# Author the exact normal-game attributes used by the qualified clean model.
config_path=PORT/'default.project.json';config=json.loads(config_path.read_text())
config['tree']['Workspace']['$attributes']={'World':'preserve','SelfTest':False,'TestTarget':False,'SaveWait':True}
config_path.write_bytes((json.dumps(config,indent=2)+'\n').encode())
record=dict(candidate_model_sha256=manifest['place_sha256'],candidate_manifest_sha256=sha((stage/'manifest.json').read_bytes()),
 source_count=273,base_source_count=224,changed=sorted(changed),sources=manifest['sources'],
 branch=branch,normal_source_activated=True,published=False)
target=H/'promotion.json';assert not target.exists();target.write_bytes((json.dumps(record,indent=2)+'\n').encode())
assert normalize(files)==normalize({f.relative_to(PORT/'src').as_posix():f.read_bytes()for f in (PORT/'src').rglob('*.luau')})
print(json.dumps(dict(source_count=273,changed_files=len(changed),published=False)))
