"""Verify the prepared normal-client model; this is not an execution receipt."""
from pathlib import Path
import argparse,hashlib,io,json,subprocess,tarfile,xml.etree.ElementTree as ET
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
p=argparse.ArgumentParser();p.add_argument('--source',default='695e772d9d1ece490dd32132c655ac60c226c7b8');p.add_argument('--out',type=Path,default=Path(r'C:/Users/natha/claude-xfer/Windowsill-native-player-695e772-full'));p.add_argument('--probe',type=Path,default=H/'native-probe.luau');p.add_argument('--receipt',default='native-prepared.json');p.add_argument('--place-name',default='Windowsill-player-stream-review.rbxlx');a=p.parse_args()
SOURCE=a.source;OUT=a.out;assert Path(a.receipt).name==a.receipt
sha=lambda b:hashlib.sha256(b).hexdigest()
manifest=json.loads((OUT/'manifest.json').read_text(encoding='utf8'));assert manifest['source']==SOURCE and manifest['persistence_disabled']
assert Path(a.place_name).name==a.place_name
place=OUT/a.place_name;assert sha(place.read_bytes())==manifest['place_sha256']
actual={};disabled=False
def walk(item,parent=''):
 global disabled
 props=item.find('Properties');name=props.findtext("string[@name='Name']");path=parent+'.'+name if parent else name
 code=props.find("*[@name='Source']")
 if code is not None:actual[path]=(code.text or '').replace('\r\n','\n').encode()
 if path=='ServerScriptService.Server.Persistence':disabled=props.findtext("bool[@name='Disabled']")=='true'
 for child in item.findall('Item'):walk(child,path)
for item in ET.parse(place).getroot().findall('Item'):walk(item)
expected={};prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
raw=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
 for item in archive:
  if not item.isfile() or not item.name.endswith('.luau'):continue
  rel=Path(item.name).relative_to('roblox_port/src');parts=list(rel.parts);leaf=parts[-1][:-5]
  for suffix in ['.client','.server']:
   if leaf.endswith(suffix):leaf=leaf[:-len(suffix)]
  expected['.'.join([prefix[parts[0]],*parts[1:-1],leaf])]=archive.extractfile(item).read().replace(b'\r\n',b'\n')
assert len(expected)==222
probe='StarterPlayer.StarterPlayerScripts.Client.SilkPlayback'
probeBytes=a.probe.read_bytes().replace(b'\r\n',b'\n')
assert actual.pop(probe)==probeBytes and actual==expected and disabled
assert len(manifest['scripts'])==223 and {row['path']:row['sha256'] for row in manifest['scripts']}=={**{name:sha(data) for name,data in expected.items()},probe:sha(probeBytes)}
guard=(OUT/'guard.luau').read_text(encoding='utf8');assert 'game.PlaceId==0' in guard and 'Persistence.Disabled==true' in guard
result=dict(source=SOURCE,path=str(place),model_sha256=sha(place.read_bytes()),manifest_sha256=sha((OUT/'manifest.json').read_bytes()),
 guard_sha256=sha((OUT/'guard.luau').read_bytes()),probe_sha256=sha(probeBytes),scripts=223,production_scripts_exact=222,
 persistence_disabled=True,executed=False,native_verified=False,recovery_native_verified=False,real_datastore_verified=False,published=False)
(H/a.receipt).write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
