"""Keep the current ledger distinct from retained historical milestones."""
from pathlib import Path
import json

here = Path(__file__).resolve().parent
path = here.parents[1] / "docs/audit/current-source/requirements.json"
data = json.loads(path.read_text(encoding="utf8"))
verified = json.loads((here / "full-verification.json").read_text(encoding="utf8"))
candidate = json.loads((here / "production-candidate.json").read_text(encoding="utf8"))
assert data["source"] == verified["source"] == candidate["source"]
assert verified["windows_failed"] == verified["linux_failed"] == 0
data["last_both_platform_full_source"] = verified["source"]
data["latest_restored_slot_full_gates"] = verified
data["latest_restored_slot_production_candidate"] = candidate
for row in data["requirements"]:
    if row["id"] == "slot-protection-A04":
        row["evidence_boundary"] = row["evidence_boundary"].replace(
            "full platform gates still live.",
            "full platform gates subsequently passed as recorded below.",
        )
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf8", newline="\n")
print("Current ledger now points to terminal source and candidate; history retained")
