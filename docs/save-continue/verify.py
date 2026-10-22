"""Current spatial validator gate; prior readiness evidence remains source-bound."""
import runpy
from pathlib import Path
target=Path(__file__).resolve().parents[1]/'spatial-save-validation/verify.py'
assert target.exists(),'Current spatial save validator full/native verification remains pending'
runpy.run_path(str(target))
