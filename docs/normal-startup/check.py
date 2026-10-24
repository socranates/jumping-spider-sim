"""Strict-check complete normal startup with the qualified account-owned overlay."""
from pathlib import Path
import importlib.util,sys
H=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('normal_startup_base',H.parent/'request-admission/check-service.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
checker=m.checker();prior=checker.paths
def paths():
 out=prior();out.update({'Server/Persistence.server.luau':H/'persistence.server.luau',
  'Server/RecoveryStartup.luau':H/'composition.luau','Client/SpiderClient.client.luau':H/'spider-client.client.luau'})
 return out
checker.paths=paths
if __name__=='__main__':
 m.checker=lambda:checker
 m.main()
