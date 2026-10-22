"""Build immutable local memory profiles. No game source edits, publishing or live saves."""
from pathlib import Path
import argparse,subprocess,hashlib,json,zipfile,zlib,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--source',required=True);p.add_argument('--rojo',required=True);p.add_argument('--out',required=True);a=p.parse_args()
source=subprocess.check_output(['git','rev-parse',a.source+'^{commit}'],cwd=ROOT,text=True).strip()
out=Path(a.out);assert out.is_absolute() and not out.exists(),'choose a new absolute directory';out.mkdir(parents=True)
archive=out/'source.zip';subprocess.run(['git','archive','--format=zip','--output='+str(archive),source,'roblox_port/src','roblox_port/default.project.json'],cwd=ROOT,check=True)
frozen=out/'frozen';frozen.mkdir()
with zipfile.ZipFile(archive) as z:
 assert all(frozen in (frozen/n).resolve().parents for n in z.namelist());z.extractall(frozen)
port=frozen/'roblox_port';expected={};source_rows=[]
for line in subprocess.check_output(['git','ls-tree','-rz',source,'roblox_port/src'],cwd=ROOT).split(b'\0'):
 if not line:continue
 head,name=line.split(b'\t',1);rel=name.decode();data=(frozen/rel).read_bytes()
 assert hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()==head.split()[2].decode(),rel
 parts=list(Path(rel).relative_to('roblox_port/src').parts)
 prefix={'First':'ReplicatedFirst','Client':'StarterPlayer.StarterPlayerScripts.Client','Server':'ServerScriptService.Server','Shared':'ReplicatedStorage.Shared'}[parts.pop(0)]
 parts[-1]=parts[-1].removesuffix('.luau').removesuffix('.client').removesuffix('.server')
 instance=prefix+'.'+'.'.join(parts);norm=data.replace(b'\r\n',b'\n')
 expected[instance]=hashlib.sha256(norm).hexdigest();source_rows.append({'path':rel,'instance':instance,'sha256':hashlib.sha256(data).hexdigest(),'native_sha256':expected[instance]})
assert len(expected)==216
driver=HERE/'driver.luau';driver_data=driver.read_bytes().replace(b'\r\n',b'\n')
expected['StarterPlayer.StarterPlayerScripts.Client.SilkPlayback']=hashlib.sha256(driver_data).hexdigest()
def absolute(node):
 if isinstance(node,dict):
  for key,value in node.items():
   if key=='$path':node[key]=str(port/value)
   else:absolute(value)
manifest={'source':source,'source_archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'source_rows':source_rows,
 'driver_sha256':hashlib.sha256(driver_data).hexdigest(),'scope':'Desktop native memory diagnostics, not release or phone evidence','profiles':[]}
for profile,duration,dwell,tier in [('smoke',90,3,'full'),('long',1800,30,'full')]:
 project=json.loads((port/'default.project.json').read_text());project['name']='WindowsillMemoryTraceNeverPublish';absolute(project)
 tree=project['tree'];tree['StarterPlayer']['StarterPlayerScripts']['Client']['SilkPlayback']={'$path':str(driver)}
 attrs={'World':'preserve','Detail':tier,'SelfTest':False,'TestTarget':False,'Wasp':True,'Cat':True,'Bird':True,'Frog':True,
  'MemoryTrace':True,'TraceSource':source,'TraceDurationSeconds':duration,'TraceDwellSeconds':dwell,'TraceProfile':profile}
 tree['Workspace']['$attributes']=attrs
 config=out/(profile+'.project.json');config.write_text(json.dumps(project,indent=2)+'\n',encoding='utf8',newline='\n')
 place=out/('memory-'+profile+'-'+tier+'.rbxlx');subprocess.run([a.rojo,'build',str(config),'-o',str(place)],check=True)
 xml=ET.parse(place);paths=set();rows=[];disabled=False
 def walk(item,parent=''):
  global disabled
  props=item.find('Properties');name=props.findtext("string[@name='Name']") or item.attrib['class'];path=parent+'.'+name if parent else name
  assert path not in paths,'duplicate instance path: '+path;paths.add(path)
  if path=='ServerScriptService.Server.Persistence':
   flag=props.find("bool[@name='Disabled']")
   if flag is None:flag=ET.SubElement(props,'bool',{'name':'Disabled'})
   flag.text='true';disabled=True
  code=props.find("*[@name='Source']")
  if code is not None:
   data=(code.text or '').replace('\r\n','\n').encode();rows.append({'path':path,'bytes':len(data),'adler32':zlib.adler32(data),'sha256':hashlib.sha256(data).hexdigest()})
  for child in item.findall('Item'):walk(child,path)
 for item in xml.getroot().findall('Item'):walk(item)
 assert disabled and len(rows)==217 and {r['path']:r['sha256'] for r in rows}==expected
 xml.write(place,encoding='utf8',xml_declaration=False)
 # JSON object syntax is not Lua: generate a literal with explicit keyed entries.
 guard='assert(game.PlaceId==0 and not game:GetService("RunService"):IsRunning() and game.ServerScriptService.Server.Persistence.Disabled==true);'
 guard+='local attrs={'+','.join('['+json.dumps(k)+']='+('true' if v is True else 'false' if v is False else json.dumps(v)) for k,v in attrs.items())+'};for k,v in attrs do assert(workspace:GetAttribute(k)==v,k) end;'
 guard+='local expected={'+','.join('{'+json.dumps(r['path'])+','+str(r['bytes'])+','+str(r['adler32'])+'}' for r in rows)+'};'
 guard+='for _,r in expected do local it=game;for part in string.gmatch(r[1],"[^.]+") do it=assert(it:FindFirstChild(part),r[1]) end;local s=string.gsub(it.Source,"\\r\\n","\\n");local a,b=1,0;for i=1,#s do a=(a+string.byte(s,i))%65521;b=(b+a)%65521 end;assert(#s==r[2] and b*65536+a==r[3],r[1]) end;'
 guard+='local n=0;for _,root in {game.ReplicatedFirst,game.ReplicatedStorage.Shared,game.ServerScriptService.Server,game.StarterPlayer.StarterPlayerScripts.Client} do for _,it in root:GetDescendants() do if it:IsA("LuaSourceContainer") then n+=1 end end end;assert(n==217);'
 guard+='print("[MEMTRACE_GUARD]",'+json.dumps(source)+','+json.dumps(profile)+','+str(duration)+',217,"persistence_disabled")'
 guardpath=out/(profile+'.guard.luau');guardpath.write_text(guard,encoding='utf8',newline='\n')
 manifest['profiles'].append({'profile':profile,'tier':tier,'duration':duration,'dwell':dwell,'attributes':attrs,'scripts':rows,
  'place':str(place),'place_sha256':hashlib.sha256(place.read_bytes()).hexdigest(),'guard_sha256':hashlib.sha256(guard.encode()).hexdigest(),'persistence_disabled':True,'published':False})
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps({'source':source,'profiles':[{k:r[k] for k in ['profile','place','place_sha256','duration']} for r in manifest['profiles']]},indent=2))
