-- Current game controller plus existing save/return probes. Never publish.
local Run=game:GetService("RunService")
local saveProbe=require(script.Parent.SaveCostMeasurement)
local returnProbe=require(script.Parent.LocalReturnMeasurement)
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("EncoderGameProbe")==true)
 local id=tostring(DateTime.now().UnixTimestampMillis)
 print("[NATIVE_ENCODER_GAME_BEGIN]",id)
 saveProbe(d)
 returnProbe(d)
 -- Sequence completion only; both individual PASS markers and no FAIL are required.
 print("[NATIVE_ENCODER_GAME_END]",id)
end
