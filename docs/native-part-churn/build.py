"""Prepare one frozen isolated native allocation control. Never publish."""
from pathlib import Path
import argparse,hashlib,json,subprocess,zlib,xml.etree.ElementTree as ET
HERE=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--rojo',required=True);p.add_argument('--out',required=True);a=p.parse_args()
out=Path(a.out);assert out.is_absolute() and not out.exists(),'choose a new absolute output directory';out.mkdir(parents=True)
data=(HERE/'probe.client.luau').read_bytes().replace(b'\r\n',b'\n');sha=hashlib.sha256(data).hexdigest()
probe=out/'Probe.client.luau';probe.write_bytes(data)
config={'name':'PartChurnNeverPublish','tree':{'$className':'DataModel',
 'StarterPlayer':{'StarterPlayerScripts':{'PartChurn':{'$path':str(probe)}}},
 'Players':{'$properties':{'CharacterAutoLoads':False}},
 'Workspace':{'$properties':{'Gravity':0,'StreamingEnabled':False},'$attributes':{'PartChurnProbe':True,'ProbeSHA256':sha}},
 'Lighting':{'$properties':{'ClockTime':14,'GlobalShadows':False}}}}
project=out/'probe.project.json';project.write_text(json.dumps(config,indent=2)+'\n',encoding='utf8',newline='\n')
place=out/'Windowsill-part-churn-control.rbxlx';subprocess.run([a.rojo,'build',str(project),'-o',str(place)],check=True)
found={};paths=set()
def walk(item,parent=''):
 name=item.findtext("./Properties/*[@name='Name']");full=parent+'.'+name if parent else name
 assert full not in paths,'duplicate instance path';paths.add(full)
 if item.attrib['class'] in {'Script','LocalScript','ModuleScript'}:
  code=item.findtext("./Properties/*[@name='Source']").replace('\r\n','\n').encode()
  found[full]=hashlib.sha256(code).hexdigest()
 for child in item.findall('Item'):walk(child,full)
for item in ET.parse(place).getroot().findall('Item'):walk(item)
assert found=={'StarterPlayer.StarterPlayerScripts.PartChurn':sha}
guard='assert(game.PlaceId==0 and not game:GetService("RunService"):IsRunning());assert(workspace:GetAttribute("PartChurnProbe")==true and workspace:GetAttribute("ProbeSHA256")=='+json.dumps(sha)+');'
guard+='local s=string.gsub(game.StarterPlayer.StarterPlayerScripts.PartChurn.Source,"\\r\\n","\\n");local a,b=1,0;for i=1,#s do a=(a+string.byte(s,i))%65521;b=(b+a)%65521 end;assert(#s=='+str(len(data))+' and b*65536+a=='+str(zlib.adler32(data))+');'
guard+='local n=0;for _,it in game:GetDescendants() do if it:IsA("LuaSourceContainer") then n+=1 end end;assert(n==1);print("[PART_CHURN_GUARD]",'+json.dumps(sha)+',n,"no_game_no_persistence")'
(out/'guard.luau').write_text(guard,encoding='utf8',newline='\n')
manifest={'probe_sha256':sha,'probe_bytes':len(data),'probe_adler32':zlib.adler32(data),'scripts':found,
 'place':str(place),'place_sha256':hashlib.sha256(place.read_bytes()).hexdigest(),'guard_sha256':hashlib.sha256(guard.encode()).hexdigest(),
 'parts':1000,'cycles':60,'stationary_seconds':30,'quiet_seconds':30,'sample_seconds':5,
 'scope':'Isolated desktop Studio Part allocation control, not game walking, standalone-client, phone or FPS evidence',
 'game_source_included':False,'persistence_included':False,'published':False}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(manifest,indent=2))
