"""Independently bind every prepared model Source and disabled flag to inputs."""
from pathlib import Path
import argparse,hashlib,importlib.util,io,json,subprocess,tarfile,xml.etree.ElementTree as ET
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--receipt',required=True);p.add_argument('--check',action='store_true');a=p.parse_args()
out=a.out.resolve();manifest=json.loads((out/'manifest.json').read_text(encoding='utf8'));source='bd67582b5d53473f067244fc1e2e1f94adde173b'
assert manifest['source']==source and manifest['clock_scale']==1 and not manifest['executed'] and not manifest['published']
place=out/'Windowsill-online-service.rbxlx';assert sha(place.read_bytes())==manifest['place_sha256']
def target(rel):
 parts=list(Path(rel).parts);leaf=parts[-1][:-5]
 for suffix in ['.server','.client']:
  if leaf.endswith(suffix):leaf=leaf[:-len(suffix)]
 prefixes={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
 return '.'.join([prefixes[parts[0]],*parts[1:-1],leaf])
expected={};production={}
raw=subprocess.check_output(['git','archive','--format=tar',source,'roblox_port/src'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
 for member in archive:
  if not member.isfile() or not member.name.endswith('.luau'):continue
  rel=Path(member.name).relative_to('roblox_port/src').as_posix();data=archive.extractfile(member).read().replace(b'\r\n',b'\n')
  production[rel]=data;expected[target(rel)]=data
spec=importlib.util.spec_from_file_location('verify_service_paths',H/'check-service.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);paths=m.checker().paths()
assert len(paths)==51 and len(set(paths.values()))==50
subprocess.run([__import__('sys').executable,str(H/'qualify-native-callback.py'),'--check'],check=True)
qualified=json.loads((H/'native-callback-types-1-types.json').read_text(encoding='utf8'))
for rel,path in paths.items():
 code=path.read_text(encoding='utf8')
 if path.name in ['worker-v3.luau','operation.luau']:
  assert code.count('require("./worker-facade")')==1;code=code.replace('require("./worker-facade")','require(script.Parent.RequestAdmissionFacade)')
 assert sha(code.encode())==qualified['mounted'][rel]
 row=manifest['private_targets'][rel]
 assert row==dict(path=path.relative_to(ROOT).as_posix(),source_sha256=sha(path.read_bytes()),mounted_sha256=sha(code.encode()))
 expected[target(rel)]=code.encode()
diags={'Client/SilkPlayback.luau':H/'online-service-client.luau','Server/NewApplicationNative.server.luau':H/'online-service-server.server.luau'}
assert manifest['diagnostic_inputs']=={path.relative_to(ROOT).as_posix():sha(path.read_bytes()) for path in diags.values()}
for rel,path in diags.items():expected[target(rel)]=path.read_bytes().replace(b'\r\n',b'\n')
actual={};disabled=[]
def walk(item,parent=''):
 props=item.find('Properties');name=props.findtext("string[@name='Name']");path=parent+'.'+name if parent else name
 code=props.find("*[@name='Source']")
 if code is not None:actual[path]=(code.text or '').replace('\r\n','\n').encode()
 if item.attrib['class'] in ['Script','LocalScript']:disabled.append([path,props.findtext("bool[@name='Disabled']")=='true'])
 for child in item.findall('Item'):walk(child,path)
for item in ET.parse(place).getroot().findall('Item'):walk(item)
assert actual==expected and len(actual)==manifest['script_count']
assert {row['path']:row['sha256'] for row in manifest['scripts']}=={name:sha(data) for name,data in actual.items()}
assert disabled==manifest['disabled_scripts'] and sum(flag for _,flag in disabled)==1 and ['ServerScriptService.Server.Persistence',True] in disabled
overrides=sorted(rel for rel in paths if rel in production);assert overrides==manifest['production_overrides']
untouched=sum(actual[target(rel)]==data for rel,data in production.items());assert untouched==manifest['untouched_production']
assert (out/'compile.txt').read_text(encoding='utf8')==f'compile {len(actual)}/{len(actual)}\n'
for step in manifest['static_steps']:assert step['exit_code']==0 and sha((out/(step['name']+'.txt')).read_bytes())==step['sha256']
guard=(out/'guard.luau').read_bytes();assert sha(guard)==manifest['guard_sha256'] and b'game.GameId==10771634917 and game.PlaceId==109879630247781' in guard and f'n=={len(actual)}'.encode() in guard
server=(H/'online-service-server.server.luau').read_text(encoding='utf8')
assert server.count(':GetDataStore(')==1 and 'DataStores:GetDataStore("WindowsillTest_v1")' in server
assert 'assert(allowedKeys[key]' in server and 'game.GameId==10771634917 and game.PlaceId==109879630247781' in server
project=json.loads((out/'native.project.json').read_text(encoding='utf8'))
assert project['placeId']==109879630247781 and project['gameId']==10771634917 and project['servePlaceIds']==[0,109879630247781]
assert project['tree']['ServerScriptService']['Server']['Persistence']['$properties']['Disabled'] is True
result=dict(source=source,place=str(place),place_sha256=sha(place.read_bytes()),manifest_sha256=sha((out/'manifest.json').read_bytes()),guard_sha256=sha(guard),scripts=len(actual),production_untouched=untouched,private_targets=len(paths),production_overrides=overrides,diagnostics=manifest['diagnostic_inputs'],production_persistence_disabled=True,memory_store=False,engine_codec=True,clock_scale=1,executed=False,native_verified=False,online_verified=False,published=False,universe=10771634917,place_id=109879630247781)
receipt=H/a.receipt;assert receipt.parent==H
if a.check:assert json.loads(receipt.read_text(encoding='utf8'))==result
else:
 assert not receipt.exists();receipt.write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(result,indent=2))
