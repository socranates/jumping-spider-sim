--!strict
-- Copy server profile dependencies while retaining one pre-load account lane.
local Options={}
function Options.bind(source:any,lane:any):any
 local out=table.clone(source)
 if lane==nil then return out end
 assert(out.startupBudget==nil,"profile admission replaces the old startup budget")
 local function child(original:any):any
  local cfg=table.clone(original or {})
  assert(cfg.admission==nil or cfg.admission==lane,"profile children must share ordinary account lane")
  cfg.admission=lane;return cfg
 end
 assert(out.lifecycleAdmission==nil or out.lifecycleAdmission==lane,"profile lifecycle lane differs")
 out.reader=child(source.reader);out.pipeline=child(source.pipeline);out.entryOptions=child(source.entryOptions)
 out.saveOptions=child(source.saveOptions)
 out.saveOptions.progress=child(out.saveOptions.progress);out.saveOptions.rest=child(out.saveOptions.rest)
 out.lifecycleAdmission=lane
 return out
end
return table.freeze(Options)
