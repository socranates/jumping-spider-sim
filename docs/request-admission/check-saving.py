"""Strict-check all saving overrides in the complete private production overlay."""
from pathlib import Path
import importlib.util
H=Path(__file__).resolve().parent
def checker():
 p=H/'check-commit.py';spec=importlib.util.spec_from_file_location('saving_types',p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 base=m.checker();old=base.paths
 def paths():
  result=old();result.update({'Server/RecoveryRoutineProgressPrototype.luau':H/'routine-progress.luau','Server/RecoveryCurrentWriterPrototype.luau':H/'current-writer.luau',
   'Server/RecoverySaveLoopPrototype.luau':H/'save-loop.luau'});return result
 base.paths=paths;return base
if __name__=='__main__':checker().main()
