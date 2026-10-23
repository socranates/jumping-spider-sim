"""Build an exact-source production candidate, with no injected diagnostic. Does not publish."""
from pathlib import Path
import hashlib,io,json,subprocess,tarfile,xml.etree.ElementTree as ET
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PORT=ROOT/'roblox_port'
SOURCE='2170f99e001c4c0a42e86454974f594820e86667'
verified=json.loads((H/'full-verification.json').read_text(encoding='utf8'))
assert verified['source']==SOURCE and verified['windows_failed']==verified['linux_failed']==0
assert verified['owner_factory_default_not_installed_in_engine']
assert b'ownerFactory' not in subprocess.check_output(['git','show',SOURCE+':roblox_port/src/Server/Persistence.server.luau'],cwd=ROOT)
raw=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src','roblox_port/default.project.json'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
 blobs={m.name:archive.extractfile(m).read() for m in archive if m.isfile()}
for name,data in blobs.items():assert (ROOT/name).read_bytes().replace(b'\r\n',b'\n')==data.replace(b'\r\n',b'\n'),name
out=Path(r'C:/Users/natha/claude-xfer/Windowsill-production-2170f99');out.mkdir(exist_ok=False)
place=out/'TheWindowsill-production-candidate.rbxlx'
subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/rojo/rojo.exe','build','default.project.json','-o',str(place)],cwd=PORT,check=True)
actual={};xml=ET.parse(place)
def walk(item,parent=''):
 props=item.find('Properties');name=props.findtext("string[@name='Name']");path=parent+'.'+name if parent else name
 assert name!='SilkPlayback','A diagnostic was injected'
 code=props.find("*[@name='Source']")
 if code is not None:actual[path]=(code.text or '').replace('\r\n','\n').encode()
 if path=='ServerScriptService.Server.Persistence':assert props.findtext("bool[@name='Disabled']")!='true'
 for child in item.findall('Item'):walk(child,path)
for item in xml.getroot().findall('Item'):walk(item)
expected={};prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
for name,data in blobs.items():
 if not name.endswith('.luau'):continue
 rel=Path(name).relative_to('roblox_port/src');parts=list(rel.parts);leaf=parts[-1][:-5]
 for suffix in ['.client','.server']:
  if leaf.endswith(suffix):leaf=leaf[:-len(suffix)]
 path='.'.join([prefix[parts[0]],*parts[1:-1],leaf]);expected[path]=data.replace(b'\r\n',b'\n')
assert len(actual)==len(expected)==222 and actual==expected
manifest=dict(source=SOURCE,place=str(place),place_sha256=hashlib.sha256(place.read_bytes()).hexdigest(),scripts=222,all_production_sources_exact=True,injected_diagnostics=False,persistence_disabled=False,verified_platform_suites=76,verified_platform_checks=468506,native_current_source_verified=False,owner_factory_installed=False,full_release_audit_complete=False,published=False)
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n');(H/'production-candidate.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(manifest,indent=2))
