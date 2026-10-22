"""Reconstruct the four desktop trials from retained native logs, without Studio.

This verifies evidence integrity and configuration, not a causal speedup or release.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify():
    manifest = read(HERE / "manifest-v6.json")
    trials = []
    artifacts = {"manifest-v6.json", "host.json", "collect.py", "compare.py", "verify_matrix.py",
                 "RESULTS-v6-trial1.md", "README.md", "runs.json", "baseline-low-v6-bootstrap-rejected.json"}
    with tempfile.TemporaryDirectory(prefix="windowsill-matrix-") as tmp:
        tmp = Path(tmp)
        for tier in ("full", "low"):
            for role in ("baseline", "candidate"):
                name = f"{role}-{tier}-v6-trial1"
                origin = read(HERE / f"{name}-origin.json")
                snapshot = HERE / f"{name}.log"
                assert digest(snapshot) == origin["snapshot_sha256"], name
                assert origin["foreground"] is True and origin["other_studio_edit_windows"] == 1, name
                assert origin["creator_error_count_at_archive"] == 0, name
                rebuilt_path = tmp / f"{name}.json"
                subprocess.run([sys.executable, str(HERE / "collect.py"), str(snapshot),
                                "--manifest", str(HERE / "manifest-v6.json"),
                                "--run-id", origin["run"], "--out", str(rebuilt_path)],
                               check=True, capture_output=True, text=True)
                actual = read(rebuilt_path)
                saved = read(HERE / f"{name}.json")
                # Path metadata differs when reconstructing on another machine.
                for value in (actual, saved):
                    value.pop("source_log")
                    value.pop("manifest")
                assert actual == saved, f"retained JSON differs from native records: {name}"
                assert all(actual[k] is True for k in ("complete", "comparison_config",
                           "source_guard_verified", "audit_scenes_complete", "workload_verified")), name
                records = actual["records"]
                assert len(records) == len({r["kind"] for r in records}) == 13, name
                assert {r["run"] for r in records} == {origin["run"]}, name
                header = next(r["value"] for r in records if r["kind"] == "header")
                assert header["role"] == role and header["tier"] == tier and header["source"] == manifest[role], name
                trials.append({"role": role, "tier": tier, "run": origin["run"],
                               "records": len(records), "source": header["source"],
                               "engine": header["engine"], "viewport": header["viewport"]})
                artifacts.update(f"{name}{suffix}" for suffix in (".json", ".log", "-origin.json"))
            report = f"comparison-{tier}-v6-trial1-reviewed.json"
            rebuilt_report = tmp / report
            subprocess.run([sys.executable, str(HERE / "compare.py"),
                            str(HERE / f"baseline-{tier}-v6-trial1.json"),
                            str(HERE / f"candidate-{tier}-v6-trial1.json"),
                            "--out", str(rebuilt_report)], check=True, capture_output=True, text=True)
            assert read(rebuilt_report) == read(HERE / report), report
            assert read(rebuilt_report)["causal_speedup_established"] is False
            artifacts.add(report)
    return {"passed": True, "baseline_source": manifest["baseline"],
            "candidate_source": manifest["candidate"], "driver_sha256": manifest["driver_sha256"],
            "trials": trials, "trial_count": 4, "records": 52, "timed_samples": 44,
            "scope": "One desktop Studio pair per tier; Free mode; not phone or published-player evidence",
            "causal_speedup_established": False, "memory_trace_30min_complete": False,
            "audit_performance_complete": False, "publication_ready": False, "published": False,
            "files": {name: digest(HERE / name) for name in sorted(artifacts)}}


if __name__ == "__main__":
    receipt = verify()
    (HERE / "matrix-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({k: receipt[k] for k in ("passed", "trial_count", "records", "timed_samples",
                     "causal_speedup_established", "audit_performance_complete")}, indent=2))
