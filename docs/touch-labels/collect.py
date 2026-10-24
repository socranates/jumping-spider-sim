"""Bind the complete bounded native rows to the one-line candidate and CLI run."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,sys,xml.etree.ElementTree as ET
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
STAGE=Path('C:/Users/natha/claude-xfer/Windowsill-touch-font-attempt1')
BASE=Path('C:/Users/natha/claude-xfer/Windowsill-menu-overflow-attempt1')
LOG=Path('C:/Users/natha/AppData/Local/Roblox/logs/0.744.0.7441077_20261024T050247Z_Studio_446EA_last.log')
sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
subprocess.run([sys.executable,str(H/'prepare.py'),'--check'],check=True)
manifest=json.loads((STAGE/'manifest.json').read_text());old=json.loads((BASE/'manifest.json').read_text())
model=Path(manifest['place']);assert sha(model.read_bytes())==manifest['place_sha256']
assert manifest['source_count']==273 and not manifest['diagnostics']
changed=[k for k in manifest['sources']if manifest['sources'][k]!=old['sources'][k]]
assert changed==['StarterPlayer.StarterPlayerScripts.Client.SpiderInput']
before=(BASE/'roblox_port/src/Client/SpiderInput.luau').read_text()
after=(STAGE/'roblox_port/src/Client/SpiderInput.luau').read_text()
anchor='\t\tb.TextSize = textSize or 18\n'
assert after==before.replace(anchor,anchor+'\t\tb.Font = Enum.Font.GothamMedium\n')
assert after==(H/'spider-input.luau').read_text()
actual={}
def walk(node,parent=''):
 props=node.find('Properties');name=props.findtext("string[@name='Name']");path=parent+'.'+name if parent else name
 source=props.find("*[@name='Source']")
 if source is not None:actual[path]=sha((source.text or '').replace('\r\n','\n').encode())
 for child in node.findall('Item'):walk(child,path)
for node in ET.parse(model).getroot().findall('Item'):walk(node)
assert actual==manifest['sources']
assert (STAGE/'compile.txt').read_text().strip()=='compile 273/273'
assert 'TypeError:'not in (STAGE/'strict.txt').read_text()
lines=LOG.read_text(encoding='utf8',errors='replace').splitlines();messages=[]
for index,line in enumerate(lines):
 if '[FLog::CreatorOutput] 'in line:messages.append((index,line.split('[FLog::CreatorOutput] ',1)[1],line))
begins=[(i,re.fullmatch(r'\[TOUCH_FONT_BEGIN\]\s+(\d+)\s+bounded_rows_not_one_truncated_message',m))for i,m,_ in messages]
begins=[(i,m.group(1))for i,m in begins if m];assert len(begins)==1
begin,tag=begins[0];rows={};live={};ends=[];raw=[];guards=[];posts=[];cleanups=[]
for i,message,line in messages:
 if message.startswith('[INTEGRATED_PLAYABLE_GUARD]'):
  assert re.fullmatch(r'\[INTEGRATED_PLAYABLE_GUARD\]\s+273\s+clean_unbound_candidate_no_diagnostics',message)
  guards.append(i);raw.append(line)
 if message.startswith('[TOUCH_FONT_POST]'):
  assert re.fullmatch(r'\[TOUCH_FONT_POST\]\s+0\s+0\s+source_unchanged',message);posts.append(i);raw.append(line)
 if message.startswith('[TOUCH_FONT_CLEANUP]'):cleanups.append(i);raw.append(line)
 if message.startswith('[TOUCH_FONT_BEGIN]'):raw.append(line)
 m=re.fullmatch(r'\[TOUCH_FONT_(ROW|LIVE)\]\s+'+tag+r'\s+(\d+)\s+(\{.*\})',message)
 if m:
  target=rows if m.group(1)=='ROW'else live;key=int(m.group(2));assert key not in target
  target[key]=json.loads(m.group(3));assert len(line.encode())<1000;raw.append(line)
 m=re.fullmatch(r'\[TOUCH_FONT_END\]\s+'+tag+r'\s+(\{.*\})',message)
 if m:ends.append((i,json.loads(m.group(1))));raw.append(line)
assert set(rows)==set(range(1,81))and set(live)==set(range(1,17))and len(ends)==1
end,summary=ends[0]
assert summary==dict(rows=80,live=16,problems=0,reproduced=13,fixture_only=True)
assert len(guards)==2 and guards[0]<begin<end<guards[1]and posts==[guards[1]+1]
assert len(cleanups)==1 and end<cleanups[0]<guards[1]
candidate=[r for r in rows.values()if not r['legacy']];legacy=[r for r in rows.values()if r['legacy']]
case=lambda r:(r['action'],r['text'],r['short'])
assert len(candidate)==len(legacy)==40 and {case(r)for r in candidate}=={case(r)for r in legacy}
assert len({case(r)for r in candidate})==40
assert all(r['okay']and r['text_fits']and r['no_extra_rows']and r['font']=='Enum.Font.GothamMedium'for r in candidate)
assert sum(not r['okay']for r in legacy)==13
assert len({r['action']for r in live.values()})==16 and all(r['font']=='Enum.Font.GothamMedium'for r in live.values())
receipt_path=ROOT/'docs/integrated-release/touch-font1-receipt.json';receipt=json.loads(receipt_path.read_text());assert receipt['all_passed']and not receipt['full']
assert receipt['inputs']=={f.relative_to(STAGE/'roblox_port/src').as_posix():sha(f.read_bytes())for f in (STAGE/'roblox_port/src').rglob('*.luau')}
assert receipt['requested']==['settings.luau','client_smoke.luau','run.luau','hud.luau']
inputs={}
def bind(path):inputs[path.relative_to(ROOT).as_posix()]=sha(path.read_bytes())
total=0
for row in receipt['results']:
 path=ROOT/'docs/integrated-release'/row['output'];data=path.read_bytes();bind(path)
 assert row['exit_code']==0 and sha(data)==row['output_sha256']
 counts=re.findall(r'passed=(\d+) failed=(\d+)',data.decode());assert counts and all(int(n)==0 for _,n in counts)
 total+=sum(int(n)for n,_ in counts)
assert total==1489
bind(receipt_path)
for name in ['prepare.py','build.py','derivation.json','spider-input.luau','native-check.luau','show-result.luau','cleanup.luau','collect.py',
 'guard-before.png','guard-after.png','native-comparison.png','ordinary-entry.png','actions.json']:bind(H/name)
errors=[line for line in lines if '[FLog::CreatorError]'in line];assert not errors
warnings=[line for line in lines if '[FLog::CreatorWarning]'in line]
result=dict(run=tag,model_sha256=manifest['place_sha256'],manifest_sha256=sha((STAGE/'manifest.json').read_bytes()),
 source_count=273,changed_source=changed[0],native_rows=[rows[i]for i in sorted(rows)],runtime_buttons=[live[i]for i in sorted(live)],
 summary=summary,passed=1489,failed=0,targeted_suites=4,log_path=str(LOG),log_sha256=sha(LOG.read_bytes()),
 creator_errors=0,creator_warning_count=len(warnings),expected_unbound_no_api=True,
 warning_counts=dict(unbound_store=sum('DataStore unavailable; this visit cannot save'in s for s in warnings),
 local_config_load=sum('403: DataStore service unavailable'in s for s in warnings),
 session_only=sum('session-only: load_failed'in s for s in warnings),
 asset_type=sum('203785492'in s for s in warnings),style=sum('StyleRule'in s for s in warnings)),
 initial_single_message_truncated=True,source_guards_before_after=True,ordinary_new_life_observed=True,
 ordinary_touch_visibility_forced=False,physical_phone=False,performance_measured=False,production_activated=False,published=False,goal_complete=False,inputs=inputs)
outputs={'native-font.json':(json.dumps(result,indent=2)+'\n').encode(),'native-output.txt':('\n'.join(raw)+'\n').encode()}
for name,data in outputs.items():
 if a.check:assert (H/name).read_bytes()==data
 else:assert not (H/name).exists();(H/name).write_bytes(data)
print(json.dumps(dict(run=tag,candidate_cases=40,candidate_failures=0,legacy_failures=13,targeted_passed=1489)))
