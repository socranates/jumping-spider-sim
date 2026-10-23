"""Build a bounded, separate streaming experiment with explicitly recorded engine policy."""
from pathlib import Path
import argparse,hashlib,json,subprocess,sys,xml.etree.ElementTree as ET
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--tier',choices=['full','low'],required=True);p.add_argument('--behavior',choices=['Default','Opportunistic'],required=True);p.add_argument('--attempt',type=int,default=1);a=p.parse_args();assert a.attempt>0
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
assert source=='695e772d9d1ece490dd32132c655ac60c226c7b8'
subprocess.run([sys.executable,str(H/'build-native.py'),'--source',source,'--rojo',r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/rojo/rojo.exe','--out',str(a.out),'--tier',a.tier,'--probe',str(H/'engine-stream-probe.luau')],check=True)
original=a.out/'Windowsill-player-stream-review.rbxlx';xml=ET.parse(original)
workspaces=[i for i in xml.getroot().findall('Item') if i.attrib['class']=='Workspace'];assert len(workspaces)==1
props=workspaces[0].find('Properties');flag=props.find("token[@name='StreamOutBehavior']")
if flag is None:flag=ET.SubElement(props,'token',{'name':'StreamOutBehavior'})
# Resolve serialization through the installed Rojo enum database rather than
# guessing a numeric enum value. Studio's guard also checks the named value.
policy=a.out/'enum-policy.project.json';policyPlace=a.out/'enum-policy.rbxlx'
policy.write_text(json.dumps({'name':'StreamingPolicy','tree':{'$className':'DataModel','Workspace':{'$className':'Workspace','$properties':{'StreamOutBehavior':a.behavior}}}}),encoding='utf8')
subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/rojo/rojo.exe','build',str(policy),'-o',str(policyPlace)],check=True)
value=ET.parse(policyPlace).getroot().findtext("Item/Properties/token[@name='StreamOutBehavior']");assert value is not None
flag.text=value
suffix='-attempt-'+str(a.attempt) if a.attempt>1 else ''
name='Windowsill-engine-stream-695e772-'+a.tier+'-'+a.behavior.lower()+suffix+'.rbxlx';place=a.out/name
xml.write(place,encoding='utf8',xml_declaration=False)
# These settings are intentionally non-scriptable in some Studio versions.
# Verify serialized values against the authored production project and enum tool.
assert props.findtext("bool[@name='StreamingEnabled']")=='true'
assert props.findtext("int[@name='StreamingMinRadius']")=='96'
assert props.findtext("int[@name='StreamingTargetRadius']")=='160'
assert props.findtext("token[@name='StreamOutBehavior']")==value
manifest=json.loads((a.out/'manifest.json').read_text(encoding='utf8'))
manifest.update(place_sha256=hashlib.sha256(place.read_bytes()).hexdigest(),place_name=name,stream_out_behavior=a.behavior,serialized_streaming_min_radius=96,serialized_streaming_target_radius=160,serialized_settings_verified=True,collision_mutations_in_probe=False,scope='Unbound, saving disabled, actual production client/WorldFocus and real engine streaming. Explicit diagnostic stream-out policy, no collision-folder mutations. Bounded local Studio observation; not production network pressure, device performance, recovery or online datastore proof; never publish.')
(a.out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n')
guard=a.out/'guard.luau';text=guard.read_text(encoding='utf8');guard.write_text('assert(workspace.StreamingEnabled);'+text,encoding='utf8',newline='\n')
subprocess.run([sys.executable,str(H/'verify-native-prepared.py'),'--out',str(a.out),'--probe',str(H/'engine-stream-probe.luau'),'--place-name',name,'--receipt','engine-'+a.tier+'-'+a.behavior.lower()+suffix+'-prepared.json'],check=True)
print('Prepared',place,'with',a.behavior,'stream-out policy; not executed')
