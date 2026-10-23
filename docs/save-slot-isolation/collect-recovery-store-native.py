from pathlib import Path
import argparse,hashlib,json,re
HERE=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--log',required=True);a=p.parse_args()
m=json.loads((HERE/'prepared-recovery-store-native-manifest.json').read_text())
lines=Path(a.log).read_text(encoding='utf8').splitlines();guard='[NATIVE_RECOVERY_STORE_GUARD] '+m['source']+' 226 production_scripts_disabled'
start=[i for i,line in enumerate(lines) if guard in line and ' > ' not in line][-1]
end=[i for i,line in enumerate(lines) if i>start and '[NATIVE_RECOVERY_STORE_PASS]' in line and ' > ' not in line]
assert len(end)==1;span=lines[start:end[0]+1]
assert not any('[NATIVE_RECOVERY_STORE_FAIL]' in line or '[FLog::CreatorError]' in line for line in span)
rows=[line.split('[FLog::CreatorOutput] ',1)[1] for line in span if '[FLog::CreatorOutput]' in line and any(s in line for s in ['[NATIVE_RECOVERY_STORE_','RECOVERY_ARCHIVE_STORE passed=','FRESH_RAW_READ passed=']) and ' > ' not in line]
text='\n'.join(rows)+'\n';match=re.search(r'\[NATIVE_RECOVERY_STORE_PASS\] (\d+) 304',text)
assert match and len(rows)==5 and 'RECOVERY_ARCHIVE_STORE passed=272 failed=0' in text and 'FRESH_RAW_READ passed=32 failed=0' in text
(HERE/'recovery-store-native-output.txt').write_text(text,encoding='utf8',newline='\n')
r=dict(source=m['source'],run=match[1],assertions=304,scripts=226,creator_errors=0,production_scripts_disabled=True,place_sha256=m['place_sha256'],candidates=m['candidates'],output_sha256=hashlib.sha256(text.encode()).hexdigest(),production_changed=False,real_datastore_verified=False,progress_import_implemented=False,scope=m['scope'])
(HERE/'recovery-store-native-receipt.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
