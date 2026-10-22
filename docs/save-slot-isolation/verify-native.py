"""Extract bounded native diagnostic evidence; no app control and no DataStore access."""
from pathlib import Path
import json,re,hashlib,sys
HERE=Path(__file__).resolve().parent
SOURCE="3647a94c67f83076a0c7be09d75ef4a60bb0b4d5"
log=Path(sys.argv[1]);text=log.read_text(encoding="utf-8",errors="replace")
lines=[s for s in text.splitlines() if "[CHET_SLOT_" in s or "[SELFTEST]" in s or "[FLog::CreatorError]" in s or "Script timeout" in s]
# Exclude command echoes; only actual CreatorOutput can satisfy positive gates.
output="\n".join(s for s in lines if "[FLog::CreatorOutput]" in s)
guard=bool(re.search(r"\[FLog::CreatorOutput\] \[CHET_SLOT_SOURCE_GUARD\] 216 216 "+SOURCE,output))
probe=bool(re.search(r"\[FLog::CreatorOutput\] \[CHET_SLOT_NATIVE_PASS\] 9 110 2276508 ",output))
cases=re.findall(r"\[FLog::CreatorOutput\] \[CHET_SLOT_NATIVE_CASE\] (main|easy|free) (corrupt|invalid|newer) pass",output)
ends=re.findall(r"\[SELFTEST\] END pass=(\d+) fail=(\d+) skip=(\d+)",output)
errors=[s for s in lines if "[FLog::CreatorError]" in s or "Script timeout" in s or "[SELFTEST] FAIL" in s or "[CHET_SLOT_NATIVE_FAIL]" in s]
expected={(mode,damage) for mode in ["main","easy","free"] for damage in ["corrupt","invalid","newer"]}
place=json.loads((HERE/"native-review.json").read_text(encoding="utf-8"));path=Path(place["path"])
artifact_ok=path.exists() and hashlib.sha256(path.read_bytes()).hexdigest()==place["sha256"]
passed=guard and probe and set(cases)==expected and len(cases)==9 and bool(ends) and ends[-1]==("274","0","0") and not errors and artifact_ok
(HERE/"native-final.txt").write_text("\n".join(lines)+"\n",encoding="utf-8")
receipt=dict(source_commit=SOURCE,source_log=str(log.resolve()),source_log_sha256=hashlib.sha256(log.read_bytes()).hexdigest(),source_guard_pass=guard,diagnostic_artifact_unchanged=artifact_ok,probe_pass=probe,probe_cases=len(cases),probe_checks=110 if probe else None,native_record_canonical_chars=2276508 if probe else None,selftest=dict(passed=int(ends[-1][0]),failed=int(ends[-1][1]),skipped=int(ends[-1][2])) if ends else None,errors=errors,passed=passed,scope="Native engine codec and local-memory SaveSession rejoin; foreground preserve self-test. Not actual client disconnect/rejoin or online DataStore evidence.")
(HERE/"native-gates.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
print(json.dumps(receipt,indent=2))
