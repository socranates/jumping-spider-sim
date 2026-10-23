"""Observe the failing reserve assertion without changing the source or its verdict."""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile,sys
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
name='client_smoke.luau';source=r.bundle(name)
baseline='ccc0abbd8a1f6a0b37dbb6244c46c2a1b106f157'
assert not subprocess.check_output(['git','diff','--name-only',baseline,'HEAD','--','roblox_port/src'],cwd=ROOT,text=True).strip(),'Diagnostic requires the unchanged pond-adoption runtime'
original_test=subprocess.check_output(['git','show',baseline+':roblox_port/tests/'+name],cwd=ROOT).decode()
current_body=r.requires((ROOT/'roblox_port/tests'/name).read_text(encoding='utf8'))+'\n';assert source.endswith(current_body)
source=source[:-len(current_body)]+r.requires(original_test)+'\n'
marker='\tassert(needs == driver.needs and prey.feeding.needs == needs and math.abs(needs.energy - energy) < 1e-6, "the reserves did not go back")'
assert source.count(marker)==1
probe=''' local saved=driver.currentStore():loadBest().record
 local object=saved.world.objects[saved.world.roots.needs["$o"]]
 local storedEnergy=nil
 for _,entry in object.e do if entry[1]=="energy" then storedEnergy=entry[2] end end
 print(string.format("RETURN_ENERGY live=%.17g observed_before=%.17g saved=%.17g delta_saved=%.17g same_root=%s same_jaws=%s",needs.energy,energy,storedEnergy,needs.energy-storedEnergy,tostring(needs==driver.needs),tostring(prey.feeding.needs==needs)))
'''
source=source.replace(marker,probe+marker)
advanced='--advance' in sys.argv
advance=next((int(x.split('=',1)[1]) for x in sys.argv if x.startswith('--advance=')),12 if advanced else 0)
advanced=advance>0
if advanced:
 marker='\tlocal energy, hour, tick = needs.energy, life.clock.hour, prey.tick'
 assert source.count(marker)==1
 source=source.replace(marker,'\tframes('+str(advance)+') -- controlled elapsed time after the saved snapshot\n'+marker)
cli=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe')
with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(source);path=Path(f.name)
try:result=subprocess.run([str(cli),str(path)],capture_output=True,text=True)
finally:path.unlink(missing_ok=True)
output=result.stdout+result.stderr
stem='return-energy-'+(('advanced'+str(advance)+'-') if advanced else '')+'diagnostic'
assert not (HERE/(stem+'.txt')).exists(),'Keep the prior diagnostic'
(HERE/(stem+'.txt')).write_text(output,encoding='utf8',newline='\n')
receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),exit_code=result.returncode,bundle_sha256=hashlib.sha256(source.encode()).hexdigest(),test_sha256=hashlib.sha256(original_test.encode()).hexdigest(),output_sha256=hashlib.sha256(output.encode()).hexdigest(),assertion_unchanged=True,production_changed=False)
receipt['advance_after_snapshot_frames']=advance
receipt['baseline_test_source']=baseline
(HERE/(stem+'.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(output);raise SystemExit(result.returncode)
