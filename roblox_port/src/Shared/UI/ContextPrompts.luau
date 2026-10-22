--!strict
-- Only the player-requested meal and dusk prompts enter the minimal play HUD.
local ControlText=require(script.Parent.ControlText)
local LifeClock=require(script.Parent.Parent.Life.LifeClock)
local LifeText=require(script.Parent.LifeText)
local P={};P.__index=P
function P.new(): any return setmetatable({night=nil,dismissed=false,away=0,key="",view=nil},P) end
function P.reset(self: any) self.night=nil;self.dismissed=false;self.away=0;self.key="";self.view=nil end
function P.step(self: any,dt: number,s: any): any
 local night=if s.hour>=LifeClock.DUSK_H then s.day elseif s.hour<LifeClock.WAKE_H then s.day-1 else nil
 if night~=self.night then self.night=night;self.dismissed=false;self.away=0 end
 if night~=nil and s.resting then self.dismissed=true end
 local text: string?=nil
 if s.enabled and not s.blocked then
  local key=ControlText.name(s.device,"feed")
  if s.held then
   if not s.canEat then text="Land and keep still to eat."
   elseif s.struggling and not s.auto then text=`Tap {if s.device=="touch" then "Grip" else key}: hold your prey`
   elseif s.struggling then text="Holding your prey"
   elseif s.auto then text="Eating - move to pause"
   else text=`Tap {key}: eat` end
  elseif night~=nil and not self.dismissed then
   if s.weak then text="Too hungry to sleep; find food."
   elseif s.canRest then text=`{if s.device=="touch" then "Rest" else key}: rest`
   elseif self.away<8 then
    local home=LifeText.HOMES[s.home or "sill_crevice"] or LifeText.HOMES.sill_crevice
    text="It is dark. Rest "..(if string.sub(home.name,1,6)=="under " then home.name else "in "..home.name).."."
    self.away+=dt
   end
  end
 end
 local cache=text or ""
 if cache~=self.key then self.key=cache;self.view=if text then {hint=text} else nil end
 return self.view
end
return P
