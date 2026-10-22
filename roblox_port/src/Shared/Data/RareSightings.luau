--!strict
-- Only finished encounters are registered. The thirteen-creature roadmap is
-- documentation, never a locked checklist or an exposed list of future pages.
local Rare = {}
Rare.luna = {
 id="luna_moth",page="rare_luna_moth",chance=.35,days=4,
 -- Authoring bounds for a Midwest spring/summer flight window, not a claim
 -- that all Illinois populations fly on every date in it. See source audit.
 firstDay=121,lastDay=243,minTemperature=16,maxRain=.08,
 at=Vector3.new(18,.45,-20),span=10,
}
return Rare
