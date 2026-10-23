"""Strict-check private New/departure in the complete saving overlay."""
from pathlib import Path
import importlib.util
H=Path(__file__).resolve().parent
def checker():
 p=H/'check-saving.py';spec=importlib.util.spec_from_file_location('lifecycle_types',p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 base=m.checker();old=base.paths
 def paths():
  result=old();result.update({'Server/RecoveryNewLifePolicyPrototype.luau':H/'new-policy.luau','Server/RecoveryDeparturePrototype.luau':H/'departure.luau',
   'Server/RecoveryRuntimePrototype.luau':H/'runtime-lifecycle.luau'});return result
 base.paths=paths;return base
if __name__=='__main__':checker().main()
