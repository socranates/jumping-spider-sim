-- Regression block for checkpoint.luau, inserted before its final result.
case("invalid fly positions are refused before restore, without changing record or live roots",function()
 local w=newWorld();local good=assert(Checkpoint.capture(w,0))
 check(#SaveRest.check("main",good)==0,"healthy checkpoint still valid")
 for _,bad in {{"NaN",Vector3.new(0,0/0,0)},{"infinity",Vector3.new(math.huge,0,0)},
  {"negative infinity",Vector3.new(0,-math.huge,0)},{"plain table",{X=0,Y=0,Z=0}},{"empty table",{}}} do
  local fly=w.prey.flies[1];local original=fly.position;fly.position=bad[2]
  local record=assert(Checkpoint.capture(w,0));fly.position=original
  local source=assert(Json.canonical(record));local before=fingerprint(w)
  local problems=SaveRest.check("main",record)
  check(#problems>0,"server refuses "..bad[1])
  local commit,why=Checkpoint.prepare(record,w)
  check(commit==nil and #why>0,"private preparation refuses "..bad[1])
  local ok=Checkpoint.restore(record,w)
  check(not ok and fingerprint(w)==before,"restore is atomic for "..bad[1])
  check(Json.canonical(record)==source,"source bytes remain unchanged for "..bad[1])
 end
end)
case("invalid garden fly positions use the same refusal as home prey",function()
 local w,director=gardenWorld()
 local original=director.flies[1].position;director.flies[1].position=Vector3.new(0,0/0,0)
 local record=assert(Checkpoint.capture(w,0));director.flies[1].position=original
 local source=assert(Json.canonical(record));local before=gardenText(w)
 check(#SaveRest.check("main",record)>0,"garden server validation refuses invalid position")
 local commit,why=Checkpoint.prepare(record,w)
 check(commit==nil and #why>0,"garden private preparation refuses invalid position")
 local ok=Checkpoint.restore(record,w)
 check(not ok and gardenText(w)==before and Json.canonical(record)==source,"garden refusal keeps source and all live roots intact")
end)
