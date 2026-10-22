from pathlib import Path
import argparse,hashlib,json,re
HERE=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--log',required=True);a=p.parse_args()
m=json.loads((HERE/'prepared-native-manifest.json').read_text(encoding='utf8'))
lines=Path(a.log).read_text(encoding='utf8').splitlines()
guard='[NATIVE_SPATIAL_GUARD] '+m['source']+' 223 persistence_disabled'
start=[i for i,l in enumerate(lines) if guard in l and ' > ' not in l][-1]
end=[i for i,l in enumerate(lines) if i>start and '[NATIVE_SPATIAL_PASS]' in l]
assert len(end)==1
span=lines[start:end[0]+1]
assert not any('[NATIVE_SPATIAL_FAIL]' in l or '[FLog::CreatorError]' in l for l in span)
rows=[l.split('[FLog::CreatorOutput] ',1)[1] for l in span if '[FLog::CreatorOutput]' in l and '[NATIVE_SPATIAL_' in l and ' > ' not in l]
text='\n'.join(rows)+'\n';run=re.search(r'\[NATIVE_SPATIAL_PASS\] (\d+) 20',text)
assert run and len(rows)==8
for name in ['nan','positive_inf','negative_inf','plain_xyz','empty_table']:
 assert '[NATIVE_SPATIAL_CASE] '+run[1]+' '+name+' refused_unchanged' in text
(HERE/'native-output.txt').write_text(text,encoding='utf8',newline='\n')
receipt=dict(source=m['source'],run=run[1],assertions=20,scripts=223,creator_errors=0,
 persistence_disabled=True,place_sha256=m['place_sha256'],output_sha256=hashlib.sha256(text.encode()).hexdigest(),
 scope='Actual-client checkpoint objects; synthetic corrupted copies; no persistent writes, arbitrary-state resume or complete spatial-field audit',published=False)
(HERE/'native-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(receipt,indent=2))
