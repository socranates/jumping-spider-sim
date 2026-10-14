-- Recovery scenarios against the box world (tests/shim.luau): tests/studio/RecoveryScenarios.luau run tick by tick on the
-- windowsill's own boxes with Workspace queries emulated for axis-aligned boxes. A deterministic smoke test of the real
-- motor, silk, jump-input and camera code; not the Roblox engine. Studio runs the same module with real queries.
local deps = {
	Motor = require("../src/Shared/Movement/SpiderMotor"),
	JumpInput = require("../src/Shared/Movement/JumpInput"),
	Layout = require("../src/Shared/Habitat/WindowsillLayout"),
	Species = require("../src/Shared/Data/Species"),
	Surfaces = require("../src/Shared/Data/Surfaces"),
	SpiderCamera = require("../src/Client/SpiderCamera"),
	cameraFixtures = { 1, 7 },
	log = function(line) print("  " .. line) end,
}
local passed, failed = 0, 0
local function check(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then passed += 1 else failed += 1; print("FAIL boxworld: " .. name .. "\n    " .. tostring(err)) end
end
require("./studio/RecoveryScenarios")(check, deps)
-- Cross-check of the emulation itself: Chet's silk spec, which passed in Windows Studio (docs/verification/roblox-silk),
-- runs unchanged on the box world.
check("Chet's Studio silk spec on the box world", function()
	local rows = {}
	require("./studio/SilkSpec")(function(name: string, fn: () -> ())
		local ok, err = pcall(fn)
		if not ok then table.insert(rows, name .. ": " .. tostring(err)) end
	end)
	assert(#rows == 0, table.concat(rows, "\n"))
end)
print(`BOXWORLD passed={passed} failed={failed}`)
if failed > 0 then error("box-world scenarios failed") end
