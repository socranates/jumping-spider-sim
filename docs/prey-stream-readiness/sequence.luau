local creature=require(script.Parent.CreatureReadinessMeasurement)
local prey=require(script.Parent.PreyReadinessMeasurement)
return function(d)
 local id=tostring(DateTime.now().UnixTimestampMillis)
 print("[NATIVE_READY_SEQUENCE_BEGIN]",id)
 creature(d);prey(d)
 -- Both individual PASS markers and no FAIL are required, not this marker alone.
 print("[NATIVE_READY_SEQUENCE_END]",id)
end
