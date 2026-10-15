local Target=require("../src/Shared/Habitat/TestTarget")
local Focus=require("../src/Shared/Movement/FocusState")
local Text=require("../src/Shared/UI/PerceptionText")
local passed,failed=0,0
local function check(name,fn)
	local ok,err=pcall(fn); if ok then passed+=1 else failed+=1; print("FAIL "..name..": "..tostring(err)) end
end
check("target speed, endpoint pause, reversal and no percept while disabled",function()
	local t=Target.new({Vector3.zero,Vector3.xAxis*0.8})
	for _=1,30 do t:step(1/60) end
	assert(math.abs(t.position.X-0.4)<1e-5 and math.abs(t.velocity.X-0.8)<1e-5)
	for _=1,31 do t:step(1/60) end
	assert(math.abs(t.position.X-0.8)<1e-5)
	for _=1,80 do t:step(1/60) end
	assert(t.position.X<0.8 and t.velocity.X<0)
	t.enabled=false; assert(t:percept()==nil)
end)
check("focus toggle priority, ground and clear",function()
	local f=Focus.new(); f:press(false,true); assert(not f.latched)
	f:press(true,true); assert(f:active(false,true,true))
	f:cancel(true); assert(f.latched); f:cancel(false); assert(not f.latched)
	f:press(true,true); assert(not f:active(true,true,false) and not f.latched)
	f:press(true,true); f:clear(); assert(not f.latched)
end)
check("words have no numeric claims",function()
	for _,c in {"movement","possible_prey","fly_like_prey","unknown"} do assert(not Text.hasNumber(Text.category(c))) end
end)
local spec = require("./studio/PerceptionSpec")
spec(check)
print(`PRESENTATION passed={passed} failed={failed}`)
if failed>0 then error("perception presentation failed") end

