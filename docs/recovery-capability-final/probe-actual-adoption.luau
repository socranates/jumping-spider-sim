-- Counterexample: borrowing the real restore preparation alone is not a recovery
-- wait-for-server-grant adapter. Ordinary local returns are expected to resume.
fresh();local record=save()
d.place(Vector3.new(-5,.31,0));d.life.clock.hour=14;d.openMenu(true)
local before=d.saveState.worldGeneration;local storeBefore=d.currentStore()
local commit=assert(d.saveState.restore.cfg.prepare(record,{mode="main"}))
assert(d.saveState.worldGeneration==before,"preparation changed the running world")
local okay,problem=commit();assert(okay,problem)
local adopted=d.saveState.worldGeneration
assert(adopted==before+1 and d.currentStore()~=storeBefore,"actual adoption did not replace the store through the intentional generation transition")
assert(math.abs(d.life.clock.hour-12)<.001 and d.session.mode=="main" and not d.needs.gentle,"actual adoption did not rebind the restored rules/clock")
local lifeTime,needsTime,point=d.life.elapsed,d.needs.elapsedS,d.motor.pos
d.menu:hide()
for _=1,60 do frame(1/60) end
print("ACTUAL_ADOPTION_COUNTEREXAMPLE",`generation_before={before} generation_after={adopted} life_delta={d.life.elapsed-lifeTime} needs_delta={d.needs.elapsedS-needsTime} moved={(d.motor.pos-point).Magnitude} no_server_grant=true`)
assert(d.life.elapsed==lifeTime and d.needs.elapsedS==needsTime,"normal restore closure alone does not hold recovery simulation pending a server grant")
