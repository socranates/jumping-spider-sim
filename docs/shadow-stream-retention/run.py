"""Read-only current-source probe; does not edit or rerun the full-suite inputs."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,subprocess,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
p=argparse.ArgumentParser();p.add_argument('--luau',required=True);p.add_argument('--name',choices=['baseline','candidate'],default='baseline');a=p.parse_args()
assert not (HERE/(a.name+'.txt')).exists(),'preserve prior observation'
spec=importlib.util.spec_from_file_location('shadow_runner',ROOT/'roblox_port/tests/run.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
source_hashes={str((r.SRC/rel).relative_to(ROOT)):hashlib.sha256((r.SRC/rel).read_bytes()).hexdigest() for _,rel in r.MODULES+r.CLIENT_MODULES}
with tempfile.TemporaryDirectory(prefix='windowsill-shadow-retention-') as tmp:
 tmp=Path(tmp)
 for name in {'shim.luau',*(ref+'.luau' for ref in r.REFERENCES)}:(tmp/name).write_bytes((r.HERE/name).read_bytes())
 (tmp/'probe.luau').write_bytes((HERE/'probe.luau').read_bytes())
 r.HERE=tmp;r.CLIENT_TESTS.add('probe.luau')
 bundle=tmp/'bundled.luau';bundle.write_text(r.bundle('probe.luau'),encoding='utf8',newline='\n')
 with (HERE/(a.name+'.txt')).open('w',encoding='utf8',newline='\n') as log:
  result=subprocess.run([a.luau,str(bundle)],stdout=log,stderr=subprocess.STDOUT)
 receipt={'exit_code':result.returncode,'test_sha256':hashlib.sha256((HERE/'probe.luau').read_bytes()).hexdigest(),
          'source_hashes':source_hashes,'scope':'Scripted stream-out/rearrival on current source and CLI shim; no native memory or FPS claim'}
 (HERE/(a.name+'-process.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
 print(json.dumps({k:v for k,v in receipt.items() if k!='source_hashes'}))
