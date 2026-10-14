"""Recover reports without retaining private Studio logs.
Usage: python tools/collect_studio_report.py path/to/Studio.log output/directory
Rejects missing/truncated rows and missing controller playback report.
"""
from pathlib import Path
import json, sys

text=Path(sys.argv[1]).read_text(encoding='utf-8',errors='replace')
records={key:[] for key in ['PORT_TEST_ROW','PORT_TEST_SUMMARY','PORT_CLIENT_REPORT']}
for line in text.splitlines():
    for key,values in records.items():
        marker=key+' '
        if marker in line:
            values.append(json.loads(line.split(marker,1)[1]))
summary=records['PORT_TEST_SUMMARY'][-1]
evidence=summary['evidence_id']
rows={r['result']['name']:r['result'] for r in records['PORT_TEST_ROW'] if r['evidence_id']==evidence}
assert len(rows)==summary['tests'], 'Missing engine result rows'
assert sum(r['passed'] for r in rows.values())==summary['passed'], 'Inconsistent result counts'
client=[r for r in records['PORT_CLIENT_REPORT'] if r.get('evidence_id')==evidence][-1]
out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
(out/'studio-report.json').write_text(json.dumps(dict(summary,results=list(rows.values())),indent=2)+'\n',encoding='utf-8',newline='\n')
(out/'client-report.json').write_text(json.dumps(client,indent=2)+'\n',encoding='utf-8',newline='\n')
print(f"{evidence}: engine {summary['passed']}/{summary['tests']}, client {client['passed']}/{client['tests']}")
sys.exit(1 if summary['failed'] or client['failed'] else 0)
