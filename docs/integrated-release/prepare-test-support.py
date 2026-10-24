"""Add the actual client clock API to the isolated staged CLI stand-in."""
from pathlib import Path
import argparse,hashlib,json
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
p=argparse.ArgumentParser();p.add_argument('--stage',type=Path,required=True);p.add_argument('--check',action='store_true');a=p.parse_args()
sha=lambda b:hashlib.sha256(b).hexdigest();original=(ROOT/'roblox_port/tests/shim.luau').read_bytes()
text=original.decode();anchor='client.scriptFolder = Instance.new("Folder")'
assert text.count(anchor)==1
text=text.replace(anchor,'''-- Server-time API used by the ordinary Preserve save client. Tests may pin it;
-- otherwise preserve the earlier stand-in's monotonic os.clock time base.
function workspace.GetServerTimeNow(_self)
 return if type(client.serverTime)=="number" then client.serverTime else os.clock()
end
'''+anchor)
target=a.stage.resolve()/'roblox_port/tests/shim.luau';data=text.encode()
receipt=dict(source='roblox_port/tests/shim.luau',original_sha256=sha(original),staged_sha256=sha(data),
 scope='CLI stand-in only; no game code or assertions changed',reason='Actual Workspace:GetServerTimeNow API absent from older stand-in')
if a.check:
 assert target.read_bytes()==data
 assert json.loads((a.stage/'test-support.json').read_text(encoding='utf8'))==receipt
else:
 assert target.read_bytes()==original and not (a.stage/'test-support.json').exists()
 target.write_bytes(data);(a.stage/'test-support.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode())
print('Staged client clock stand-in verified'if a.check else 'Staged client clock stand-in added')
