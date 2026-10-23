"""Check all-slot lane propagation with the complete ordinary strict overlay."""
from pathlib import Path
import importlib.util
H=Path(__file__).resolve().parent
def checker():
 s=importlib.util.spec_from_file_location('profile_types',H/'check-ordinary.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
 base=m.checker();old=base.paths
 def paths():
  out=old();out.update({'Server/RecoveryProfileOwnerPrototype.luau':H/'profile-owner.luau',
   'Server/RecoveryProfileAdmissionOptions.luau':H/'profile-options.luau','Server/RecoveryNewLifePolicyPrototype.luau':H/'new-policy-profile.luau'});return out
 base.paths=paths;return base
if __name__=='__main__':checker().main()
