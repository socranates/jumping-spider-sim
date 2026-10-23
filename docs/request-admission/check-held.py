"""Strict-check terminal-held maintenance and Runtime over the lifecycle overlay."""
from pathlib import Path
import importlib.util
H=Path(__file__).resolve().parent
def checker():
 p=H/'check-lifecycle.py';spec=importlib.util.spec_from_file_location('held_types',p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 base=m.checker();old=base.paths
 def paths():
  result=old();result.update({'Server/RecoveryIdlePrototype.luau':H/'idle.luau','Server/RecoveryRuntimePrototype.luau':H/'runtime-held.luau'});return result
 base.paths=paths;return base
if __name__=='__main__':checker().main()
