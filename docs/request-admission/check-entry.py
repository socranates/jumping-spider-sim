"""Type-check the entry/read-lease replacements with all44 existing candidates."""
from pathlib import Path
import importlib.util
H=Path(__file__).resolve().parent
def checker():
 p=H/'check-workers.py';spec=importlib.util.spec_from_file_location('entry_types',p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 old=m.paths
 def paths():
  result=old();result.update({'Server/RecoveryEntryPrototype.luau':H/'entry.luau','Server/RecoveryReadLeasePrototype.luau':H/'lease.luau','Server/RecoveryRequestAdmission.luau':H/'worker-v2.luau'});return result
 m.paths=paths;return m
if __name__=='__main__':checker().main()
