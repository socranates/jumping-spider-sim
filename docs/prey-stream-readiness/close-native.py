"""Restore diagnostic bytes only after both owned Studio windows have exited."""
from pathlib import Path
import hashlib,json,subprocess
HERE=Path(__file__).resolve().parent
BASE=Path(r'C:/Users/natha/claude-xfer')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
# The UI observer confirmed stopped/closed windows 7606220 and 153093060,
# with the unrelated pre-existing rig window 94504044 still present.
for suffix,window,outfile in [('',7606220,'native-attempt1-close.json'),('-v2',153093060,'native-close.json')]:
 folder=BASE/('Windowsill-prey-readiness-032926f'+suffix)
 place=folder/'Windowsill-prey-readiness-review.rbxlx'
 original=folder/'original.rbxlx'
 manifest=json.loads((HERE/('native-attempt1-manifest.json' if not suffix else 'prepared-native-manifest.json')).read_text(encoding='utf8'))
 assert sha(original)==manifest['place_sha256']
 if suffix:
  saved=folder/'studio-saved.rbxlx';assert not saved.exists()
  saved.write_bytes(place.read_bytes());place.write_bytes(original.read_bytes())
 else:saved=folder/'studio-saved.rbxlx'
 assert sha(place)==manifest['place_sha256']
 receipt=dict(playback_stopped=True,place_closed=True,diagnostic_window_closed=True,
  diagnostic_window_id=window,prior_window_id=94504044,prior_window_remained=True,
  saved_serialization_sha256=sha(saved),original_restored_sha256=sha(place))
 (HERE/outfile).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print('Both diagnostic archives restored; owned windows closed; original rig retained.')
