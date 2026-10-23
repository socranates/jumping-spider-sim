"""Build a small standalone Studio scene with exact production animal modules. Never publish."""
from pathlib import Path
import argparse,hashlib,json,subprocess,xml.etree.ElementTree as ET
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PORT=ROOT/'roblox_port'
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
p=argparse.ArgumentParser();p.add_argument('--attempt',type=int,default=1);a=p.parse_args();assert 1<=a.attempt<=3
out=Path(r'C:/Users/natha/claude-xfer')/('Windowsill-animal-animation-'+source[:7]+('-v'+str(a.attempt) if a.attempt>1 else ''))
out.mkdir(exist_ok=False)
project={'name':'AnimalAnimationReview','tree':{'$className':'DataModel',
 'ReplicatedStorage':{'Shared':{'$path':str(PORT/'src/Shared')}},
 'StarterPlayer':{'StarterPlayerScripts':{'Review':{'$path':str(H/'native-review.client.luau'),'$attributes':{'SourceCommit':source}},'LivingWorld':{'$path':str(PORT/'src/Client/LivingWorld.luau')},'CatBody':{'$path':str(PORT/'src/Client/CatBody.luau')}}},
 'Players':{'$properties':{'CharacterAutoLoads':False}},'Workspace':{'$properties':{'StreamingEnabled':False},'$attributes':{'AnimalAnimationReview':True}},
 'Lighting':{'$properties':{'ClockTime':13,'Brightness':2,'Technology':'Future'}}}}
config=out/'review.project.json';config.write_text(json.dumps(project,indent=2),encoding='utf8',newline='\n')
place=out/'AnimalAnimationReview.rbxlx'
subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/rojo/rojo.exe','build',str(config),'-o',str(place)],check=True)
xml=ET.parse(place);scripts=[]
for item in xml.getroot().iter('Item'):
 props=item.find('Properties')
 if props is None:continue
 code=props.find("*[@name='Source']")
 if code is not None:scripts.append(dict(name=props.findtext("string[@name='Name']"),sha256=hashlib.sha256((code.text or '').replace('\r\n','\n').encode()).hexdigest()))
manifest=dict(source=source,place=str(place),sha256=hashlib.sha256(place.read_bytes()).hexdigest(),scripts=scripts,production_startup=False,persistence=False,published=False,native_executed=False)
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n')
(H/'native-package.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n')
print(place)
