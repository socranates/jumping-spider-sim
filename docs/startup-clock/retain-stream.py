"""Retain bounded capture provenance without copying the large native trace."""
from pathlib import Path
import hashlib,json,re,subprocess
H=Path(__file__).resolve().parent/'stream-full1'
stage=Path('C:/Users/natha/claude-xfer/Windowsill-startup-stream-full2')
log=Path('C:/Users/natha/AppData/Local/Roblox/logs/0.744.0.7441077_20261024T122402Z_Studio_74F14_last.log')
raw=Path('C:/Users/natha/AppData/Local/Roblox/logs/microprofile-20261024-072700-SillStart1.x.html')
sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((stage/'manifest.json').read_text())
assert sha(Path(m['place']).read_bytes())==m['place_sha256']
lines=[];events={}
for line in log.read_text(encoding='utf8').splitlines():
 if re.search(r'\[FLog::CreatorOutput\] \[LIBMP_(CAPABILITY|STREAM_START|STREAM_STOP)\]',line):
  match=re.search(r'\[LIBMP_(\w+)\]\s+(\{.*\})$',line);assert match
  assert match[1]not in events
  events[match[1]]=json.loads(match[2]);lines.append(line)
assert set(events)=={'CAPABILITY','STREAM_START','STREAM_STOP'}
assert all(events['CAPABILITY'][k]for k in ['accessible','compatible','ready'])
assert events['STREAM_START']['accepted']and events['STREAM_STOP']['accepted']
assert events['STREAM_STOP']['before']['Active']and events['STREAM_STOP']['before']['RecordedSizeKb']>0
(H/'capture-output.txt').write_text('\n'.join(lines)+'\n')
for name in ['compile.txt','strict.txt']:(H/name).write_bytes((stage/name).read_bytes())
failed=Path('C:/Users/natha/claude-xfer/Windowsill-startup-stream-full1/strict.txt')
(H/'sdk-strict-first.txt').write_bytes(failed.read_bytes())
R=Path(__file__).resolve().parents[2]
for rel,digest in m['original_sources'].items():
 assert sha((R/'roblox_port/src'/rel).read_bytes().replace(b'\r\n',b'\n'))==digest
receipt=dict(raw_path=str(raw),raw_bytes=raw.stat().st_size,raw_sha256=sha(raw.read_bytes()),
 model_sha256=m['place_sha256'],matched_ordinary_sources=273,events=events,
 sdk_source='https://github.com/Roblox/libmp/releases/download/latest/LibMP.luau',
 sdk_sha256=m['microprofiler_sdk_sha256'],sdk_python_archive_sha256='6e8ebe95583620b05cc60dc73db14b5d0c1c5987a74aac024909771583594fdd',
 sdk_docs_commit='23573b949ed027fdf8820f969bea525b96c357cc',wasmtime_version='38.0.0',
 staged_compile_sources=277,strict_sources=276,strict_sdk_excluded=True,published=False,
 limits='One local Studio file stream. Additional SDK module replicated but not imported by game scripts. It is loaded in Edit before capture. Closed scopes and incomplete frames do not prove exhaustive exclusive CPU attribution. No ordinary game source change or Player/mobile performance claim.')
(H/'capture.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({k:receipt[k]for k in ['raw_bytes','raw_sha256','model_sha256','matched_ordinary_sources']}))
