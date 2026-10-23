-- Targeted current-client counterexample. Insert before the original suite's
-- readyBed cleanup, while the actual SpiderClient's world still exists.
do
 local d=assert(ClientStubs.driver);local oldStreaming=workspace.StreamingEnabled
 local folder;local parent
 local ok,problem=xpcall(function()
  assert(d.world.map.world()=="test_garden","unexpected baseline world")
  assert(d.fresh("free",false,nil),"fresh Free life refused")
  d.place(Vector3.new(11,-89.69,-50));frames(5)
  assert(d.world:regionReady("bed_a") and d.motor.mode=="attached","baseline needs a supported attached spider")
  local pos=d.motor.pos;local needsElapsed=d.needs.elapsedS;local lifeElapsed=d.life.elapsed
  folder=assert(d.world:folderOf(assert(WorldMap.region("bed_a"))));parent=folder.Parent
  workspace.StreamingEnabled=true;folder.Parent=nil
  assert(not d.world:regionReady("bed_a"),"fixture failed to remove real collision")
  frames(60)
  local moved=(d.motor.pos-pos).Magnitude
  print("PLAYER_STREAM_WITNESS moved="..moved.." before="..tostring(pos).." after="..tostring(d.motor.pos).." mode="..d.motor.mode.." life_seconds="..tostring(d.life.elapsed-lifeElapsed).." needs_seconds="..tostring(d.needs.elapsedS-needsElapsed))
  assert(moved<.001 and d.motor.mode=="attached","the actual player fell or moved while their region collision was absent")
 end,debug.traceback)
 if folder then folder.Parent=parent end;workspace.StreamingEnabled=oldStreaming
 assert(ok,problem)
 print("PLAYER_STREAM_READINESS passed=1 failed=0")
end
