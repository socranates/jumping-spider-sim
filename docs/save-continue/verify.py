"""Current pond adoption gate; prior readiness evidence remains source-bound."""
import runpy
from pathlib import Path
target=Path(__file__).resolve().parents[1]/'checkpoint-return-oracle/verify.py'
assert target.exists(),'Current pond adoption verification remains pending'
runpy.run_path(str(target))
