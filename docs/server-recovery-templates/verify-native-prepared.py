"""Verify production and both diagnostics before opening the unbound model."""
from pathlib import Path
import hashlib, io, json, subprocess, tarfile, xml.etree.ElementTree as ET
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
SOURCE='46c299f5e36038d06f164c968e5fda78bb4407e8'
OUT=Path(r'C:/Users/natha/claude-xfer/Windowsill-native-template-46c299f-full')
sha=lambda b:hashlib.sha256(b).hexdigest()
manifest=json.loads((OUT/'manifest.json').read_text(encoding='utf8'))
place=OUT/'Windowsill-template-review.rbxlx'
assert manifest['source']==SOURCE and manifest['persistence_disabled'] and sha(place.read_bytes())==manifest['place_sha256']
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
  parts=list(Path(item.name).relative_to('roblox_port/src').parts);leaf=parts[-1][:-5]
  for suffix in ['.client','.server']:
   if leaf.endswith(suffix):leaf=leaf[:-len(suffix)]
  expected['.'.join([prefix[parts[0]],*parts[1:-1],leaf])]=archive.extractfile(item).read().replace(b'\r\n',b'\n')
assert len(expected)==223
for path,file in [('StarterPlayer.StarterPlayerScripts.Client.SilkPlayback','native-client.luau'),('ServerScriptService.Server.TemplateNative','native-server.server.luau')]:
 expected[path]=(H/file).read_bytes().replace(b'\r\n',b'\n')
assert len(actual)==225 and actual==expected and disabled
assert {row['path']:row['sha256'] for row in manifest['scripts']}=={name:sha(data) for name,data in expected.items()}
guard=(OUT/'guard.luau').read_bytes();assert b'game.PlaceId==0' in guard and b'Persistence.Disabled==true' in guard
result=dict(source=SOURCE,path=str(place),model_sha256=sha(place.read_bytes()),manifest_sha256=sha((OUT/'manifest.json').read_bytes()),
 guard_sha256=sha(guard),client_probe_sha256=sha((H/'native-client.luau').read_bytes()),server_probe_sha256=sha((H/'native-server.server.luau').read_bytes()),
 scripts=225,production_scripts_exact=223,persistence_disabled=True,executed=False,native_verified=False,real_datastore_verified=False,published=False)
(H/'native-prepared.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(result,indent=2))
