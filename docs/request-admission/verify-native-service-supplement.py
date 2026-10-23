"""Bind the bounded complete Studio Output row to the truncated log prefix."""
from pathlib import Path
import hashlib,json,re
H=Path(__file__).resolve().parent;sha=lambda b:hashlib.sha256(b).hexdigest()
base_path=H/'native-service-attempt2.json';base=json.loads(base_path.read_text(encoding='utf8'))
raw=(H/'native-service-attempt2-server-end-ui.txt').read_bytes()
match=re.search(r'\[NEW_APP_NATIVE_SERVER_END\] '+base['run']+r' (\{.*\}) nil',raw.decode('utf8'));assert match
full=json.loads(match[1]);assert all(full[key]==value for key,value in base['server_summary_available_fields'].items())
assert full['providerActive']==0 and full['phase']=='closed' and full['accountGate']['scopes']==0
assert full['run']==base['run'] and full['checks']==base['server_checks'] and len(full['owners'])==7
expected=dict(run=base['run'],base_result_sha256=sha(base_path.read_bytes()),ui_output_sha256=sha(raw),source='bounded Studio Output accessibility text',complete_fields_match_log_prefix=True,server_summary=full,replacementClosed_is_not_general_Session_closed=True)
assert json.loads((H/'native-service-attempt2-output-supplement.json').read_text(encoding='utf8'))==expected
print('Complete Studio Output summary matches retained log prefix and result hashes.')
