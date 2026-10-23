from pathlib import Path
import argparse,hashlib,json,re
HERE=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--log',required=True);a=p.parse_args()
m=json.loads((HERE/'prepared-pond-batch-manifest.json').read_text(encoding='utf8'))
lines=Path(a.log).read_text(encoding='utf8').splitlines()
guard='[NATIVE_POND_BATCH_GUARD] '+m['source']+' 224 persistence_disabled'
start=[i for i,line in enumerate(lines) if guard in line and ' > ' not in line][-1]
end=[i for i,line in enumerate(lines) if i>start and '[NATIVE_POND_BATCH_PASS]' in line]
assert len(end)==1
span=lines[start:end[0]+1]
assert not any('[NATIVE_POND_BATCH_FAIL]' in line or '[FLog::CreatorError]' in line for line in span)
rows=[line.split('[FLog::CreatorOutput] ',1)[1] for line in span if '[FLog::CreatorOutput]' in line and '[NATIVE_POND_BATCH_' in line and ' > ' not in line]
text='\n'.join(rows)+'\n';passed=re.search(r'\[NATIVE_POND_BATCH_PASS\] (\d+) 41',text)
assert passed and len(rows)==11;run=passed[1];pairs=[]
for line in rows:
 fields=line.split()
 if fields[0]!='[NATIVE_POND_BATCH_PAIR]':continue
 assert fields[1]==run
 pairs.append(dict(tier=fields[2],pair=int(fields[3]),order=fields[4],calls=int(fields[5]),
  reference_cpu_ms=float(fields[6]),candidate_cpu_ms=float(fields[7]),reference_positive_heap_kb=float(fields[8]),
  candidate_positive_heap_kb=float(fields[9]),reference_worst_call_ms=float(fields[10]),candidate_worst_call_ms=float(fields[11])))
assert len(pairs)==8 and all(row['calls']==120 for row in pairs)
summaries={}
for tier in ['full','low']:
 group=[row for row in pairs if row['tier']==tier]
 assert [row['pair'] for row in group]==[1,2,3,4] and [row['order'] for row in group]==['AB','BA','AB','BA']
 a_cpu=sum(row['reference_cpu_ms'] for row in group);b_cpu=sum(row['candidate_cpu_ms'] for row in group)
 a_heap=sum(row['reference_positive_heap_kb'] for row in group);b_heap=sum(row['candidate_positive_heap_kb'] for row in group)
 summaries[tier]=dict(reference_cpu_ms=a_cpu,candidate_cpu_ms=b_cpu,component_cpu_reduction_percent=(1-b_cpu/a_cpu)*100,
  reference_positive_heap_kb=a_heap,candidate_positive_heap_kb=b_heap,positive_heap_reduction_percent=(1-b_heap/a_heap)*100,
  pairs_faster=sum(row['candidate_cpu_ms']<row['reference_cpu_ms'] for row in group))
(HERE/'pond-batch-output.txt').write_text(text,encoding='utf8',newline='\n')
r=dict(source=m['source'],run=run,scripts=224,assertions=41,creator_errors=0,persistence_disabled=True,
 place_sha256=m['place_sha256'],output_sha256=hashlib.sha256(text.encode()).hexdigest(),pairs=pairs,summaries=summaries,
 scope='Counterbalanced contiguous120-frame batches, one controlled draw per timed frame on the same pose sequences, full/low; original985 native equivalence checks retained separately. Positive heap growth is not allocation rate or leak proof; no whole-game FPS claim.',
 adopted=False,published=False)
r['adoption_criteria_met']=all(v['component_cpu_reduction_percent']>=10 and v['positive_heap_reduction_percent']>=15 and v['pairs_faster']>=3 for v in summaries.values())
r['candidate_faster_only_when_second']=all((row['candidate_cpu_ms']<row['reference_cpu_ms'])==(row['order']=='AB') for row in pairs)
(HERE/'pond-batch-receipt.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
