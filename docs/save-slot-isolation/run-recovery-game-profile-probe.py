from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def build():
 spec=importlib.util.spec_from_file_location('actual_game_runner',H/'run-recovery-game-entry.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 text,inputs=m.build(focused=True)
 marker='for _,mode in Rules.MODES do for _,stage'
 assert text.count(marker)==1
 probe=H/'recovery-game-profile-probe.luau';text=text.split(marker,1)[0]+probe.read_text(encoding='utf8')
 return text,inputs+[probe]
if __name__=='__main__':
 text,inputs=build();prefix='actual-game-profile-alias-1';out=H/(prefix+'-output.txt');assert not out.exists()
 sha=lambda b:hashlib.sha256(b).hexdigest();hashes={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in inputs}
 with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
 try:r=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(path)],capture_output=True,text=True)
 finally:path.unlink(missing_ok=True)
 assert hashes=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in inputs}
 output=r.stdout+r.stderr;out.write_text(output,encoding='utf8',newline='\n')
 (H/(prefix+'-receipt.json')).write_text(json.dumps(dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),exit_code=r.returncode,inputs=hashes,bundle_sha256=sha(text.encode()),output_sha256=sha(output.encode()),expected_integration_counterexample=True,legacy_profile_supported=False,native_verified=False,real_datastore_verified=False,published=False),indent=2)+'\n',encoding='utf8',newline='\n')
 print(output);raise SystemExit(r.returncode)
