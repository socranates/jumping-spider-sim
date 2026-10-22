case("client world-aware rest validation keeps the full acceptance boundary without a second decode",function()
 for _,mode in SaveRules.MODES do
  local record,world=realRest(120,mode);local original=canon(record)
  check(#SaveRest.check(mode,record)==0 and #SaveRest.check(mode,record,world)==0,mode..": complete real checkpoint validates against either proper world")
  for _,damage in {"schema","graph","life","position"} do
   local bad=Json.copy(record)
   if damage=="schema" then bad.schema_version=1e9
   elseif damage=="graph" then bad.world.objects[1]=nil
   elseif damage=="life" then bad.life_rules.mode="unknown"
   else bad.player.position={0/0,0,0} end
   check(#SaveRest.check(mode,bad)>0 and #SaveRest.check(mode,bad,world)>0,mode..": both validators reject "..damage)
  end
  check(canon(record)==original,mode..": validation never mutates input")
 end
end)

