"""Collect one completed real-engine self-test, excluding unrelated log data."""
from pathlib import Path
import argparse,hashlib,json,re
H=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--log',type=Path,required=True);p.add_argument('--check',action='store_true');a=p.parse_args()
raw=a.log.read_bytes();text=raw.decode('utf8',errors='replace');rows=[];messages=[];warnings=[];guards=[]
for line in text.splitlines():
 if '[FLog::CreatorWarning]'in line or '[FLog::CreatorError]'in line:
  safe=re.sub(r'\bt\d+_\d+\b','<synthetic-test-key>',line)
  safe=re.sub(r'(https?://[^\s?]+)\?[^\s]+',r'\1?<query omitted>',safe)
  warnings.append(safe)
 if '[FLog::CreatorOutput]'not in line or '] > 'in line:continue
 match=re.search(r'\[SELFTEST\]\s+(.*)$',line)
 if match:rows.append(line);messages.append(match[1])
 elif '[INTEGRATED_NATIVE_FIXTURE]'in line or '[INTEGRATED_NATIVE_POST]'in line or '[ISOLATED_PLAYER_GUARD] 274 'in line:
  guards.append(line)
assert sum(s.startswith('BEGIN ')for s in messages)==1
ends=[s for s in messages if s.startswith('END ')];assert len(ends)==1
match=re.fullmatch(r'END pass=(\d+) fail=(\d+) skip=(\d+)',ends[0]);assert match
counts=dict(zip(['pass','fail','skip'],map(int,match.groups())))
names={kind:[s[len(kind)+1:]for s in messages if s.startswith(kind+' ')]for kind in ['PASS','FAIL','SKIP']}
assert all(len(names[k.upper()])==v for k,v in counts.items())
assert any('INFO world: preserve (revision preserve-3)'==s for s in messages)
assert not any('scope: selected' in s for s in messages)
assert any('[INTEGRATED_NATIVE_FIXTURE]'in s for s in guards)and any('[INTEGRATED_NATIVE_POST]'in s for s in guards)
fixture=json.loads((H/'fixture.json').read_text());sha=lambda b:hashlib.sha256(b).hexdigest()
output=('\n'.join(guards+rows)+'\n').encode()
record=dict(log_sha256=sha(raw),output_sha256=sha(output),fixture_sha256=sha((H/'fixture.json').read_bytes()),
 counts=counts,names=names,complete=True,all_passed=counts=={'pass':fixture['expected_checks'],'fail':0,'skip':0},
 info=[s for s in messages if s.startswith('INFO ')],warnings=warnings,
 published=False,standalone_player=False,natural_full_lifecycle_proved=False,whole_map_visual_sweep_proved=False)
out=H/'attempt1-output.txt';target=H/'attempt1-receipt.json'
if a.check:assert out.read_bytes()==output and json.loads(target.read_text())==record
else:
 if out.exists():assert out.read_bytes()==output
 out.write_bytes(output);target.write_bytes((json.dumps(record,indent=2)+'\n').encode())
print(json.dumps(dict(counts=counts,complete=True,all_passed=record['all_passed'],warnings=len(warnings))))
