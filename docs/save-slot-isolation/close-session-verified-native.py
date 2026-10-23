"""After observing stopped/saved/closed place and exited window129368102 only."""
from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent;folder=Path(r'C:/Users/natha/claude-xfer/Windowsill-session-verified-f405359')
place=folder/'Windowsill-session-verified-review.rbxlx';original=folder/'original.rbxlx';saved=folder/'studio-saved.rbxlx';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
m=json.loads((HERE/'prepared-session-verified-native-manifest.json').read_text());assert sha(original)==m['place_sha256'] and not saved.exists()
saved.write_bytes(place.read_bytes());place.write_bytes(original.read_bytes());assert sha(place)==m['place_sha256']
r=dict(playback_stopped=True,place_closed=True,diagnostic_window_closed=True,diagnostic_window_id=129368102,prior_window_id=94504044,prior_window_remained=True,saved_serialization_sha256=sha(saved),original_restored_sha256=sha(place))
(HERE/'session-verified-native-close.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
