"""Read-only optimistic connectivity bound on drawn-block merging.
No boxes are changed. Includes unsafe names/materials intentionally: this can only OVERestimate safe merging.
"""
from pathlib import Path
from collections import defaultdict
import json,hashlib,gzip
ROOT=Path(__file__).resolve().parent
raw=(ROOT/'records.txt').read_bytes() if (ROOT/'records.txt').exists() else gzip.decompress((ROOT/'records.txt.gz').read_bytes());regions=[];totals={t:defaultdict(int) for t in ['full','low']}
for line in raw.decode('utf-8-sig').splitlines():
 if not line.startswith('{'):continue
 row=json.loads(line);groups=defaultdict(list);eligible=0
 for d in row['records']:
  if d.get('shape') is not None or d.get('turn') is not None or d.get('dew') is not None:continue
  # Preserve nil versus explicit defaults, and compare color components rather than shim tables.
  key=json.dumps([d.get(k) for k in ['color','material','transparency','reflectance','shadow','group','full','far']],separators=(',',':'))
  lo=[a-s*.5 for a,s in zip(d['at'],d['size'])];hi=[a+s*.5 for a,s in zip(d['at'],d['size'])]
  groups[key].append((lo,hi,d['id']));eligible+=1
 reductions=0;pairs=0;rect_pairs=0;neighbours=set()
 for boxes in groups.values():
  boxes.sort(key=lambda b:(b[0][0],b[2]));parent=list(range(len(boxes)))
  def find(i):
   while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
   return i
  for i,(lo,hi,name) in enumerate(boxes):
   for j in range(i+1,len(boxes)):
    ol,oh,oname=boxes[j]
    if ol[0]>hi[0]+.001:break
    if all(ol[k]<=hi[k]+.001 and lo[k]<=oh[k]+.001 for k in range(3)):
     pairs+=1;neighbours.update([name,oname]);a,b=find(i),find(j)
     if a!=b:parent[b]=a;reductions+=1
     # A legal initial pair also shares two complete spans. Components may include much more than rectangles.
     if sum(abs(lo[k]-ol[k])<=.001 and abs(hi[k]-oh[k])<=.001 for k in range(3))>=2:rect_pairs+=1
 n=len(row['records']);result={'region':row['region'],'kind':row['kind'],'tier':row['tier'],'before':n,'eligible':eligible,'same_key_touch_pairs':pairs,'initial_rectangular_pairs':rect_pairs,'records_with_neighbour':len(neighbours),'optimistic_max_removed':reductions,'optimistic_min_after':n-reductions}
 regions.append(result)
 for k in ['before','eligible','same_key_touch_pairs','initial_rectangular_pairs','records_with_neighbour','optimistic_max_removed']:totals[row['tier']][k]+=result[k]
summary={}
for tier,r in totals.items():
 r=dict(r);r['optimistic_percent_removed']=100*r['optimistic_max_removed']/r['before'];r['optimistic_min_after']=r['before']-r['optimistic_max_removed'];summary[tier]=r
nonpatch={}
for tier in ['full','low']:
 values=[v for v in regions if v['tier']==tier and v['kind']!='patch'];n=sum(v['before'] for v in values);m=sum(v['optimistic_max_removed'] for v in values)
 nonpatch[tier]={'before':n,'optimistic_max_removed':m,'optimistic_min_after':n-m,'optimistic_percent_removed':100*m/n}
report={'source_runtime':'14e60991c785c4293c3560e6d8b7ecded7e7ac75','records_sha256':hashlib.sha256(raw).hexdigest(),'regions':len(regions)//2,'scope':'all preserve Region.decor / LookPlan records including backdrop and near-detail patches; excludes persistent sill decor and collision parts','method':'same-key plain blocks, no turn or dew; epsilon .001; touching/overlapping AABB connectivity is a deliberately generous upper bound, even allowing edge/corner contact and nonrectangular components; ignores name/animation/material-grain exclusions','summary':summary,'excluding_near_detail_patches':nonpatch,'under_ten_percent_even_optimistically':all(r['optimistic_percent_removed']<10 for r in [*summary.values(),*nonpatch.values()]),'per_region':regions}
(ROOT/'estimate.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:report[k] for k in ['regions','summary','under_ten_percent_even_optimistically']},indent=2))
