"""Reproduce and qualify bounded scheduler history in both typed bridges."""
from pathlib import Path
import hashlib,importlib.util,sys
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def load(name,file):
 spec=importlib.util.spec_from_file_location(name,H/file);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def build(before=False,testsPath=None):
 runner=load('history_operation','run-operation.py')
 bundle,_,paths=runner.build(H/('worker-v2.luau' if before else 'worker-v3.luau'),H/('operation-before-history.luau' if before else 'operation.luau'))
 tests=testsPath or H/'history-tests.luau';bundle+='\n'+tests.read_text();paths+=[tests]
 return bundle,{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},paths
if __name__=='__main__':
 bundle,inputs,paths=build('--before' in sys.argv[2:]);load('history_execute','run.py').execute(sys.argv[1],bundle,inputs,paths)
