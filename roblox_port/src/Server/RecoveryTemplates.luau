--!strict
-- Server-authored, unplayed recovery destinations. No client record, live life,
-- DataStore, terrain construction or simulation tick is used to make a template.
-- Inactive until the recovery owner is explicitly installed by persistence.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rules = require(Shared.Data.SaveRules)
local Species = require(Shared.Data.Species)
local Layout = require(Shared.Habitat.WindowsillLayout)
local Map = require(Shared.World.WorldMap)
local Region = require(Shared.World.Region)
local Motor = require(Shared.Movement.SpiderMotor)
local Director = require(Shared.Prey.PreyDirector)
local Memory = require(Shared.Perception.ObservationMemory)
local Sensor = require(Shared.Perception.Sensor)
local Needs = require(Shared.Life.NeedsModel)
local Life = require(Shared.Life.LifeLoop)
local Rival = require(Shared.Predator.RivalSpider)
local Mate = require(Shared.Predator.Mate)
local Mating = require(Shared.Life.Mating)
local Wasp = require(Shared.Predator.WaspDirector)
local Cat = require(Shared.Predator.Cat)
local Water = require(Shared.Life.Water)
local Checkpoint = require(Shared.Persistence.Checkpoint)
local SaveRest = require(Shared.Persistence.SaveRest)
local Work = require(Shared.Persistence.SaveWork)
local Templates = {}; Templates.__index = Templates
local EPSILON = 0.00001
local function unavailableSave(): Life.CheckpointResult
 return {ok=false,message="template is not a live save owner"}
end
local function reference(name: string): (...any) -> ...any
 return function(...: any): ...any error("validation-only recovery reference: " .. name, 0) end
end
local function context(): Checkpoint.World
 local world = SaveRest.stubWorld()
 -- stubWorld is sufficient for decoding, but its shared noop would collapse
 -- distinct names when a projected graph is captured again. Keep identities.
 world.prey.graph.cast = reference("graph.cast")
 world.prey.graph.sweep = reference("graph.sweep")
 world.prey.graph.overlap = reference("graph.overlap")
 world.life.save = reference("life.save")
 world.needs.onEnergyChanged = reference("needs.onEnergyChanged")
 return world
end
local function scope(self: any): boolean
 if not self.valid then return true end
 local thread = coroutine.create(self.valid)
 local result = table.pack(coroutine.resume(thread))
 if coroutine.status(thread) ~= "dead" then coroutine.close(thread); return false end
 return result[1] == true and result[2] == true
end
local function freeze(value: any)
 if type(value) ~= "table" or table.isfrozen(value) then return end
 local pulse = Work.pulse(); if pulse then pulse() end
 for _, child in value do freeze(child) end
 table.freeze(value)
end
local function current(self: any): boolean
 if self.closed or Map.world() ~= "preserve" or Map.revision() ~= self.revision or Map.SEED ~= self.seed
  or self.root.Parent ~= workspace or self.home.Parent ~= self.root or self.home.Name ~= self.homeName
  or self.home:GetAttribute("ContentRevision") ~= Layout.CONTENT_REVISION or not scope(self) then return false end
 local seen = {}
 for _, part in self.home:GetChildren() do
  local spec = self.expected[part.Name]
  if not spec or seen[part.Name] or not part:IsA("Part") or not part.Anchored or not part.CanQuery or not part.CanCollide
   or part.Shape ~= nil and part.Shape ~= Enum.PartType.Block
   or part:GetAttribute("SurfaceId") ~= spec.id or part:GetAttribute("ProfileId") ~= spec.profile
   or (part.Position - (spec.lo + spec.hi)*0.5).Magnitude > EPSILON or (part.Size - (spec.hi - spec.lo)).Magnitude > EPSILON
   or (part.CFrame.RightVector - Vector3.xAxis).Magnitude > EPSILON
   or (part.CFrame.UpVector - Vector3.yAxis).Magnitude > EPSILON then return false end
  seen[part.Name] = true
 end
 for id in self.expected do if not seen[id] then return false end end
 return true
end
local function pulse(self: any)
 local step = Work.pulse(); if step then step() end
 assert(current(self), "authored recovery geometry or construction scope changed")
