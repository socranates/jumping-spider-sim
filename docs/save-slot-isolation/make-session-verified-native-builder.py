from pathlib import Path
HERE=Path(__file__).resolve().parent
source=(HERE/'build-session-budget-native.py').read_text()
for old,new in [('session-budget-yield-types.json','session-budget-verified-types.json'),('session-budget-yield-candidate.luau','session-budget-verified-candidate.luau'),('session-budget-candidate-tests.luau','session-budget-checked-tests.luau'),('session-budget-yield-fixed-receipt.json','session-verified-yield-receipt.json'),('session-budget-yield-controls-receipt.json','session-verified-controls-receipt.json'),('a==82 and b==44','a==83 and b==44'),('checks==126','checks==127'),('SessionBudget','SessionVerified'),('NATIVE_SESSION_BUDGET','NATIVE_SESSION_VERIFIED'),('session-budget-native','session-verified-native'),('Windowsill-session-budget-review','Windowsill-session-verified-review')]:
 assert old in source,old
 source=source.replace(old,new)
source='\n'.join(line.rstrip() for line in source.splitlines())+'\n'
(HERE/'build-session-verified-native.py').write_text(source,encoding='utf8',newline='\n')
print('Prepared a distinct native requalification builder; prior126-check package is superseded')
