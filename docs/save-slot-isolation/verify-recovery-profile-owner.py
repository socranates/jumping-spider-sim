"""Verify one complete profile cohort against current source and type evidence."""
from pathlib import Path
import ast, hashlib, importlib.util, io, json, re, subprocess, tarfile
H = Path(__file__).resolve().parent
ROOT = H.parents[1]
sha = lambda b: hashlib.sha256(b).hexdigest()
spec = importlib.util.spec_from_file_location("profile_runner", H / "run-recovery-profile-owner.py")
runner = importlib.util.module_from_spec(spec); spec.loader.exec_module(runner)
bundle, _ = runner.build()
receipt = json.loads((H / "profile-full-1-receipt.json").read_text(encoding="utf8"))
output = (H / "profile-full-1-output.txt").read_bytes()
source = subprocess.check_output(["git", "log", "-1", "--format=%H", "--", "roblox_port/src", "roblox_port/tests"], cwd=ROOT, text=True).strip()
assert receipt["source"] == source and receipt["exit_code"] == 0 and not receipt["focused"]
assert sha(bundle.encode()) == receipt["bundle_sha256"] and sha(output) == receipt["output_sha256"]
for name, digest in {**receipt["inputs"], **receipt["production_inputs"]}.items():
    assert sha((ROOT / name).read_bytes()) == digest, name
archive = subprocess.check_output(["git", "archive", "--format=tar", source, "roblox_port/src", "roblox_port/tests"], cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
    committed = {item.name: sha(tar.extractfile(item).read()) for item in tar if item.isfile()}
assert committed == receipt["production_inputs"]
tree = ast.parse((H / "verify-recovery-capability.py").read_text(encoding="utf8"))
node = next(n.value for n in tree.body if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "expected" for t in n.targets))
expected = {kw.arg: ast.literal_eval(kw.value) for kw in node.keywords}
assert sum(expected.values()) == 187257
expected.update(RECOVERY_ACTUAL_GAME=1012, RECOVERY_PROFILE_OWNER=10177, RECOVERY_PROFILE_SERVICE=3141)
rows = re.findall(r"^(RECOVERY_\w+) passed=(\d+) failed=(\d+)", output.decode(), re.M)
assert len(rows) == len(expected) == 28
assert {name: (int(p), int(f)) for name, p, f in rows} == {name: (n, 0) for name, n in expected.items()}
for mode in ["main", "free", "easy"]:
    assert f"RECOVERY_PROFILE mode={mode} one_session=true fresh_selection=true matching_pipeline=true entry_granted=true" in output.decode()
    assert f"RECOVERY_PROFILE_SERVICE mode={mode} three_offers=true same_session=true apply_once=true actual_grant=true stored_ack=true other_slots_unchanged=true" in output.decode()
types = json.loads((H / "profile-types-2-types.json").read_text(encoding="utf8"))
assert types["source"] == source and len(types["candidates"]) == 36 and len(types["steps"]) == 3
for name, digest in types["candidates"].items():
    assert sha((H / name).read_bytes()) == digest, name
for name, digest in types["production_inputs"].items():
    assert sha((ROOT / name).read_bytes()) == digest, name
for step in types["steps"]:
    assert step["exit_code"] == 0
    assert sha((H / ("profile-types-2-" + step["name"] + ".txt")).read_bytes()) == step["output_sha256"]
assert (H / "profile-types-2-compile.txt").read_text(encoding="utf8") == "compile 36/36\n"
strict = (H / "profile-types-2-strict.txt").read_text(encoding="utf8")
assert not [line for line in strict.splitlines() if line and not line.startswith("[INFO]") and "didChangeWatchedFiles" not in line]
assert subprocess.run(["git", "diff", "--quiet", "HEAD", "--", "roblox_port/src", "roblox_port/tests"], cwd=ROOT).returncode == 0
assert "ownerFactory" not in (ROOT / "roblox_port/src/Server/Persistence.server.luau").read_text(encoding="utf8")
result = dict(source=source, preceding_private_assertions=188269, profile_owner_assertions=10177, profile_service_assertions=3141,
              total_assertions=sum(expected.values()), failed=0, private_candidates=36, compile_and_full_strict_clean=True,
              one_session_backend_scheduler_and_quota=True, server_owned_profile_templates=True,
              all_three_slots_visible_in_one_service_visit=True, selected_offer_freshly_rechecked=True,
              stable_offer_ids_retained=True, stale_cross_slot_and_reentrant_choices_fenced=True,
              yielded_provider_cancelled_before_rebind=True, ordinary_preaccept_choice_same_session=True,
              accepted_write_switch_requires_replacement_epoch=True, accepted_switch_retains_lease_without_rest_writes=True,
              actual_service_client_grant_and_next_rest_ack_all_slots=True, other_current_slots_and_originals_preserved=True,
              server_profile_owner_installed_in_engine=False, replacement_epochs_implemented=False,
              ordinary_menu_recovery_installed=False, native_full_recovery_verified=False,
              real_datastore_verified=False, published=False, goal_complete=False)
(H / "recovery-profile-owner-verification.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf8", newline="\n")
print(json.dumps(result, indent=2))
