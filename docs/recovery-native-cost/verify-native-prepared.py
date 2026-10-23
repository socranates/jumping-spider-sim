"""Independently inspect every model Source before the unpublished Studio run."""
from pathlib import Path
import argparse,ast,hashlib,io,json,subprocess,tarfile,xml.etree.ElementTree as ET
H=Path(__file__).resolve().parent;ROOT=H.parents[1];P=ROOT/'docs/save-slot-isolation'
SOURCE='bd67582b5d53473f067244fc1e2e1f94adde173b';sha=lambda b:hashlib.sha256(b).hexdigest()
parser=argparse.ArgumentParser();parser.add_argument('--out',required=True);parser.add_argument('--receipt',required=True)
parser.add_argument('--client-source',default='native-client.luau',help='Explicit preserved diagnostic source for a historical attempt')
parser.add_argument('--check',action='store_true',help='Recheck an existing receipt without rewriting it')
parser.add_argument('--server-source',default='native-server.server.luau')
a=parser.parse_args()
out=Path(a.out).resolve();manifest=json.loads((out/'manifest.json').read_text())
place=out/'Windowsill-native-new-application.rbxlx';assert manifest['source']==SOURCE and sha(place.read_bytes())==manifest['place_sha256']
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
def target(rel):
 p=list(Path(rel).parts);leaf=p[-1][:-5]
 for suffix in ['.server','.client']:
  if leaf.endswith(suffix):leaf=leaf[:-len(suffix)]
 return '.'.join([prefix[p[0]],*p[1:-1],leaf])
expected={};production={}
raw=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
 for member in archive:
  if not member.isfile() or not member.name.endswith('.luau'):continue
  name=Path(member.name).relative_to('roblox_port/src').as_posix();data=archive.extractfile(member).read().replace(b'\r\n',b'\n')
  production[target(name)]=data;expected[target(name)]=data
assert len(production)==224
tree=ast.parse((P/'check-recovery-pipeline.py').read_text())
names=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='names' for t in n.targets))
for name in ['check-recovery-game-entry.py','check-recovery-profile-owner.py']:
 for n in ast.parse((P/name).read_text()).body:
  if isinstance(n,ast.Assign) and isinstance(n.targets[0],ast.Subscript) and isinstance(n.targets[0].value,ast.Name) and n.targets[0].value.id=='names':names[ast.literal_eval(n.targets[0].slice)]=ast.literal_eval(n.value)
names.update({'Shared/Persistence/ReplacementProtocolPrototype.luau':'replacement-protocol-prototype.luau','Server/ReplacementOwnerPrototype.luau':'replacement-owner-prototype.luau','Server/ReplacementServicePrototype.luau':'replacement-service-prototype.luau','Client/ReplacementClientPrototype.luau':'replacement-client-prototype.luau'})
paths={key:P/value for key,value in names.items()};paths['Server/RecoveryNewLifePolicyPrototype.luau']=ROOT/'docs/new-life-policy/new-life-policy-prototype.luau'
assert len(paths)==41 and manifest['private_candidates']=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in paths.values()}
for name,path in paths.items():expected[target(name)]=path.read_bytes().replace(b'\r\n',b'\n')
client_source=(H/a.client_source).resolve();assert client_source.parent==H
server_source=(H/a.server_source).resolve();assert server_source.parent==H
diagnostics={'Client/SilkPlayback.luau':client_source,'Server/NewApplicationNative.server.luau':server_source}
for name,path in diagnostics.items():expected[target(name)]=path.read_bytes().replace(b'\r\n',b'\n')
assert manifest['diagnostic_inputs']=={'docs/recovery-native-cost/native-client.luau':sha(client_source.read_bytes()),'docs/recovery-native-cost/native-server.server.luau':sha((server_source).read_bytes())}
actual={};disabled=[]
def walk(item,parent=''):
 props=item.find('Properties');name=props.findtext("string[@name='Name']");path=parent+'.'+name if parent else name
 code=props.find("*[@name='Source']")
 if code is not None:actual[path]=(code.text or '').replace('\r\n','\n').encode()
 if item.attrib['class'] in ['Script','LocalScript']:disabled.append([path,props.findtext("bool[@name='Disabled']")=='true'])
 for child in item.findall('Item'):walk(child,path)
for item in ET.parse(place).getroot().findall('Item'):walk(item)
assert actual==expected and len(actual)==265 and disabled==manifest['disabled_scripts']
assert sum(flag for _,flag in disabled)==1 and ['ServerScriptService.Server.Persistence',True] in disabled
assert sum(name in production and production[name]==data for name,data in actual.items())==222
assert {r['path']:r['sha256'] for r in manifest['scripts']}=={name:sha(value) for name,value in expected.items()}
assert (out/'compile.txt').read_text()=='compile 265/265\n'
for step in manifest['static_steps']:assert step['exit_code']==0 and sha((out/(step['name']+'.txt')).read_bytes())==step['sha256']
strict=(out/'strict.txt').read_text();assert not [line for line in strict.splitlines() if line and not line.startswith('[INFO]') and 'didChangeWatchedFiles' not in line]
guard=(out/'guard.luau').read_bytes();assert sha(guard)==manifest['guard_sha256'] and b'game.PlaceId==0' in guard and b'n==265' in guard
server=(server_source).read_text();assert 'GetService("DataStoreService")' not in server and ':GetDataStore(' not in server
receipt=H/a.receipt;assert receipt.parent==H
result=dict(source=SOURCE,place=str(place),place_sha256=sha(place.read_bytes()),manifest_sha256=sha((out/'manifest.json').read_bytes()),guard_sha256=sha(guard),
 scripts=265,production_untouched=222,private_candidates=41,production_overrides=['WorldMap','Checkpoint'],diagnostics=manifest['diagnostic_inputs'],production_persistence_disabled=True,memory_store=True,engine_codec=True,clock_scale=10,executed=False,native_verified=False,online_verified=False,published=False)
if a.check:assert json.loads(receipt.read_text())==result,'Prepared receipt no longer matches sources/model'
else:
 assert not receipt.exists(),'Preserve earlier prepared evidence'
 receipt.write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(result,indent=2))
