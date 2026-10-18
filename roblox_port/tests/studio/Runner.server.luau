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
-- A spec may report that part of itself could not run here (for instance DataStore checks without API access): never counted as passed.
local notRun = {}
local function skip(name: string, why: string)
	table.insert(notRun, {name = name, why = why})
	print("PORT_TEST_SKIPPED " .. HttpService:JSONEncode({evidence_id = evidence.id, name = name, why = why}))
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
check("Perception spec completes", function() require(script.Parent.PerceptionSpec)(check) end)
check("Prey spec completes", function() require(script.Parent.PreySpec)(check) end)
check("Prompt spec completes", function() require(script.Parent.PromptSpec)(check) end)
check("Life spec completes", function() require(script.Parent.LifeSpec)(check) end)
check("Wasp spec completes", function() require(script.Parent.WaspSpec)(check) end)
check("Peacock spec completes", function() require(script.Parent.PeacockSpec)(check) end)
check("Ant mimic spec completes", function() require(script.Parent.AntMimicSpec)(check) end)
check("Growth spec completes", function() require(script.Parent.GrowthSpec)(check) end)
check("Notebook spec completes", function() require(script.Parent.NotebookSpec)(check) end)
check("State spec completes", function() require(script.Parent.StateSpec)(check, skip) end)
check("Settings spec completes", function() require(script.Parent.SettingsSpec)(check) end)
local report = {suite = "Roblox engine", evidence_id = evidence.id, passed = passed, failed = failed,
	tests = passed + failed, not_run = #notRun, skipped = notRun, engine = version(), results = rows}
local json = HttpService:JSONEncode(report)
local output = Instance.new("StringValue")
output.Name = "PortTestReport"
output.Value = json
output.Parent = game:GetService("TestService")
print("PORT_TEST_REPORT " .. json)
-- Studio truncates long individual log messages. Keep each result independently recoverable.
for _, row in rows do print("PORT_TEST_ROW " .. HttpService:JSONEncode({evidence_id=evidence.id,result=row})) end
print("PORT_TEST_SUMMARY " .. HttpService:JSONEncode({evidence_id=evidence.id,passed=passed,failed=failed,tests=passed+failed,not_run=#notRun,engine=version()}))
if failed > 0 then warn("PORT_TEST_FAIL") end
