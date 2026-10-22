"""Build a guarded local caption review with the production persistence script disabled."""
from pathlib import Path
import argparse,hashlib,json,subprocess,zlib,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;PORT=ROOT/'roblox_port'
p=argparse.ArgumentParser();p.add_argument('--rojo',required=True);p.add_argument('--out',required=True);a=p.parse_args()
out=Path(a.out).resolve();assert not out.exists();out.mkdir(parents=True)
source='a36789375dd75920c0eca59ac524644b8776477f'
for line in subprocess.check_output(['git','ls-tree','-rz',source,'roblox_port/src'],cwd=ROOT).split(b'\0'):
 if not line:continue
 header,name=line.split(b'\t',1);data=(ROOT/name.decode()).read_bytes()
 assert hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()==header.split()[2].decode(),name
project=json.loads((PORT/'default.project.json').read_text())
def absolute(node):
 if isinstance(node,dict):
  for key,value in node.items():
   if key=='$path':node[key]=str(PORT/value)
   else:absolute(value)
absolute(project)
tree=project['tree'];tree['StarterPlayer']['StarterPlayerScripts']['Client']['SilkPlayback']={'$path':str(HERE/'native-probe.luau')}
tree['Workspace']['$attributes']={'World':'preserve','Detail':'full','SelfTest':False,'TestTarget':False,'Wasp':True,'Cat':True,'Bird':True,'Frog':True,'CaptionProbe':True}
config=out/'native.project.json';config.write_text(json.dumps(project,indent=2),encoding='utf-8',newline='\n')
place=out/'Windowsill-captions-review.rbxlx';subprocess.run([a.rojo,'build',str(config),'-o',str(place)],check=True)
xml=ET.parse(place);rows=[]
def walk(item,parent=''):
 props=item.find('Properties');name=props.findtext("string[@name='Name']");path=parent+'.'+name if parent else name
 if path=='ServerScriptService.Server.Persistence':
  flag=props.find("bool[@name='Disabled']")
  if flag is None:flag=ET.SubElement(props,'bool',{'name':'Disabled'})
  flag.text='true'
 code=props.find("*[@name='Source']")
 if code is not None:
  text=(code.text or '').replace('\r\n','\n').encode();rows.append({'path':path,'length':len(text),'adler32':zlib.adler32(text),'sha256':hashlib.sha256(text).hexdigest()})
 for child in item.findall('Item'):walk(child,path)
for item in xml.getroot().findall('Item'):walk(item)
assert len(rows)==217
xml.write(place,encoding='utf-8',xml_declaration=False)
guard='assert(game.PlaceId==0 and not game:GetService("RunService"):IsRunning() and workspace:GetAttribute("CaptionProbe")==true and game.ServerScriptService.Server.Persistence.Disabled==true);local expected={'
guard+=','.join('{'+json.dumps(r['path'])+','+str(r['length'])+','+str(r['adler32'])+'}' for r in rows)+'};'
guard+='for _,r in expected do local it=game;for name in string.gmatch(r[1],"[^.]+") do it=assert(it:FindFirstChild(name),r[1]) end;local s=string.gsub(it.Source,"\\r\\n","\\n");local a,b=1,0;for i=1,#s do a=(a+string.byte(s,i))%65521;b=(b+a)%65521 end;assert(#s==r[2] and b*65536+a==r[3],r[1]) end;local n=0;for _,root in {game.ReplicatedFirst,game.ReplicatedStorage.Shared,game.ServerScriptService.Server,game.StarterPlayer.StarterPlayerScripts.Client} do for _,it in root:GetDescendants() do if it:IsA("LuaSourceContainer") then n+=1 end end end;assert(n==#expected);print("[CAPTION_NATIVE_GUARD]","'+source+'",n,"persistence_disabled")'
(out/'guard.luau').write_text(guard,encoding='utf-8',newline='\n')
manifest={'source':source,'scripts':rows,'persistence_disabled':True,'place_sha256':hashlib.sha256(place.read_bytes()).hexdigest(),'scope':'Caption UI probe only, no save backend or performance claim; never publish'}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps({'place':str(place),'scripts':len(rows),'persistence_disabled':True,'sha256':manifest['place_sha256']}))
