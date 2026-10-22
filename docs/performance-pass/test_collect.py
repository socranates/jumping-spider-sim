"""Synthetic collector rejection tests; never native performance evidence."""
from pathlib import Path
import copy,json,math,subprocess,sys,tempfile,unittest,zlib
HERE=Path(__file__).resolve().parent
class CollectorTests(unittest.TestCase):
 def fixture(self):
  header=dict(role="baseline",source="a"*40,tier="full",engine="synthetic",warm_seconds=15,sample_seconds=20,harness_version=6,predator_flags={k:True for k in ["Wasp","Cat","Bird","Frog"]})
  records={"header":header}
  def sample(seconds):
   frames=[1000/60]*(seconds*60);n=len(frames)
   return dict(before={"predators":{k:{"enabled":True} for k in ["wasp","cat","bird","frog"]}},after={"predators":{k:{"enabled":True} for k in ["wasp","cat","bird","frog"]}},elapsed=seconds,action_ok=True,focus_preserved=True,viewport_unchanged=True,frame_times_ms=frames,frames=dict(frames=n,mean_ms=sum(frames)/n,median_ms=frames[0],p95_ms=frames[0],max_ms=frames[0]))
  for name in ["sill_dawn","hut_lamp_night","garden_rain","meadow_wind","pond","can_doorway","lamppost_night","walk_1","walk_2","walk_3"]:records[name]=sample(20)
  records["walk_continuous"]=sample(68)
  path=[]
  for t in range(69):
   z=-550-2.5*t;region="pad_a2" if z>-616 else "pad_b2" if z>-716 else "pad_c2"
   path.append(dict(elapsed=t,pos=[-60,-84.29,z],region=region))
  records["continuous_route"]=dict(elapsed=68,distance=170,regions=["pad_a2","pad_b2","pad_c2"],required_regions=["pad_a2","pad_b2","pad_c2"],placement_calls_during_walk=0,fresh_calls_during_walk=0,path=path)
  return records
 def collect(self,records):
  with tempfile.TemporaryDirectory() as folder:
   root=Path(folder);lines=["[FLog::CreatorOutput] [CHET_PERF_SOURCE_GUARD] baseline "+"a"*40+" full 216 216 "+"b"*64]
   for kind,value in records.items():
    raw=json.dumps(value,separators=(",",":"));chunks=[raw[i:i+250] for i in range(0,len(raw),250)]
    lines.append(f"[CHET_PERF_BEGIN] test {kind} {len(raw.encode())} {len(chunks)} {zlib.adler32(raw.encode())}")
    lines.extend(f"[CHET_PERF_DATA] test {kind} {i} {json.dumps(chunk)}" for i,chunk in enumerate(chunks,1))
    lines.append(f"[CHET_PERF_END] test {kind}")
   lines.append("[CHET_PERF_DONE] test baseline")
   log=root/"synthetic.log";log.write_text("\n".join(lines),encoding="utf-8")
   manifest=root/"manifest.json";manifest.write_text(json.dumps(dict(baseline="a"*40,driver_sha256="b"*64,profiles=[dict(role="baseline",tier="full",production_modules=215,extra_diagnostic_modules=1)])),encoding="utf-8")
   output=root/"result.json"
   result=subprocess.run([sys.executable,str(HERE/"collect.py"),str(log),"--manifest",str(manifest),"--out",str(output)],capture_output=True,text=True)
   self.assertEqual(result.returncode,0,result.stderr)
   return json.loads(output.read_text(encoding="utf-8"))
 def test_complete_continuous_walk(self):
  r=self.collect(self.fixture());self.assertTrue(r["complete"] and r["audit_scenes_complete"])
 def test_missing_route_cannot_complete_v6(self):
  records=self.fixture();del records["continuous_route"];r=self.collect(records);self.assertFalse(r["complete"] or r["audit_scenes_complete"])
 def test_teleport_is_rejected(self):
  records=self.fixture();records["continuous_route"]["path"][20]["pos"][2]-=50
  r=self.collect(records);self.assertFalse(r["complete"] or r["audit_scenes_complete"])
 def test_shortened_frame_capture_is_rejected(self):
  records=self.fixture();records["walk_continuous"]=records["walk_1"]
  r=self.collect(records);self.assertFalse(r["complete"] or r["audit_scenes_complete"])
 def test_mid_route_reset_is_rejected(self):
  records=self.fixture();records["continuous_route"]["fresh_calls_during_walk"]=1
  r=self.collect(records);self.assertFalse(r["complete"] or r["audit_scenes_complete"])
 def test_disabled_predator_is_rejected(self):
  records=self.fixture();records["walk_continuous"]["after"]["predators"]["wasp"]["enabled"]=False
  r=self.collect(records);self.assertFalse(r["complete"] or r["workload_verified"])
 def test_old_complete_smoke_is_not_eighth_scene_evidence(self):
  records=self.fixture();del records["header"]["harness_version"];del records["walk_continuous"];del records["continuous_route"]
  r=self.collect(records);self.assertTrue(r["complete"]);self.assertFalse(r["audit_scenes_complete"])
if __name__=="__main__":unittest.main()
