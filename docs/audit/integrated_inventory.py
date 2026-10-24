"""Index the exact staged candidate; lexical matches are not coverage claims."""
from pathlib import Path
import argparse,hashlib,json,re,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[2]
STAGE=Path('C:/Users/natha/claude-xfer/Windowsill-menu-overflow-attempt1')
OUT=Path(__file__).resolve().parent/'integrated-source'
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
sha=lambda b:hashlib.sha256(b).hexdigest()
manifest=json.loads((STAGE/'manifest.json').read_text());SRC=STAGE/'roblox_port/src';TESTS=STAGE/'roblox_port/tests'
assert sha(Path(manifest['place']).read_bytes())==manifest['place_sha256']
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
def model_name(rel):
 parts=Path(rel).parts
 return '.'.join([prefix[parts[0]],*parts[1:-1],parts[-1][:-5].removesuffix('.server').removesuffix('.client')])
files={f.relative_to(SRC).as_posix():f.read_bytes()for f in sorted(SRC.rglob('*.luau'))}
assert len(files)==273 and {model_name(k):sha(v.replace(b'\r\n',b'\n'))for k,v in files.items()}==manifest['sources']
names={}
for rel in files:names.setdefault(Path(rel).name.removesuffix('.luau'),[]).append(rel)
test_text={f.name:f.read_text(encoding='utf8')for f in sorted(TESTS.glob('*.luau'))}
direct={rel:[]for rel in files}
for name,text in test_text.items():
 for match in re.finditer(r'require\("\.\./src/([^"\n]+)"\)',text):
  rel=match[1]+'.luau'
  if rel in direct and name not in direct[rel]:direct[rel].append(name)
runtime_pattern=re.compile(r'BindToRenderStep|RenderStepped|Heartbeat|Stepped:|\bwhile\s|task\.(wait|spawn|delay)|RemoteEvent|RemoteFunction|FireServer|FireClient|OnServerEvent|OnClientEvent|GetDataStore|GetRequestBudgetForRequestType|UpdateAsync|GetAsync|SetAsync|Instance\.new|:Connect\(')
records=[];runtime=[];ambiguous=[]
for rel,data in files.items():
 text=data.decode('utf8');lines=text.splitlines();dependencies=set();unresolved=[]
 for n,line in enumerate(lines,1):
  if line.lstrip().startswith('--'):continue
  if runtime_pattern.search(line):runtime.append(dict(path=rel,line=n,text=line.strip()))
  for match in re.finditer(r'\brequire\(((?:[^()\n]|\([^()\n]*\))*)\)',line):
   expr=match[1];tokens=re.findall(r'[A-Za-z_][A-Za-z_0-9.]*',expr);candidates=[]
   for token in reversed(tokens):
    key=token.split('.')[-1]
    if key in names:candidates=names[key];break
   if len(candidates)>1 and 'script.Parent.' in expr:
    local=Path(rel).parent/(key+'.luau')
    candidates=[c for c in candidates if Path(c)==local]
   if len(candidates)==1:dependencies.add(candidates[0])
   else:
    unresolved.append(dict(line=n,expression=expr,candidates=candidates))
    ambiguous.append(dict(path=rel,line=n,expression=expr,candidates=candidates))
  if re.search(r'\(\s*require\s*::|\bpcall\s*\(\s*require\s*,',line):
   expr='runtime/cast require: '+line.strip()
   unresolved.append(dict(line=n,expression=expr,candidates=[]))
   ambiguous.append(dict(path=rel,line=n,expression=expr,candidates=[]))
 purpose=next((s.removeprefix('-- ').strip()for s in lines if s.startswith('-- ')and len(s)>8),'Inspect source; no module summary.')
 records.append(dict(path=rel,sha256=sha(data),bytes=len(data),lines=len(lines),side=Path(rel).parts[0],purpose=purpose,
  strict=bool(lines)and lines[0].strip()=='--!strict',requires=sorted(dependencies),unresolved=unresolved,direct_tests=direct[rel]))
for row in records:row['required_by']=[other['path']for other in records if row['path']in other['requires']]
summary=dict(sources=len(records),lines=sum(r['lines']for r in records),over800=sum(r['lines']>800 for r in records),
 no_direct_standard_import=sum(not r['direct_tests']for r in records),without_strict=sum(not r['strict']for r in records),
 unresolved_require_sites=len(ambiguous),runtime_call_sites=len(runtime))
index=dict(model_sha256=manifest['place_sha256'],manifest_sha256=sha((STAGE/'manifest.json').read_bytes()),source_root=str(SRC),
 summary=summary,modules=records,runtime_calls=runtime,unresolved_require_sites=ambiguous,
 limits='Literal name inference only, not a complete dependency graph, function coverage, runtime cadence or per-module behavioral review. Private recovery cohorts are separately qualified.')
out=['# Integrated candidate source map\n\n',f"Exact clean model SHA256 `{manifest['place_sha256']}`; 273 staged sources, including the qualified save owner, scenery cache and title fix. Production remains unchanged.\n\n",
 'This index supersedes the older 222-file lexical map for this private candidate. It records file size, purpose, side, inferred consumers/direct standard tests, and runtime call sites. A direct import is not a coverage percentage. Modules without a direct standard-suite import may have indirect or separately qualified private protocol tests. Unresolved/ambiguous imports remain explicit; no cycle-free claim is made.\n\n',
 f"{summary['sources']} files / {summary['lines']:,} lines; {summary['over800']} files over 800 lines; {summary['no_direct_standard_import']} without a direct standard test import; {summary['without_strict']} without a strict directive.\n\n",
 '| Source | Lines | Side | Purpose | Inferred consumers | Direct standard imports | Flags |\n|---|---:|---|---|---|---|---|\n']
for row in records:
 flags=(['over800']if row['lines']>800 else[])+(['no direct standard import']if not row['direct_tests']else[])+(['unresolved imports']if row['unresolved']else[])
 out.append('| `'+row['path']+'` | '+str(row['lines'])+' | '+row['side']+' | '+row['purpose'].replace('|','/')[:150]+' | '+', '.join(row['required_by'])+' | '+', '.join(row['direct_tests'])+' | '+', '.join(flags)+' |\n')
out.append('\n## Runtime call sites\n\nA match is a call site, not proof of execution frequency or ownership cleanup. Inspect its enclosing function before changing cadence or allocation.\n\n| Source | Line | Site |\n|---|---:|---|\n')
for row in runtime:out.append(f"| `{row['path']}` | {row['line']} | `{row['text'].replace('|','/')[:260]}` |\n")
out.append('\n## Unresolved imports\n\n| Source | Line | Expression | Candidates |\n|---|---:|---|---|\n')
for row in ambiguous:out.append(f"| `{row['path']}` | {row['line']} | `{row['expression'].replace('|','/')}` | {', '.join(row['candidates'])} |\n")
outputs={'MAP.md':''.join(out).encode(),'inventory.json':(json.dumps(index,indent=2)+'\n').encode()}
if a.check:
 for name,data in outputs.items():assert (OUT/name).read_bytes()==data
else:
 OUT.mkdir(exist_ok=True)
 for name,data in outputs.items():(OUT/name).write_bytes(data)
print(json.dumps(summary))