end
local function build(self: any): any
 pulse(self)
 local home = assert(Map.region(Map.HOME)); local retreat = home.retreats[1]
 assert(retreat ~= nil, "authored home retreat required")
 local midpoint = (retreat.min + retreat.max)*0.5
 local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Include
 params.FilterDescendantsInstances = {self.home}
 local hit = workspace:Raycast(midpoint, -Vector3.yAxis*((retreat.max.Y - retreat.min.Y) + 2), params)
 assert(hit and hit.Normal:Dot(Vector3.yAxis) > 0.999, "authored home retreat support unavailable")
 local position = hit.Position + hit.Normal*Motor.HEIGHT
 assert(Map.at(position) == home and Map.inRetreat(position, Map.HOME) == retreat.id, "supported template pose is outside its home retreat")
 local casts = Director.casts(self.root)
 self.probe = casts.probe -- retained for cleanup even when capture/validation fails
 local result = {}
 for _, mode in Rules.MODES do
  pulse(self)
  local gentle = mode ~= "main"
  local prey = Director.engine(self.root, Species.fly_like_prototype, Map.SEED, 4, true, nil, casts)
  assert(#prey.flies == 4 and prey.tick == 0 and prey.now == 0, "fresh authored home population differs")
  local memory = Memory.new(); local sensor = Sensor.new(memory)
  sensor:configureFrom(Species.phidippus_audax_prototype.perception)
  local needs = Needs.new(true, gentle); needs:useGameRules()
  prey.feeding.needs = needs; prey.feeding:useGameRules(); prey.feeding.tapToFeed = true
  local life = Life.new(needs, unavailableSave); life:useGameRules(); life.growth:useGameRules(gentle)
  life.mode, life.rules = if mode == "free" then "free" else "main", if gentle then "gentle" else "standard"
  life.rival, life.mate, life.mating = Rival.new(), Mate.new(), Mating.new()
  -- Capture needs only the authored attached pose, not a simulated motor.
  local world = {motor={mode="attached",preparing=false,vel=Vector3.zero,pos=position,up=hit.Normal,heading=home.spawn.heading,gazePitch=0},
   prey=prey,sensor=sensor,memory=memory,needs=needs,life=life,garden={}}
  assert(Checkpoint.boundaryProblem(world) == "", "fresh template is not at a rest boundary")
  local record, why = Checkpoint.capture(world, 0); assert(record, why)
  record.breakaway, record.wasp, record.cat, record.water = {left=0}, Wasp.defaultRecord(), Cat.defaultRecord(), Water.defaultRecord()
  local errors = SaveRest.check(mode, record, context())
  assert(#errors == 0, "authored recovery template refused: " .. table.concat(errors, "; "))
  freeze(record); result[mode] = record
 end
 pulse(self)
 return table.freeze(result)
end
function Templates.new(root: Instance?, valid: (() -> boolean)?): (any?, string?)
 -- This once-per-server engine snapshot is deliberately non-yielding. Closing
 -- a cancellable worker would skip its temporary probe's cleanup after pcall.
 if Work.pulse() ~= nil then return nil, "build authored templates outside cancellable workers" end
 if root == nil or not root:IsA("Folder") or root.Parent ~= workspace or Map.world() ~= "preserve" or valid ~= nil and type(valid) ~= "function" then
  return nil, "server Preserve geometry and construction scope required"
 end
 local home = Map.region(Map.HOME)
 if not home then return nil, "authored home region unavailable" end
 local name = Region.folderName(home); local folder = root:FindFirstChild(name)
 if not folder then return nil, "authored home collision has not arrived" end
 local expected = {}; for _, spec in Region.pieces(home) do expected[spec.id] = spec end
 local self: any = setmetatable({root=root,home=folder,homeName=name,expected=expected,revision=Map.revision(),seed=Map.SEED,valid=valid,closed=false}, Templates)
 local result = table.pack(pcall(build, self))
 if self.probe then self.probe:Destroy(); self.probe = nil end
 if not result[1] then self.closed = true; return nil, tostring(result[2]) end
 self.records = result[2]
 return self, nil
end
-- Frozen records can be shared by the cache. Each owner gets independent
-- validation callback/reference contexts; the owner then takes its bounded copy.
function Templates.profiles(self: any): (any?, string?)
 if not current(self) then return nil, "authored recovery geometry or scope changed" end
 local out = {}
 for _, mode in Rules.MODES do out[mode] = table.freeze({template=self.records[mode],context=context()}) end
 return table.freeze(out), nil
end
function Templates.close(self: any) self.closed = true end
return table.freeze(Templates)
