"""Retain exact historical test inputs for the earlier passing receipts."""
from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent
text=(HERE/'recovery-archive-store-before-fresh-tests.luau').read_text(encoding='utf8')
suffix=text[text.rindex('print("RECOVERY_ARCHIVE_STORE'):]
earlier=text[:text.index('-- Real coroutine suspension')]+suffix
receipt=json.loads((HERE/'recovery-archive-store-before-yield-receipt.json').read_text())
assert hashlib.sha256(earlier.encode()).hexdigest()==receipt['test_sha256']
(HERE/'recovery-archive-store-before-yield-tests.luau').write_text(earlier,encoding='utf8',newline='\n')
start=earlier.index('do\n local b,r,p=fixture();local j\n j=begin(r,p,function() if j then r:cancel(j)')
end=earlier.index('\nend\n',start)+len('\nend\n')
initial=earlier[:start]+earlier[end:]
receipt=json.loads((HERE/'recovery-archive-store-initial-receipt.json').read_text())
assert hashlib.sha256(initial.encode()).hexdigest()==receipt['test_sha256']
(HERE/'recovery-archive-store-initial-tests.luau').write_text(initial,encoding='utf8',newline='\n')
print('Prior237/239-check test inputs reconstructed and hash-verified against their preserved receipts.')
