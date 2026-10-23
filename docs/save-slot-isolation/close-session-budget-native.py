"""Only after observing both places stopped/saved/closed and window149554162 exited."""
from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent;BASE=Path(r'C:/Users/natha/claude-xfer')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for version,manifest,receipt in [('v2','prepared-session-budget-native-initial-manifest.json','session-budget-native-initial-close.json'),('v3','prepared-session-budget-native-manifest.json','session-budget-native-close.json')]:
 folder=BASE/('Windowsill-session-budget-f405359-'+version);place=folder/'Windowsill-session-budget-review.rbxlx';original=folder/'original.rbxlx';saved=folder/'studio-saved.rbxlx'
 m=json.loads((HERE/manifest).read_text());assert sha(original)==m['place_sha256'] and not saved.exists()
 saved.write_bytes(place.read_bytes());place.write_bytes(original.read_bytes());assert sha(place)==m['place_sha256']
 r=dict(playback_stopped=True,place_closed=True,diagnostic_window_closed=True,diagnostic_window_id=149554162,prior_window_id=94504044,prior_window_remained=True,saved_serialization_sha256=sha(saved),original_restored_sha256=sha(place))
 (HERE/receipt).write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(receipt,r['original_restored_sha256'])
