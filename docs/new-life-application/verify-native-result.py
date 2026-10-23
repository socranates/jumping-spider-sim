"""Recheck source/model identity and retained terminal native evidence."""
from pathlib import Path
import hashlib,json,re,subprocess,sys
H=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
for attempt in [1,2]:
 result=json.loads((H/f'native-attempt{attempt}.json').read_text())
 prepared=json.loads((H/f'native-prepared-attempt{attempt}.json').read_text())
 assert result['source']==prepared['source']=='bd67582b5d53473f067244fc1e2e1f94adde173b'
 for key in ['place_sha256','manifest_sha256','diagnostics']:assert result[key]==prepared[key],key
 command=[sys.executable,str(H/'verify-native-prepared.py'),'--out',result['artifact'],'--receipt',f'native-prepared-attempt{attempt}.json','--check']
 if attempt==1:command+=['--client-source','native-attempt1-client.luau']
 subprocess.run(command,check=True,capture_output=True)
 raw=(H/f'native-attempt{attempt}.txt').read_bytes();assert sha(raw)==result['output_sha256']
 text=raw.decode();tag=result['run']
 assert f'[NEW_APP_NATIVE_GUARD] {result["source"]} 265 memory_only unbound do_not_publish' in text
 assert f'[NEW_APP_NATIVE_CLIENT_BEGIN] {tag} ' in text and f'[NEW_APP_NATIVE_SERVER_BEGIN] {tag} ' in text
 if attempt==1:
  assert result['terminal']=='failed' and not result['native_verified']
  assert f'[NEW_APP_NATIVE_CLIENT_FAIL] {tag} ' in text and 'native held world admitted reset/local return' in text
 else:
  assert result['terminal']=='passed' and result['native_verified'] and result['client_checks']==70
  assert result['stored_modes']==['main','free','easy']
  rows=re.findall(r'\[NEW_APP_NATIVE_NEW_STORED\] '+tag+r' (main|free|easy) actual_menu real_grant life_save stored_ack immutable_original',text)
  assert rows==result['stored_modes']
  passed=re.findall(r'\[NEW_APP_NATIVE_CLIENT_PASS\] '+tag+r' 70 (\{.*\})',text)
  assert len(passed)==1 and json.loads(passed[0])==result['client_summary']
  assert result['client_summary']==dict(clock_scale=10,engine_codec=True,memory_store=True,online=False,options=224,real_remote_events=True,server_checks=10)
  assert '[NEW_APP_NATIVE_CLIENT_FAIL]' not in text and '[NEW_APP_NATIVE_SERVER_FAIL]' not in text and '[FLog::CreatorError]' not in text
  assert '"lockReleased":true' in text and '"optionsCreated":224,"optionsDestroyed":224' in text
  assert '"originalExact":{"easy":true,"free":true,"main":true}' in text
 assert not result['online_verified'] and not result['published']
print('Native attempts bound: preserved diagnostic failure; current 70 client +10 server pass; no online/release claim.')
