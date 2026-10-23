"""Strict-check commit/writer/pipeline overrides over the46-target archive overlay."""
from pathlib import Path
import importlib.util
H=Path(__file__).resolve().parent
def checker():
 p=H/'check-archive.py';spec=importlib.util.spec_from_file_location('commit_types',p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
 base=m.checker();old=base.paths
 def paths():
  result=old();result.update({'Server/RecoveryProposalStorePrototype.luau':H/'proposal.luau','Server/RecoveryRestWriterPrototype.luau':H/'rest-writer.luau',
   'Server/RecoveryProgressWriterPrototype.luau':H/'progress-writer.luau','Server/RecoveryCommitControllerPrototype.luau':H/'commit.luau',
   'Server/RecoveryPipelinePrototype.luau':H/'pipeline.luau'});return result
 base.paths=paths;return base
if __name__=='__main__':checker().main()
