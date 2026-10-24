"""Create a test-only upload from the clean candidate; unchanged gameplay sources."""
from pathlib import Path
import argparse,copy,hashlib,json,subprocess,xml.etree.ElementTree as ET,zlib
H=Path(__file__).resolve().parent
TOOLS=Path('C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--candidate',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
candidate=a.candidate.resolve();out=a.out.resolve();assert out.parent.is_dir()and not out.exists();out.mkdir()
clean=json.loads((candidate/'manifest.json').read_text(encoding='utf8'));assert clean['source_count']==273 and clean['diagnostics']==False
project=json.loads((candidate/'roblox_port/default.project.json').read_text(encoding='utf8'))
project.update(name='WindowsillIsolatedPlayerReview',servePort=34875,servePlaceIds=[109879630247781],placeId=109879630247781,gameId=10771634917)
probe=H/'player-probe.client.luau';r=subprocess.run([str(TOOLS/'luau/luau-compile.exe'),'--null',str(probe)],capture_output=True,text=True);assert r.returncode==0,r.stdout+r.stderr
first={'$className':'ReplicatedFirst','$ignoreUnknownInstances':False}
for path in sorted((candidate/'roblox_port/src/First').glob('*.luau')):
 name=path.name.removesuffix('.luau').removesuffix('.client');first[name]={'$path':str(path)}
first['PlayerArrivalProbe']={'$path':str(probe)}
project['tree']['ReplicatedFirst']=first
# A marker, not a test runner: ordinary Persistence selects the test store and
# its t<fresh-server-time>_<UserId> keys. No existing user/test record is read.
project['tree']['ServerScriptService']['PortTests']={'$className':'Folder','$ignoreUnknownInstances':False}
store='WindowsillTest_player57_20261023a1';assert len(store)<=40
project['tree']['Workspace']['$attributes'].update(SaveStore=store)
assert 'Detail'not in project['tree']['Workspace']['$attributes']
config=out/'player-test.project.json';config.write_bytes((json.dumps(project,indent=2)+'\n').encode())
place=out/'TheWindowsill-isolated-player.rbxlx';subprocess.run([str(TOOLS/'rojo/rojo.exe'),'build',str(config),'-o',str(place)],check=True)
actual={};disabled=[]
def walk(item,parent=''):
 props=item.find('Properties');name=props.findtext("string[@name='Name']");path=parent+'.'+name if parent else name
 source=props.find("*[@name='Source']")
 if source is not None:actual[path]=(source.text or '').replace('\r\n','\n').encode()
 if item.attrib['class']in ['Script','LocalScript']:disabled.append([path,props.findtext("bool[@name='Disabled']")=='true'])
 for child in item.findall('Item'):walk(child,path)
for item in ET.parse(place).getroot().findall('Item'):
 name=item.find('Properties').findtext("string[@name='Name']")
 if name in ['ReplicatedFirst','ReplicatedStorage','ServerScriptService','StarterPlayer','Workspace']:assert item.attrib['class']==name
 walk(item)
assert len(actual)==274 and not any(flag for _,flag in disabled)
assert {k:sha(v)for k,v in actual.items()if k!='ReplicatedFirst.PlayerArrivalProbe'}==clean['sources']
assert actual['ReplicatedFirst.PlayerArrivalProbe']==probe.read_bytes()
mapfile=out/'sourcemap.json'
subprocess.run([str(TOOLS/'rojo/rojo.exe'),'sourcemap',str(config),'--output',str(mapfile)],check=True)
r=subprocess.run([str(TOOLS/'lsp/luau-lsp.exe'),'analyze','--sourcemap='+str(mapfile),'--definitions='+str(TOOLS/'globalTypes.d.luau'),'--no-strict-dm-types',str(candidate/'roblox_port/src'),str(probe)],cwd=out,capture_output=True,text=True)
(out/'strict.txt').write_bytes((r.stdout+r.stderr).encode());print('strict',r.returncode,(r.stdout+r.stderr)[:1200]);assert r.returncode==0
guard='assert(not game:GetService("RunService"):IsRunning()and game.GameId==10771634917 and game.PlaceId==109879630247781);assert(workspace:GetAttribute("SaveStore")=="'+store+'"and workspace:GetAttribute("Detail")==nil);local expected='+json.dumps([[k,len(v),zlib.adler32(v)]for k,v in sorted(actual.items())],separators=(',',':')).replace('[','{').replace(']','}')+';'
guard+='for _,r in expected do local it=game;for n in string.gmatch(r[1],"[^.]+")do it=assert(it:FindFirstChild(n),r[1])end;local s=string.gsub(it.Source,"\\r\\n","\\n");local a,b=1,0;for i=1,#s do a=(a+string.byte(s,i))%65521;b=(b+a)%65521 end;assert(#s==r[2]and b*65536+a==r[3],r[1])end;local count=0;for _,root in {game.ReplicatedFirst,game.ReplicatedStorage,game.ServerScriptService,game.StarterPlayer,workspace}do for _,it in root:GetDescendants()do if it:IsA("LuaSourceContainer")then count+=1 end end end;assert(count==274,"unexpected editable source count");assert(#game.ServerScriptService.PortTests:GetDescendants()==0);assert(not game.ServerScriptService.Server.Persistence.Disabled);print("[ISOLATED_PLAYER_GUARD]",274,"normal_gameplay_fresh_test_keys_only_never_production")'
(out/'guard.luau').write_bytes(guard.encode())
manifest=dict(candidate=str(candidate),candidate_manifest_sha256=sha((candidate/'manifest.json').read_bytes()),clean_place_sha256=clean['place_sha256'],place=str(place),place_sha256=sha(place.read_bytes()),
 sources={k:sha(v)for k,v in actual.items()},source_count=274,unchanged_game_sources=273,readonly_probe_sha256=sha(probe.read_bytes()),guard_sha256=sha(guard.encode()),
 universe=10771634917,place_id=109879630247781,test_store=store,key_policy='ordinary test-place t<server os.time>_<UserId>',published=False,executed=False)
(out/'manifest.json').write_bytes((json.dumps(manifest,indent=2)+'\n').encode());print(json.dumps({k:manifest[k]for k in ['place','place_sha256','source_count','unchanged_game_sources','test_store']},indent=2))
