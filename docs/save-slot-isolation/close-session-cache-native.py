"""Run only after observing stopped playback, saved/closed place and exited window."""
from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent
folder=Path(r'C:/Users/natha/claude-xfer/Windowsill-session-cache-405e9df')
place=folder/'Windowsill-session-cache-review.rbxlx';original=folder/'original.rbxlx';saved=folder/'studio-saved.rbxlx'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
m=json.loads((HERE/'prepared-session-cache-native-manifest.json').read_text())
assert sha(original)==m['place_sha256'] and not saved.exists()
saved.write_bytes(place.read_bytes());place.write_bytes(original.read_bytes())
assert sha(place)==m['place_sha256']
receipt=dict(playback_stopped=True,place_closed=True,diagnostic_window_closed=True,diagnostic_window_id=406390538,prior_window_id=94504044,prior_window_remained=True,saved_serialization_sha256=sha(saved),original_restored_sha256=sha(place))
(HERE/'session-cache-native-close.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(receipt,indent=2))
