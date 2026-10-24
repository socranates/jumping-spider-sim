"""Strict-check actual startup with scoped recorded-offer validation."""
from pathlib import Path
import importlib.util
H=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('legacy_normal_mounts',H/'check.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
checker=m.checker;prior=checker.paths
def paths():
 out=prior();out.update({'Client/SpiderClient.client.luau':H/'spider-client-legacy.client.luau',
  'Client/SaveContinuation.luau':H/'continuation-legacy.luau','Client/RecoveryOfferValidation.luau':H/'offer-validation.luau'})
 return out
checker.paths=paths
if __name__=='__main__':
 m.m.checker=lambda:checker
 m.m.main()
