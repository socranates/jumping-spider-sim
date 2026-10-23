"""Reproduce cancellation during scheduler bookkeeping against either bridge."""
from pathlib import Path
import hashlib,importlib.util,sys
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def load(name,file):
 spec=importlib.util.spec_from_file_location(name,H/file);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def build(workerPath=None):
 base=load('dispatch_base','run-bridge.py');bundle,_,paths=base.build(workerPath or H/'worker-v2.luau')
 tests=H/'dispatch-guard-tests.luau';bundle+='\n'+tests.read_text();paths+=[tests]
 inputs={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
 return bundle,inputs,paths
if __name__=='__main__':
 module=H/(sys.argv[2] if len(sys.argv)>2 else 'worker-v2.luau');assert module.parent==H
 bundle,inputs,paths=build(module);load('dispatch_execute','run.py').execute(sys.argv[1],bundle,inputs,paths)
