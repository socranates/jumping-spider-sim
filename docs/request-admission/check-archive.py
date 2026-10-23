"""Strict-check the explicit archive replacements and nested operation module."""
from pathlib import Path
import importlib.util
H=Path(__file__).resolve().parent
def checker():
 p=H/'check-entry.py';spec=importlib.util.spec_from_file_location('archive_types',p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 base=m.checker();old=base.paths
 def paths():
  result=old();result.update({'Server/RecoveryRequestAdmission.luau':H/'worker-v3.luau','Shared/Persistence/RecoverySourceCollectorPrototype.luau':H/'collector.luau',
   'Shared/Persistence/RecoveryArchiveStorePrototype.luau':H/'repository.luau','Shared/Persistence/RecoveryControllerPrototype.luau':H/'controller.luau',
   'Shared/Persistence/RecoveryOperationAdmission.luau':H/'operation.luau','Shared/Persistence/RequestAdmissionFacade.luau':H/'worker-facade.luau'})
  return result
 base.paths=paths;return base
if __name__=='__main__':checker().main()
