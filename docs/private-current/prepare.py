"""Freeze current CI-qualified sources and a new private-only read-only observer.
Creates local files only; no upload, publication or API/security settings change.
"""
from pathlib import Path
import argparse,hashlib,json,subprocess,xml.etree.ElementTree as ET,zlib
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PORT=ROOT/'roblox_port'
TOOLS=Path('C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
DEST=Path('C:/Users/natha/claude-xfer/Windowsill-private-current-20261024a1')
SOURCE_COMMIT='dd21210557990e0c0040b8028a714201de12e9d2'
STORE='WindowsillTest_playerRig_20261024a1'
sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
receipt=json.loads((PORT/'build-receipt.json').read_text())
qualified=json.loads((ROOT/'docs/rig-hair-cache/qualification.json').read_text())
ci=json.loads((ROOT/'docs/rig-hair-cache/github-ci.json').read_text())
assert receipt['evidence_id']==qualified['evidence_id']=='032b5985ac17eeb2'
assert qualified['full_ci_conclusion']==ci['run']['conclusion']=='success'
assert qualified['full_ci_suites']==80 and ci['run']['head_sha']==SOURCE_COMMIT
assert receipt==json.loads(subprocess.check_output(['git','show',SOURCE_COMMIT+':roblox_port/build-receipt.json'],cwd=ROOT))
normal=next(x for x in receipt['outputs']if x['file']=='TheWindowsill.rbxlx')
assert not normal['selftest']and sha((PORT/normal['file']).read_bytes())==normal['sha256']
expected={f.relative_to(PORT/'src').as_posix():f.read_bytes().replace(b'\r\n',b'\n')for f in (PORT/'src').rglob('*.luau')}
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
def item_name(rel):
 parts=Path(rel).parts
 return '.'.join([prefix[parts[0]],*parts[1:-1],parts[-1][:-5].removesuffix('.server').removesuffix('.client')])
assert len(expected)==273 and {item_name(k):sha(v)for k,v in expected.items()}==receipt['sources']
probe=(H/'player-probe.client.luau').read_bytes().replace(b'\r\n',b'\n')
for token in [b'SetAttribute',b'FireServer',b'InvokeServer',b'DataStoreService',b'TeleportService',b'Instance.new',b'HttpService:Request',b':CaptureTo',b':StartFileStream']:
 assert token not in probe,token
if a.check:
 m=json.loads((H/'prepared.json').read_text())
 assert sha(Path(m['place']).read_bytes())==m['place_sha256']
 assert sha((DEST/'guard.luau').read_bytes())==m['guard_sha256']
 assert sha((DEST/'setup.luau').read_bytes())==m['setup_sha256']
 assert m['source_commit']==SOURCE_COMMIT and m['readonly_probe_sha256']==sha(probe)
 for rel,data in expected.items():assert (DEST/'src'/rel).read_bytes()==data
 print('Prepared current private candidate reverified; no publication performed');raise SystemExit
assert not DEST.exists()and not(H/'prepared.json').exists();DEST.mkdir()
for rel,data in expected.items():
 f=DEST/'src'/rel;f.parent.mkdir(parents=True,exist_ok=True);f.write_bytes(data)
(DEST/'PlayerArrivalProbe.client.luau').write_bytes(probe)
project=json.loads((PORT/'default.project.json').read_text())
project.update(name='WindowsillPrivateCurrent',placeId=109879630247781,gameId=10771634917)
for role,node in [('Shared',project['tree']['ReplicatedStorage']['Shared']),('Client',project['tree']['StarterPlayer']['StarterPlayerScripts']['Client']),('Server',project['tree']['ServerScriptService']['Server'])]:node['$path']=str(DEST/'src'/role)
first={'$className':'ReplicatedFirst','$ignoreUnknownInstances':False}
for f in sorted((DEST/'src/First').glob('*.luau')):first[f.name.removesuffix('.luau').removesuffix('.client')]={'$path':str(f)}
first['PlayerArrivalProbe']={'$path':str(DEST/'PlayerArrivalProbe.client.luau')}
project['tree']['ReplicatedFirst']=first
project['tree']['ServerScriptService']['PortTests']={'$className':'Folder','$ignoreUnknownInstances':False}
attrs=project['tree']['Workspace']['$attributes']
assert attrs=={'World':'preserve','SelfTest':False,'TestTarget':False,'SaveWait':True}
assert len(STORE)<=40 and STORE.startswith('WindowsillTest_')
attrs.update(SaveStore=STORE,PortEvidence=receipt['evidence_id'])
config=DEST/'private-current.project.json';config.write_bytes((json.dumps(project,indent=2)+'\n').encode())
r=subprocess.run([str(TOOLS/'luau/luau-compile.exe'),'-O0','--null',str(DEST/'PlayerArrivalProbe.client.luau')],capture_output=True,text=True)
(H/'probe-compile.txt').write_bytes((r.stdout+r.stderr+f'compile exit {r.returncode}\n').encode());assert r.returncode==0
mapfile=DEST/'sourcemap.json'
subprocess.run([str(TOOLS/'rojo/rojo.exe'),'sourcemap',str(config),'--output',str(mapfile)],check=True,capture_output=True)
r=subprocess.run([str(TOOLS/'lsp/luau-lsp.exe'),'analyze','--sourcemap='+str(mapfile),'--definitions='+str(TOOLS/'globalTypes.d.luau'),'--no-strict-dm-types',str(DEST/'src'),str(DEST/'PlayerArrivalProbe.client.luau')],cwd=DEST,capture_output=True,text=True)
(H/'strict.txt').write_bytes((r.stdout+r.stderr).encode());print('strict',r.returncode,(r.stdout+r.stderr)[:1800],flush=True);assert r.returncode==0
place=DEST/'TheWindowsill-private-current.rbxlx'
subprocess.run([str(TOOLS/'rojo/rojo.exe'),'build',str(config),'-o',str(place)],check=True)
actual={};disabled=[]
def walk(it,parent=''):
 props=it.find('Properties');path=(parent+'.'if parent else '')+props.findtext("string[@name='Name']")
 source=props.find("*[@name='Source']")
 if source is not None:actual[path]=(source.text or '').replace('\r\n','\n').encode()
 if it.attrib['class']in ['Script','LocalScript']:disabled.append(props.findtext("bool[@name='Disabled']")=='true')
 for child in it.findall('Item'):walk(child,path)
for it in ET.parse(place).getroot().findall('Item'):walk(it)
assert len(actual)==274 and not any(disabled)
assert actual.pop('ReplicatedFirst.PlayerArrivalProbe')==probe
assert {k:sha(v)for k,v in actual.items()}==receipt['sources']
actual['ReplicatedFirst.PlayerArrivalProbe']=probe
rows=[[k,len(v),zlib.adler32(v)]for k,v in sorted(actual.items())]
guard='assert(not game:GetService("RunService"):IsRunning()and game.GameId==10771634917 and game.PlaceId==109879630247781);'
guard+='assert(workspace:GetAttribute("SaveStore")=="'+STORE+'"and workspace:GetAttribute("PortEvidence")=="'+receipt['evidence_id']+'"and workspace:GetAttribute("Detail")==nil);assert(workspace:GetAttribute("World")=="preserve"and workspace:GetAttribute("SelfTest")==false and workspace:GetAttribute("TestTarget")==false and workspace:GetAttribute("SaveWait")==true);'
guard+='local expected='+json.dumps(rows,separators=(',',':')).replace('[','{').replace(']','}')+';'
guard+='for _,r in expected do local it=game;for n in string.gmatch(r[1],"[^.]+")do it=assert(it:FindFirstChild(n),r[1])end;local s=string.gsub(it.Source,"\\r\\n","\\n");local x,y=1,0;for i=1,#s do x=(x+string.byte(s,i))%65521;y=(y+x)%65521 end;assert(#s==r[2]and y*65536+x==r[3],r[1])end;'
guard+='local n=0;for _,root in {game.ReplicatedFirst,game.ReplicatedStorage,game.ServerScriptService,game.StarterPlayer,workspace}do for _,it in root:GetDescendants()do if it:IsA("LuaSourceContainer")then n+=1;if it:IsA("BaseScript")then assert(not it.Disabled)end end end end;assert(n==274);assert(#game.ServerScriptService.PortTests:GetDescendants()==0);print("[PRIVATE_CURRENT_GUARD]",274,"'+receipt['evidence_id']+'","'+STORE+'")'
setup='assert(not game:GetService("RunService"):IsRunning());assert((game.PlaceId==0 and game.GameId==0)or(game.PlaceId==109879630247781 and game.GameId==10771634917));if game.PlaceId==0 then game:SetPlaceId(109879630247781);game:SetUniverseId(10771634917)end;'+guard
(DEST/'guard.luau').write_bytes((guard+'\n').encode());(DEST/'setup.luau').write_bytes((setup+'\n').encode())
m=dict(place=str(place),place_sha256=sha(place.read_bytes()),source_count=274,unchanged_game_sources=273,
 source_commit=SOURCE_COMMIT,ci_run=ci['run']['id'],evidence_id=receipt['evidence_id'],
 sources={k:sha(v)for k,v in actual.items()},readonly_probe_sha256=sha(probe),
 clean_model_sha256=normal['sha256'],guard_sha256=sha((DEST/'guard.luau').read_bytes()),setup_sha256=sha((DEST/'setup.luau').read_bytes()),
 universe=10771634917,place_id=109879630247781,test_store=STORE,key_policy='ordinary test-place t<server os.time>_<UserId>',
 normal_gameplay=True,selftest=False,published=False,authorization='Not requested yet for this new candidate; previous private13 authorization is fulfilled.',
 limits='Prepared source identity and static checks. Native guard, publication/version, standalone observation and full gameplay verification are separate.')
(H/'prepared.json').write_bytes((json.dumps(m,indent=2)+'\n').encode());(DEST/'manifest.json').write_bytes((json.dumps(m,indent=2)+'\n').encode())
print(json.dumps({k:m[k]for k in ['place','place_sha256','source_count','evidence_id','test_store']},indent=2))
