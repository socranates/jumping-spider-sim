"""Collect only a guarded, terminal successful server-memory fixture."""
from pathlib import Path
import argparse,hashlib,json,re
H=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--log',required=True);a=p.parse_args()
manifest=json.loads((H/'prepared-recovery-idle-native-manifest.json').read_text(encoding='utf8'))
assert manifest['production_scripts_disabled'] and len(manifest['scripts'])==245
assert hashlib.sha256(Path(manifest['place']).read_bytes()).hexdigest()==manifest['place_sha256']
for name,digest in manifest['candidates'].items():assert hashlib.sha256((H/name).read_bytes()).hexdigest()==digest
text=Path(a.log).read_text(encoding='utf8');lines=text.splitlines()
events=[line for line in lines if re.search(r'\[FLog::Creator(?:Output|Warning)\] (?:Warning: )?\[RECOVERY_IDLE_NATIVE_(?:GUARD|BEGIN|PASS|FAIL)\]',line)]
guard=[s for s in events if '[RECOVERY_IDLE_NATIVE_GUARD]' in s];begin=[s for s in events if '[RECOVERY_IDLE_NATIVE_BEGIN]' in s];passed=[s for s in events if '[RECOVERY_IDLE_NATIVE_PASS]' in s]
assert len(guard)==len(begin)==len(passed)==1 and not any('[RECOVERY_IDLE_NATIVE_FAIL]' in s for s in events)
assert manifest['source']+' 245 production_scripts_disabled' in guard[0]
run=re.search(r'\[RECOVERY_IDLE_NATIVE_BEGIN\] (\d+)',begin[0]).group(1)
match=re.search(r'\[RECOVERY_IDLE_NATIVE_PASS\] (\d+) (\d+) memory_backend_only',passed[0]);assert match and match[1]==run and int(match[2])==22
start=text.index(guard[0]);end=text.index(passed[0])+len(passed[0]);assert start<text.index(begin[0])<end
assert '[FLog::CreatorError]' not in text[start:end]
output='\n'.join(events)+'\n';(H/'recovery-idle-native-events.txt').write_text(output,encoding='utf8',newline='\n')
result=dict(source=manifest['source'],run=run,assertions=22,script_fingerprints=245,production_scripts_disabled=True,backend='MemoryBackend',controlled_terminal_metadata=True,actual_discovery_pipeline_native_verified=False,place_sha256=manifest['place_sha256'],manifest_sha256=hashlib.sha256((H/'prepared-recovery-idle-native-manifest.json').read_bytes()).hexdigest(),events_sha256=hashlib.sha256(output.encode()).hexdigest(),log=str(Path(a.log)),creator_errors=0,real_datastore_verified=False,natural_gameplay_verified=False,published=False)
(H/'recovery-idle-native-receipt.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
