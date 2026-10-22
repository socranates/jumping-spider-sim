"""Collector boundary tests. Synthetic records here are never native memory evidence."""
from pathlib import Path
import copy,json,re,unittest,zlib,importlib.util
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('memory_collect',HERE/'collect.py');c=importlib.util.module_from_spec(spec);spec.loader.exec_module(c)
MANIFEST=json.loads((HERE/'manifest-v1b.json').read_text())
SMOKE=json.loads((HERE/'smoke-v1b.json').read_text())['records']
def encode(records):
 h=records['header'];run='synthetic-unit-test';lines=[f"[MEMTRACE_GUARD] {h['source']} {h['profile']} {h['duration_seconds']} 217 persistence_disabled"]
 for kind,value in records.items():
  raw=json.dumps(value,separators=(',',':')).encode();chunks=[raw[i:i+250].decode() for i in range(0,len(raw),250)]
  lines.append(f'[MEMTRACE_BEGIN] {run} {kind} {len(raw)} {len(chunks)} {zlib.adler32(raw)}')
  for i,payload in enumerate(chunks,1):lines.append(f'[MEMTRACE_DATA] {run} {kind} {i} '+json.dumps(payload))
  lines.append(f'[MEMTRACE_END] {run} {kind}')
 lines.append(f"[MEMTRACE_DONE] {run} {h['profile']} {h['duration_seconds']}")
 return '\n'.join(lines)
def synthetic_long(growth=False):
 h=copy.deepcopy(SMOKE['header']);h.update(profile='long',duration_seconds=1800,dwell_seconds=30)
 regions=c.REGIONS;templates={}
 for k,v in SMOKE.items():
  if k.startswith('visit_'):templates.setdefault(v['region'],v['state'])
 records={'header':h};interval=1800/56
 def state(elapsed,region):
  s=copy.deepcopy(templates[region]);s.update(elapsed=elapsed,utc_ms=h['began_utc_ms']+elapsed*1000,sim_seconds=elapsed,
   phase='dwell',wanted=region,region=region,region_ready=True,initialized_regions=40)
  s['frames']={'count':100,'seconds':15,'max_ms':20}
  if growth and elapsed>1400:
   s['memory']['engine_mb']+=1024;s['memory']['lua_gc_mib']+=128;s['memory']['instances']+=10000
  return s
 for i in range(1,57):
  region=regions[(i-1)%7];elapsed=i*interval;s=state(elapsed,region)
  records['arrival_'+str(i)]={'elapsed':elapsed-30,'visit':i,'region':region}
  records['visit_'+str(i)]={'elapsed':elapsed,'visit':i,'region':region,'dwell_seconds':30,'memory_min':copy.deepcopy(s['memory']),'state':s}
 for i in range(121):
  elapsed=.1 if i==0 else i*15;region=regions[min(55,int(elapsed/interval))%7];s=state(elapsed,region)
  if i==0:s['frames']['count']=0
  records['sample_'+str(i+1)]=s
 f=copy.deepcopy(SMOKE['final']);f.update(elapsed=1800,utc_ms=h['began_utc_ms']+1800000,frames=12000,frame_seconds=1800,
  sim_seconds=1800,samples=121,visits=56,visited={k:True for k in regions},state=state(1800,regions[-1]))
 records['final']=f;return records
class CollectorTests(unittest.TestCase):
 def test_native_rehearsal_never_becomes_long_memory_gate(self):
  r=c.collect(encode(SMOKE),MANIFEST);self.assertTrue(r['complete']);self.assertFalse(r['memory_gate_evidence']);self.assertEqual(r['growth_screen'],'rehearsal_only')
 def test_missing_chunk_is_incomplete(self):
  lines=encode(SMOKE).splitlines();i=next(i for i,l in enumerate(lines) if '[MEMTRACE_DATA]' in l);del lines[i]
  r=c.collect('\n'.join(lines),MANIFEST);self.assertFalse(r['complete']);self.assertTrue(r['incomplete_records'])
 def test_modified_payload_fails_checksum(self):
  lines=encode(SMOKE).splitlines();i=next(i for i,l in enumerate(lines) if '[MEMTRACE_DATA]' in l)
  m=re.search(r'(".*")$',lines[i]);payload=json.loads(m[1]);lines[i]=lines[i][:m.start()]+json.dumps('!'+payload[1:])
  self.assertRaises(ValueError,c.collect,'\n'.join(lines),MANIFEST)
 def test_focus_loss_is_rejected(self):
  r=copy.deepcopy(SMOKE);r['sample_2']['focus_losses']=1;self.assertRaises(ValueError,c.collect,encode(r),MANIFEST)
 def test_missing_memory_tag_is_rejected(self):
  r=copy.deepcopy(SMOKE);r['sample_2']['memory']['tags_mb'].pop('LuaHeap');self.assertRaises(ValueError,c.collect,encode(r),MANIFEST)
 def test_stalled_simulation_is_rejected(self):
  for value in [0,float('inf'),float('nan')]:
   with self.subTest(value=value):
    r=copy.deepcopy(SMOKE);r['final']['sim_seconds']=value;self.assertRaises(ValueError,c.collect,encode(r),MANIFEST)
 def test_short_trace_cannot_claim_long_profile(self):
  r=copy.deepcopy(SMOKE);r['header'].update(profile='long',duration_seconds=1800,dwell_seconds=30);self.assertRaises(ValueError,c.collect,encode(r),MANIFEST)
 def test_duplicate_header_is_rejected(self):
  text=encode(SMOKE);text+='\n[MEMTRACE_BEGIN] synthetic-unit-test header 1 1 1';self.assertRaises(ValueError,c.collect,text,MANIFEST)
 def test_valid_long_synthetic_data_exercises_gate(self):
  r=c.collect(encode(synthetic_long()),MANIFEST);self.assertTrue(r['complete']);self.assertTrue(r['memory_gate_evidence']);self.assertEqual(r['growth_screen'],'no_large_growth_flag')
 def test_large_growth_is_flagged_not_called_leak_free(self):
  r=c.collect(encode(synthetic_long(True)),MANIFEST);self.assertTrue(r['memory_gate_evidence']);self.assertEqual(r['growth_screen'],'investigate_growth')
if __name__=='__main__':unittest.main()
