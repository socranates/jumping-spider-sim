"""Build private reference/candidate comparison. Does not launch or publish."""
from pathlib import Path
import hashlib,json,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PORT=ROOT/'roblox_port'
source=json.loads((H/'source.json').read_text())['source']
out=Path(r'C:/Users/natha/claude-xfer')/('Windowsill-wasp-reuse-'+source[:7]);out.mkdir(exist_ok=False)
tree={'$className':'DataModel','ReplicatedStorage':{'Shared':{'$path':str(PORT/'src/Shared')}},'StarterPlayer':{'StarterPlayerScripts':{'Trial':{'$path':str(H/'native.client.luau'),'$attributes':{'SourceCommit':source}},'Original':{'$path':str(H/'reference.luau')},'Candidate':{'$path':str(H/'candidate.luau')}}},'Players':{'$properties':{'CharacterAutoLoads':False}},'Workspace':{'$properties':{'StreamingEnabled':False},'$attributes':{'WaspReuseTrial':True}}}
config=out/'trial.project.json';config.write_text(json.dumps(dict(name='WaspReuseTrial',tree=tree),indent=2),encoding='utf8',newline='\n')
place=out/'WaspReuseTrial.rbxlx'
subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/rojo/rojo.exe','build',str(config),'-o',str(place)],check=True)
manifest=dict(source=source,place=str(place),place_sha256=hashlib.sha256(place.read_bytes()).hexdigest(),inputs={name:hashlib.sha256((H/name).read_bytes()).hexdigest() for name in ['native.client.luau','reference.luau','candidate.luau']},production_connected=False,persistence=False,native_executed=False,published=False)
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n');(H/'native-package.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n');print(place)
