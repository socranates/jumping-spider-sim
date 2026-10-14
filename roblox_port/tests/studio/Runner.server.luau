--!strict
-- Included only in tests.project.json. Press Play/Run in Studio; normal place excludes it.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end
local HttpService = game:GetService("HttpService")
local evidence = require(script.Parent.BuildInfo)
workspace:SetAttribute("PortEvidence",evidence.id)
local rows = {}
local passed, failed = 0, 0
local function check(name: string, fn: () -> ())
	local ok, detail = pcall(fn)
	if ok then passed += 1 else failed += 1 end
	table.insert(rows, {name = name, passed = ok, detail = if ok then "" else tostring(detail)})
end
check("Studio spec completes", function() require(script.Parent.Spec)(check) end)
check("Silk spec completes", function() require(script.Parent.SilkSpec)(check) end)
check("Graphics spec completes", function() require(script.Parent.GraphicsSpec)(check) end)
-- Recovery scenarios and the catch camera on real raycasts and sphere casts (the same module the CLI runs on its box world).
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local deps = {
	Motor = require(Shared.Movement.SpiderMotor), JumpInput = require(Shared.Movement.JumpInput), StickCarry = require(Shared.Movement.StickCarry),
	Layout = require(Shared.Habitat.WindowsillLayout), Species = require(Shared.Data.Species), Surfaces = require(Shared.Data.Surfaces),
	SpiderCamera = require(game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client"):WaitForChild("SpiderCamera")) :: any,
	cameraFixtures = "all", transparent = true, yield = function() task.wait() end,
	log = function(line: string) print("PORT_SCENARIO " .. line) end,
}
check("Recovery scenarios complete", function() require(script.Parent.RecoveryScenarios)(check, deps) end)
check("Prompt spec completes", function() require(script.Parent.PromptSpec)(check) end)
local report = {suite = "Roblox engine", evidence_id = evidence.id, passed = passed, failed = failed,
	tests = passed + failed, not_run = 0, engine = version(), results = rows}
local json = HttpService:JSONEncode(report)
local output = Instance.new("StringValue")
output.Name = "PortTestReport"
output.Value = json
output.Parent = game:GetService("TestService")
print("PORT_TEST_REPORT " .. json)
-- Studio truncates long individual log messages. Keep each result independently recoverable.
for _, row in rows do print("PORT_TEST_ROW " .. HttpService:JSONEncode({evidence_id=evidence.id,result=row})) end
print("PORT_TEST_SUMMARY " .. HttpService:JSONEncode({evidence_id=evidence.id,passed=passed,failed=failed,tests=passed+failed,engine=version()}))
if failed > 0 then warn("PORT_TEST_FAIL") end
