from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent
folder=Path(r'C:/Users/natha/claude-xfer/Windowsill-recovery-archive-405e9df')
place=folder/'Windowsill-recovery-archive-review.rbxlx';original=(folder/'original.rbxlx').read_bytes()
m=json.loads((HERE/'prepared-recovery-archive-native-unrun-manifest.json').read_text())
sha=lambda b:hashlib.sha256(b).hexdigest()
assert sha(original)==m['place_sha256']
saved=folder/'studio-saved.rbxlx';assert not saved.exists();saved.write_bytes(place.read_bytes());place.write_bytes(original)
(HERE/'recovery-archive-unrun-close.json').write_text(json.dumps(dict(window=421397974,window_closed=True,prior_window=94504044,prior_window_remained=True,guard_executed=False,play_executed=False,superseded_by='Windowsill-recovery-archive-405e9df-v2',reason='Corrected synthetic current/backup fixture aliasing before testing; raw stored values own independent decoded trees',saved_serialization_sha256=sha(saved.read_bytes()),original_restored_sha256=sha(original)),indent=2)+'\n',encoding='utf8',newline='\n')
print('Unrun diagnostic serialization retained and original hash restored.')
