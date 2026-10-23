from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((HERE/'return-test-candidate.json').read_text());r=json.loads((HERE/'return-test-v2-receipt.json').read_text())
candidate=(HERE/'client-smoke-snapshot-candidate.luau').read_bytes()
target=ROOT/'roblox_port/tests/client_smoke.luau'
assert sha(target.read_bytes())==m['original_sha256']
assert sha(candidate)==m['candidate_sha256']==r['candidate_sha256'] and r['exit_code']==0
assert sha((HERE/'return-test-v2-output.txt').read_bytes())==r['output_sha256']
assert (HERE/'return-test-v2-output.txt').read_text().strip()=='CLIENT passed=27 failed=0'
target.write_bytes(candidate)
(HERE/'return-test-adoption.json').write_text(json.dumps(dict(original_sha256=m['original_sha256'],candidate_sha256=sha(candidate),client_passed=27,client_failed=0,runtime_changed=False,adopted=True,current_full_gates_pending=True,published=False),indent=2)+'\n',encoding='utf8',newline='\n')
print('Snapshot-oracle test correction adopted; runtime unchanged.')
