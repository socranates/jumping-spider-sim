"""Bind the terminal replacement cohort to source, bundle, logs and types."""
from pathlib import Path
import ast, hashlib, importlib.util, io, json, re, subprocess, tarfile
H = Path(__file__).resolve().parent
ROOT = H.parents[1]
sha = lambda b: hashlib.sha256(b).hexdigest()
spec = importlib.util.spec_from_file_location("replacement_runner", H / "run-replacement.py")
runner = importlib.util.module_from_spec(spec); spec.loader.exec_module(runner)
bundle, _ = runner.build()
receipt = json.loads((H / "replacement-full-1-receipt.json").read_text(encoding="utf8"))
output = (H / "replacement-full-1-output.txt").read_bytes()
source = subprocess.check_output(["git", "log", "-1", "--format=%H", "--", "roblox_port/src", "roblox_port/tests"], cwd=ROOT, text=True).strip()
assert receipt["source"] == source and receipt["exit_code"] == 0 and not receipt["focused"]
assert sha(bundle.encode()) == receipt["bundle_sha256"] and sha(output) == receipt["output_sha256"]
for name, digest in {**receipt["inputs"], **receipt["production_inputs"]}.items():
    assert sha((ROOT / name).read_bytes()) == digest, name
archive = subprocess.check_output(["git", "archive", "--format=tar", source, "roblox_port/src", "roblox_port/tests"], cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
    committed = {item.name:sha(tar.extractfile(item).read()) for item in tar if item.isfile()}
assert committed == receipt["production_inputs"]
tree = ast.parse((H / "verify-recovery-capability.py").read_text(encoding="utf8"))
node = next(n.value for n in tree.body if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "expected" for t in n.targets))
expected = {kw.arg:ast.literal_eval(kw.value) for kw in node.keywords}
assert sum(expected.values()) == 187257
expected.update(RECOVERY_ACTUAL_GAME=1012, RECOVERY_PROFILE_OWNER=10177, RECOVERY_PROFILE_SERVICE=3141, SESSION_REPLACEMENT=2667)
rows = re.findall(r"^(RECOVERY_\w+|SESSION_REPLACEMENT) passed=(\d+) failed=(\d+)", output.decode(), re.M)
assert len(rows) == len(expected) == 29
assert {name:(int(p),int(f)) for name,p,f in rows} == {name:(n,0) for name,n in expected.items()}
assert sum(expected.values()) == 204254
for mode in ["main", "free", "easy"]:
    assert f"SESSION_REPLACEMENT mode={mode} old_closed=true fresh_epoch=true no_auto_choice=true final_progress=true originals_unchanged=true late_old_refused=true" in output.decode()
types = json.loads((H / "replacement-types-6-types.json").read_text(encoding="utf8"))
assert types["source"] == source and len(types["candidates"]) == 40 and len(types["steps"]) == 3
for name, digest in types["candidates"].items():
    assert sha((H / name).read_bytes()) == digest, name
for name, digest in types["production_inputs"].items():
    assert sha((ROOT / name).read_bytes()) == digest, name
for step in types["steps"]:
    assert step["exit_code"] == 0 and sha((H / ("replacement-types-6-" + step["name"] + ".txt")).read_bytes()) == step["output_sha256"]
assert (H / "replacement-types-6-compile.txt").read_text(encoding="utf8") == "compile 40/40\n"
strict = (H / "replacement-types-6-strict.txt").read_text(encoding="utf8")
assert not [line for line in strict.splitlines() if line and not line.startswith("[INFO]") and "didChangeWatchedFiles" not in line]
assert subprocess.run(["git", "diff", "--quiet", "HEAD", "--", "roblox_port/src", "roblox_port/tests"], cwd=ROOT).returncode == 0
assert "ownerFactory" not in (ROOT / "roblox_port/src/Server/Persistence.server.luau").read_text(encoding="utf8")
result = dict(source=source, preceding_private_assertions=201587, replacement_assertions=2667, total_assertions=204254, failed=0,
              private_candidates=40, compile_and_full_strict_clean=True, actual_service_client_and_continuation_used=True,
              explicit_capability_frozen_on_first_compatible_handshake=True, application_pause_and_fresh_menu_callbacks_required=True,
              old_checkpoint_and_offer_work_revoked=True, exact_closed_departure_before_new_owner=True,
              new_epoch_and_nonce_bound_loaded_reply=True, ordinary_messages_epoch_fenced=True,
              old_yielded_client_update_not_restamped=True, final_progress_preserved=True,
              confirmed_rests_archives_and_proposals_unchanged=True, same_physical_account_key_retained=True,
              rolling_request_debt_retained_across_sessions=True, replacement_startup_lane_closed=True,
              loss_retry_and_two_consecutive_replacements_verified=True, departure_failure_and_deadline_remain_readonly=True,
              removal_and_shutdown_during_closing_verified=True, late_unloaded_constructor_discarded_without_io=True,
              application_callbacks_scripted_not_native_menu=True, native_replacement_verified=False,
              ordinary_engine_recovery_installed=False, real_datastore_verified=False, published=False, goal_complete=False)
(H / "replacement-verification.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf8", newline="\n")
print(json.dumps(result, indent=2))
