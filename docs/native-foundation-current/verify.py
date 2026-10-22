from pathlib import Path
import hashlib,json,subprocess,io,tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
read=lambda n:json.loads((HERE/n).read_text(encoding='utf8'))
sha=lambda b:hashlib.sha256(b).hexdigest()
n=read('receipt.json');m=read('prepared-manifest.json')
assert n['source']==m['source']=='8e02b5ee5f443ab332cf7e70f5951a304cb89eea'
assert n['scripts']==217 and n['creator_errors']==0 and n['persistence_disabled']
assert n['output_sha256']==sha((HERE/'native-output.txt').read_bytes())
assert n['place_sha256']==m['place_sha256']
assert (n['shadow']['cases'],n['shadow']['assertions'])==(7,1513)
assert (n['save']['cases'],n['save']['assertions'])==(8,45)
found={r['path']:r['sha256'] for r in m['scripts']};assert len(found)==217
blob=subprocess.check_output(['git','archive','--format=tar',n['source'],'roblox_port/src'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(blob)) as tree:
 files=[t for t in tree if t.isfile()];assert len(files)==216
 for t in files:
  b=tree.extractfile(t).read();assert (ROOT/t.name).read_bytes()==b
  parts=list(Path(t.name).relative_to('roblox_port/src').parts)
  prefix={'First':'ReplicatedFirst','Client':'StarterPlayer.StarterPlayerScripts.Client','Server':'ServerScriptService.Server','Shared':'ReplicatedStorage.Shared'}[parts.pop(0)]
  parts[-1]=parts[-1].removesuffix('.luau').removesuffix('.client').removesuffix('.server')
  assert found.pop(prefix+'.'+'.'.join(parts))==sha(b.replace(b'\r\n',b'\n'))
assert found=={'StarterPlayer.StarterPlayerScripts.Client.SilkPlayback':sha((HERE/'native-probe.luau').read_bytes())}
output=(HERE/'native-output.txt').read_text(encoding='utf8')
for prefix,k in [('SHADOW_CLEANUP','shadow'),('OBSERVED_LIFE','save')]:
 r=n[k];assert f'[{prefix}_DONE] {r["run_id"]} {r["cases"]} {r["assertions"]}' in output
assert '_FAIL]' not in output and '[FLog::CreatorError]' not in output
print('Verified exact-source native shadow1513 and synthetic save45; no online/rejoin/network/performance claim')
