"""Portable nested accounting and explicit raw-adapter boundary tests."""
from pathlib import Path
import hashlib,importlib.util,sys
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def load(name,file):
 spec=importlib.util.spec_from_file_location(name,H/file);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def build(workerPath=None,operationPath=None):
 bundle,_,paths=load('operation_base','run-bridge.py').build(workerPath or H/'worker-v3.luau')
 operation=operationPath or H/'operation.luau';tests=H/'operation-tests.luau'
 bundle+='\nlocal Operation=(function()\n'+operation.read_text().replace('require("./worker-facade")','Facade')+'\nend)()\n'+tests.read_text()
 paths+=[operation,tests];return bundle,{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},paths
if __name__=='__main__':
 bundle,inputs,paths=build();load('operation_execute','run.py').execute(sys.argv[1],bundle,inputs,paths)
