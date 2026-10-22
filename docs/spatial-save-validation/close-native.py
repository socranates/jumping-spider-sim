"""Archive serialization/restore bytes after UI has confirmed this diagnostic exited."""
from pathlib import Path
import argparse,hashlib,json
p=argparse.ArgumentParser();p.add_argument('--folder',required=True);p.add_argument('--place',required=True)
p.add_argument('--manifest',required=True);p.add_argument('--output',required=True);p.add_argument('--window',type=int,required=True)
a=p.parse_args();folder=Path(a.folder).resolve();place=(folder/a.place).resolve()
assert place.parent==folder and place.suffix=='.rbxlx'
m=json.loads(Path(a.manifest).read_text(encoding='utf8'));sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
original=folder/'original.rbxlx';saved=folder/'studio-saved.rbxlx'
assert sha(original)==m['place_sha256'] and not saved.exists()
saved.write_bytes(place.read_bytes());place.write_bytes(original.read_bytes())
assert sha(place)==m['place_sha256']
receipt=dict(playback_stopped=True,place_closed=True,diagnostic_window_closed=True,diagnostic_window_id=a.window,
 prior_window_id=94504044,prior_window_remained=True,saved_serialization_sha256=sha(saved),original_restored_sha256=sha(place))
Path(a.output).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(receipt,indent=2))
