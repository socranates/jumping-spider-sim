"""Retain bounded viewer exports; raw Studio HTML/platform inventory stays local."""
from pathlib import Path
import csv,hashlib,json
H=Path(__file__).resolve().parent;D=Path('C:/Users/natha/Downloads')
L=Path('C:/Users/natha/AppData/Local/Roblox/logs')
sha=lambda b:hashlib.sha256(b).hexdigest()
captures=[]
for name,rawfile,expected in [
 ('client','microprofile-20261024-071325.html',128),
 ('server','log_C6C23_microprofile_20261024-070906.html',60)]:
 source=D/(name+'_summary (1).json');data=json.loads(source.read_text())
 assert data['num_frames']==expected
 # Keep display context and curated timing values, omit machine identifiers.
 platform=data.pop('platform_info')
 data['display_context']={k:platform[k]for k in ['Build','Version','DisplaySize','DrawSize','QualityLevel']}
 (H/(name+'-summary.json')).write_text(json.dumps(data,indent=2)+'\n')
 marker=D/(name+' (1).csv');rows=list(csv.reader(marker.read_text().splitlines()))
 assert rows[0][0]=='frames'and rows[1]==['name','group','average','max','callaverage']
 # First table is aggregate timings; later tables contain raw frame events.
 aggregate=[]
 for r in rows[2:]:
  if not r:break
  assert len(r)==5
  aggregate.append(r)
 timed=[r for r in aggregate if float(r[2])>0]
 timed.sort(key=lambda r:float(r[2]),reverse=True)
 with (H/(name+'-markers-top100.csv')).open('w',newline='')as f:
  writer=csv.writer(f);writer.writerows(rows[:2]+timed[:100])
 captures.append(dict(kind=name,raw_path=str(L/rawfile),raw_sha256=sha((L/rawfile).read_bytes()),
  raw_bytes=(L/rawfile).stat().st_size,summary_download=str(source),summary_sha256=sha(source.read_bytes()),
  frames=data['num_frames'],marker_aggregate_frames=int(rows[0][1]),
  marker_download=str(marker),marker_sha256=sha(marker.read_bytes()),aggregate_marker_rows=len(aggregate),
  limits='Post-PASS local Studio rainy-garden endpoint; native profiler/console UI interaction nearby. Not a paired performance benchmark or an isolated production server. Marker CSV aggregate window differs from dump frame count.'))
record=dict(captures=captures,fresh_server_request=True,server_isolation_qualified=False,
 native_run='1792843345517',published=False,
 limits='Fresh unpaused Server-tab request and later paused client dump in the same local Studio process. Frame summaries differ but several timer totals/maxima repeat exactly; aggregate independence is not established. Scope timers nest and aliases overlap; Sleep is not busy CPU. Do not sum labels or attribute end-to-end savings.')
(H/'profiles.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps([dict(kind=x['kind'],frames=x['frames'],marker_frames=x['marker_aggregate_frames'])for x in captures]))
