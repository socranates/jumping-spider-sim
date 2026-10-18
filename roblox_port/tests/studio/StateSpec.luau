--!strict
-- Persistent saves in the engine (ROBLOX-39). Two parts.
-- Always run: the server's rest check on real checkpoints as a DataStore hands them back (HttpService:JSONDecode of the fixture), envelopes
-- through the engine's own JSON, the session logic on the in-memory backend, and that the server script started with the test store and
-- made its remotes.
-- Needs "Enable Studio Access to API Services" (Game Settings > Security) in a place saved to Roblox: a real DataStore round trip through
-- DataStoreBackend (WindowsillTest_v1 only, keys of its own, removed at the end), the session lock between two sessions, and the real error
-- messages for a bad key and a value that is too large, checked against SaveStores.classify. Without access those are reported as not run
-- (the report's not_run list), never as passed.
return function(check: (string, () -> ()) -> (), skip: (string, string) -> ())
	local HttpService = game:GetService("HttpService")
	local DataStoreService = game:GetService("DataStoreService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local ServerFolder = game:GetService("ServerScriptService"):WaitForChild("Server")
	local SaveRules = require(Shared.Data.SaveRules)
	local Json = require(Shared.Persistence.Json)
	local SaveEnvelope = require(Shared.Persistence.SaveEnvelope)
	local SaveProgress = require(Shared.Persistence.SaveProgress)
	local SaveRest = require(Shared.Persistence.SaveRest)
	local SaveSession = require(Shared.Persistence.SaveSession)
	local SaveStores = require(Shared.Persistence.SaveStores)
	local MemoryBackend = require(Shared.Persistence.MemoryBackend)
	local DataStoreBackend = require(ServerFolder:WaitForChild("DataStoreBackend")) :: any
	local Fixture = require(script.Parent:WaitForChild("StateFixture")) :: any

	local function canon(v: any): string
		return (Json.canonical(v)) or "?"
	end
	local function decoded(which: string): any
		return HttpService:JSONDecode(Fixture[which])
	end
	local function prog(ids: { string }): any
		return SaveProgress.snapshot({ opened = ids, eye_seconds = 12 }, true, "maratus_volans_male", { LargeText = true })
	end

	check("state: real checkpoints, decoded by the engine's JSON, pass the server's rest check; the other mode refuses them", function()
		local main, free = decoded("main"), decoded("free")
		local p1 = SaveRest.check("main", main)
		assert(#p1 == 0, "main: " .. table.concat(p1, "; "))
		local p2 = SaveRest.check("free", free)
		assert(#p2 == 0, "free: " .. table.concat(p2, "; "))
		assert(#SaveRest.check("free", main) > 0 and #SaveRest.check("main", free) > 0, "a rest was accepted under the wrong mode")
		assert(#Fixture.main < SaveRules.MAX_REST_CHARS / 3, `the fixture is {#Fixture.main} characters`)
	end)

	check("state: the server's rest check refuses the usual damage in the engine too", function()
		local function refused(label: string, mutate: (any) -> ())
			local c = decoded("main")
			mutate(c)
			local ok, problems = pcall(SaveRest.check, "main", c)
			assert(ok and #(problems :: any) > 0, label .. " was accepted")
		end
		refused("a spider outside the sill", function(c) c.player.position = { 9999, 0, 0 } end)
		refused("a newer schema", function(c) c.schema_version = 99 end)
		refused("a dangling reference", function(c) c.world.objects[2].e[1][2] = { ["$o"] = 99999 } end)
		refused("another mode's rules", function(c) c.life_rules = { mode = "free", rules = "gentle" } end)
		refused("a vector where a number belongs", function(c) c.player.position = Vector3.new(1, 1, 1) end)
		refused("an Instance", function(c) c.player.extra = workspace end)
		refused("a function", function(c) c.player.extra = function() end end)
	end)

	check("state: envelopes survive the engine's JSON round trip: checksum, backup and lock", function()
		local rest = decoded("main")
		local spec = SaveRest.SPECS.main
		local env1 = SaveEnvelope.make(spec, rest, 1000, nil, { session = "S1" })
		local env2 = SaveEnvelope.make(spec, rest, 2000, env1, { session = "S2" })
		local back = HttpService:JSONDecode(HttpService:JSONEncode(env2))
		local o = SaveEnvelope.open(spec, back)
		assert(o.status == "ok", `{o.status}: {o.reasons[1]}`)
		assert(canon(o.payload) == canon(rest), "the payload changed in the round trip")
		assert(o.backup ~= nil and o.backup.status == "ok", "the backup did not survive")
		local pspec = SaveProgress.SPEC
		local penv = SaveEnvelope.make(pspec, prog({ "bold_jumper", "venom" }), 3000, nil, { lock = { session = "S", beat = 3000 } })
		local pback = HttpService:JSONDecode(HttpService:JSONEncode(penv))
		local po = SaveEnvelope.open(pspec, pback)
		assert(po.status == "ok" and po.lock ~= nil and po.lock.session == "S", "progress did not survive")
		assert(canon(po.payload) == canon(prog({ "bold_jumper", "venom" })), "progress changed")
		pback.payload.notebook.opened[1] = "other"
		assert(SaveEnvelope.open(pspec, pback).status == "corrupt", "a change was not noticed")
		-- numbers with fractions must have the same canonical text before and after
		local fractions = { a = 0.1, b = 1 / 3, c = 2 ^ -30, d = 123456.789, e = -0.0000123, f = 1e15 + 0.5 }
		assert(canon(fractions) == canon(HttpService:JSONDecode(HttpService:JSONEncode(fractions))), "number text changed in a round trip")
	end)

	check("state: a whole visit on the in-memory backend in the engine: load, save, leave, rejoin, and a competing session", function()
		local backend = MemoryBackend.new()
		local t = 5000
		local function session(id: string): any
			return SaveSession.new({ backend = backend, userId = "spec", sessionId = id, now = function(): number return t end, sleep = function(s: number) t += s end })
		end
		local a = session("A")
		assert(a:load() == "active", "A did not load")
		assert(a:setProgress(prog({ "bold_jumper" })), "progress refused")
		assert(a:setRest("main", decoded("main")), "rest refused")
		for _ = 1, 20 do t += 1; a:step() end
		local b = session("B")
		assert(b:load() == "session" and b.reason == "other_session", "B was not held back by A's lock")
		a:flush()
		local c = session("C")
		assert(c:load() == "active", "C could not load after A left")
		assert(c.progress.notebook.opened[1] == "bold_jumper" and c.rests.main ~= nil, "C did not get A's save")
		c:flush()
	end)

	check("state: the server script started with the test store and made its remotes", function()
		local deadline = os.clock() + 10
		while workspace:GetAttribute("SaveStoreName") == nil and os.clock() < deadline do task.wait(0.1) end
		assert(workspace:GetAttribute("SaveStoreName") == SaveRules.STORE_TEST, "the store name is " .. tostring(workspace:GetAttribute("SaveStoreName")))
		assert(SaveStores.name(true, true, nil) == SaveRules.STORE_TEST and SaveStores.name(false, false, nil) == SaveRules.STORE_PRODUCTION, "SaveStores.name")
		local folder = ReplicatedStorage:WaitForChild(SaveRules.REMOTES_NAME, 10)
		assert(folder ~= nil, "no remotes folder")
		local a, b = folder:FindFirstChild("ToServer"), folder:FindFirstChild("ToClient")
		assert(a ~= nil and a:IsA("RemoteEvent") and b ~= nil and b:IsA("RemoteEvent"), "the remotes are not RemoteEvents")
	end)

	-- ------------------------------------------------------------------------------------------------ needs API access
	local storeName = SaveRules.STORE_TEST
	local store: any = nil
	local okStore, why = pcall(function(): any
		local s = DataStoreService:GetDataStore(storeName)
		s:GetAsync("spec_probe") -- the first real request: errors here mean no API access (or an unsaved place)
		store = s
		return nil
	end)
	if not okStore then
		skip("state: DataStore round trip through DataStoreBackend, the lock, real error messages", "no DataStore access: " .. tostring(why))
		return
	end
	local runId = `spec{os.time()}x{math.random(1, 99999)}`
	local keys = { "P_" .. runId, "R_" .. runId .. "_main", "R_" .. runId .. "_free" }
	local function cleanup()
		for _, k in keys do pcall(function() store:RemoveAsync(k) end) end
	end

	check("state: a real DataStore round trip: save, leave, rejoin, rest and progress separate; the lock holds a second session out", function()
		local backend = DataStoreBackend.new(store)
		local function session(id: string): any
			return SaveSession.new({ backend = backend, userId = runId, sessionId = id, now = os.time, sleep = function(s: number) task.wait(s) end,
				log = function(text: string) print("[state spec] " .. text) end })
		end
		local a = session("A")
		assert(a:load() == "active", "A: " .. tostring(a.reason))
		assert(a:setProgress(prog({ "bold_jumper", "venom" })), "progress refused")
		assert(a:setRest("main", decoded("main")) and a:setRest("free", decoded("free")), "rests refused")
		local b = session("B")
		assert(b:load() == "session" and b.reason == "other_session", "B was not held out by the lock: " .. tostring(b.state) .. "/" .. tostring(b.reason))
		a:flush()
		local rawP = store:GetAsync(keys[1])
		assert(SaveEnvelope.open(SaveProgress.SPEC, rawP).status == "ok" and rawP.lock == nil, "progress is not stored, or the lock was kept")
		assert(SaveEnvelope.open(SaveRest.SPECS.main, store:GetAsync(keys[2])).status == "ok", "the main rest is not stored")
		assert(SaveEnvelope.open(SaveRest.SPECS.free, store:GetAsync(keys[3])).status == "ok", "the free rest is not stored")
		local c = session("C")
		assert(c:load() == "active", "C: " .. tostring(c.reason))
		assert(canon(c.progress.notebook.opened) == canon({ "bold_jumper", "venom" }) and c.progress.appearance == "maratus_volans_male", "C did not get the progress back")
		assert(canon(c.rests.main) == canon(decoded("main")) and canon(c.rests.free) == canon(decoded("free")), "C did not get the rests back")
		c:flush()
	end)

	check("state: real DataStore error messages are classed as 'value' (a bad key, a value too large, a value that cannot be stored)", function()
		local samples: { { string } } = {}
		local function sample(label: string, fn: () -> ())
			local ok, err = pcall(function(): any
				fn()
				return nil
			end)
			assert(not ok, label .. " did not fail")
			local class = SaveStores.classify(err)
			table.insert(samples, { label, tostring(err), class })
			print("PORT_STATE_ERROR " .. HttpService:JSONEncode({ label = label, message = tostring(err), class = class }))
		end
		sample("a key of 60 characters", function() store:GetAsync(string.rep("k", 60)) end)
		sample("an empty key", function() store:GetAsync("") end)
		sample("a value over 4 MB", function() store:UpdateAsync(keys[1] .. "_big", function(): any return { text = string.rep("x", 4300000) } end) end)
		sample("a value that is not storable", function() store:UpdateAsync(keys[1] .. "_nan", function(): any return { n = 0 / 0, f = function() end } end) end)
		for _, s in samples do
			assert(s[3] == "value", `"{s[1]}" gave "{s[2]}", classed {s[3]}`)
		end
		pcall(function() store:RemoveAsync(keys[1] .. "_big") end)
		pcall(function() store:RemoveAsync(keys[1] .. "_nan") end)
	end)

	cleanup()
end
