from pathlib import Path
import tempfile,shutil,subprocess,json,hashlib,sys
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
TOOL=Path(r"C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe")
assert not (HERE/'target.txt').exists(), 'preserve the previous run before repeating'
suites=sys.argv[1:] or ['save_restore.luau','save_work.luau','checkpoint.luau','rare_sightings.luau','continuation_menu.luau','save_continuation.luau','save_intent.luau','save_observation.luau','state.luau','state_client.luau','state_offline.luau','rest_storage.luau','rest_compression.luau','save_notice.luau','title.luau']
with tempfile.TemporaryDirectory() as folder:
 snap=Path(folder);shutil.copytree(ROOT/'roblox_port/src',snap/'roblox_port/src');shutil.copytree(ROOT/'roblox_port/tests',snap/'roblox_port/tests')
 files=list((snap/'roblox_port/src').rglob('*.luau'))+list((snap/'roblox_port/tests').rglob('*'))
 inputs={p.relative_to(snap).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files if p.is_file() and '__pycache__' not in p.parts}
 with (HERE/'target.txt').open('w',encoding='utf8',newline='\n') as log:r=subprocess.run([sys.executable,str(snap/'roblox_port/tests/run.py'),str(TOOL),*suites],stdout=log,stderr=subprocess.STDOUT)
 f=HERE/'target.txt';f.write_bytes(f.read_bytes().replace(b'\r\n',b'\n'))
 (HERE/'target-process.json').write_text(json.dumps(dict(exit_code=r.returncode,suites=suites,inputs=inputs),indent=2)+'\n',encoding='utf8',newline='\n')
 print('target exit',r.returncode,flush=True);assert r.returncode==0
