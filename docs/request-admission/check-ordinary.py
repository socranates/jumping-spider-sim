"""Ordinary Session and its Shared request driver in the full strict overlay."""
from pathlib import Path
import importlib.util
H=Path(__file__).resolve().parent
def checker():
 p=H/'check-held.py';s=importlib.util.spec_from_file_location('ordinary_types',p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
 base=m.checker();old=base.paths
 def paths():
  result=old();result.update({'Shared/Persistence/SaveSession.luau':H/'ordinary-session.luau','Shared/Persistence/OrdinaryRequestAdmission.luau':H/'ordinary-io.luau',
   'Server/RecoveryRuntimePrototype.luau':H/'runtime-ordinary.luau'});return result
 base.paths=paths;return base
if __name__=='__main__':checker().main()
