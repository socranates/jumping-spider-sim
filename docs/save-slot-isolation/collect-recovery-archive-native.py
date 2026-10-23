from pathlib import Path
import argparse,hashlib,json,re
HERE=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--log',required=True);a=p.parse_args()
m=json.loads((HERE/'prepared-recovery-archive-native-manifest.json').read_text())
lines=Path(a.log).read_text(encoding='utf8').splitlines()
guard='[NATIVE_RECOVERY_ARCHIVE_GUARD] '+m['source']+' 224 persistence_disabled'
start=[i for i,line in enumerate(lines) if guard in line and ' > ' not in line][-1]
end=[i for i,line in enumerate(lines) if i>start and '[NATIVE_RECOVERY_ARCHIVE_PASS]' in line and ' > ' not in line]
assert len(end)==1;span=lines[start:end[0]+1]
assert not any('[NATIVE_RECOVERY_ARCHIVE_FAIL]' in line or '[FLog::CreatorError]' in line for line in span)
rows=[line.split('[FLog::CreatorOutput] ',1)[1] for line in span if '[FLog::CreatorOutput]' in line and ('[NATIVE_RECOVERY_ARCHIVE_' in line or 'RECOVERY_ARCHIVE passed=' in line) and ' > ' not in line]
text='\n'.join(rows)+'\n';match=re.search(r'\[NATIVE_RECOVERY_ARCHIVE_PASS\] (\d+) 82',text)
assert match and len(rows)==4 and 'RECOVERY_ARCHIVE passed=73 failed=0 suspensions=16' in text
(HERE/'recovery-archive-native-output.txt').write_text(text,encoding='utf8',newline='\n')
receipt=dict(source=m['source'],run=match[1],assertions=82,scripts=224,creator_errors=0,persistence_disabled=True,candidate_sha256=m['candidate_sha256'],place_sha256=m['place_sha256'],output_sha256=hashlib.sha256(text.encode()).hexdigest(),production_changed=False,durable_archive_implemented=False,progress_import_implemented=False,scope=m['scope'])
(HERE/'recovery-archive-native-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(receipt,indent=2))
