from pathlib import Path
import argparse,hashlib,json,re,statistics,xml.etree.ElementTree as ET
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
p=argparse.ArgumentParser();p.add_argument('--log',required=True);a=p.parse_args()
text=Path(a.log).read_text(encoding='utf8',errors='replace')
assert '[WASP_REUSE_NATIVE_FAIL]' not in text and '[FLog::CreatorError]' not in text
m=re.search(r'\[WASP_REUSE_NATIVE_RESULT\]\s+(\{[^\n]+\})',text);assert m,'Native trial is not complete'
result=json.loads(m[1]);result['rows']=[json.loads(row) for row in re.findall(r'\[WASP_REUSE_NATIVE_ROW\]\s+(\{[^\n]+\})',text)];manifest=json.loads((H/'native-package.json').read_text())
assert result['source']==manifest['source'] and result['focus_losses']==0 and result['width']>=320 and result['height']>=180
assert '[WASP_REUSE_NATIVE_PASS] '+str(result['checks']) in text and result['checks']>100000
assert hashlib.sha256(Path(manifest['place']).read_bytes()).hexdigest()==manifest['place_sha256']
for name,digest in manifest['inputs'].items():assert hashlib.sha256((H/name).read_bytes()).hexdigest()==digest
xml=ET.parse(manifest['place']);sources={}
for item in xml.getroot().iter('Item'):
 props=item.find('Properties')
 if props is None:continue
 code=props.find("*[@name='Source']")
 if code is not None:sources[props.findtext("string[@name='Name']")]=(code.text or '').replace('\r\n','\n')
for name,path in [('Original',H/'reference.luau'),('Candidate',H/'candidate.luau'),('WaspLook',ROOT/'roblox_port/src/Shared/Data/WaspLook.luau'),('Shapes',ROOT/'roblox_port/src/Shared/Habitat/Shapes.luau')]:assert sources[name]==path.read_text()
summaries={};adopt=True
assert len(result['rows'])==16 and result['calls_per_batch']==360
for mode in ['flying','holding','walking','alternating']:
 rows=[r for r in result['rows'] if r['mode']==mode];assert {r['pair'] for r in rows}=={1,2,3,4}
 ratios=[r['candidate_ms']/r['original_ms'] for r in rows]
 assert all(r['original_ms']>0 and r['candidate_ms']>0 for r in rows)
 reduction=(1-statistics.median(ratios))*100
 passed=(reduction>=10 and all(x<1 for x in ratios)) if mode in ['flying','holding'] else statistics.median(ratios)<=1.05
 summaries[mode]=dict(median_cpu_reduction_percent=reduction,pairs_faster=sum(x<1 for x in ratios),threshold_passed=passed)
 adopt=adopt and passed
events='\n'.join(line for line in text.splitlines() if 'WASP_REUSE_NATIVE_' in line)+'\n'
(H/'native-events.txt').write_text(events,encoding='utf8',newline='\n')
receipt=dict(source=result['source'],result=result,summary=summaries,adoption_thresholds_passed=adopt,events_sha256=hashlib.sha256(events.encode()).hexdigest(),place_sha256=manifest['place_sha256'],native_geometry_verified=True,production_changed=False,whole_game_fps_verified=False,published=False)
(H/'native-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(summaries,indent=2));print('adoption thresholds passed:',adopt)
