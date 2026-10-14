--!strict
-- Included only in tests.project.json. Press Play/Run in Studio; normal place excludes it.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end
local HttpService = game:GetService("HttpService")
local evidence = require(script.Parent.BuildInfo)
local rows = {}
local passed, failed = 0, 0
local function check(name, fn)
	local ok, detail = pcall(fn)
	if ok then passed += 1 else failed += 1 end
	table.insert(rows, {name = name, passed = ok, detail = if ok then "" else tostring(detail)})
end
check("Studio spec completes", function() require(script.Parent.Spec)(check) end)
local report = {suite = "Roblox engine", evidence_id = evidence.id, passed = passed, failed = failed,
	tests = passed + failed, not_run = 0, engine = version(), results = rows}
local json = HttpService:JSONEncode(report)
local output = Instance.new("StringValue")
output.Name = "PortTestReport"
output.Value = json
output.Parent = game:GetService("TestService")
print("PORT_TEST_REPORT " .. json)
if failed > 0 then warn("PORT_TEST_FAIL") end
