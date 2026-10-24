for _,mode in Rules.MODES do
 test("legacy-incoming-protected-validation-"..mode,function()
  WorldMap.use("test_garden");local old=gardenWorld()
  old.life.mode=if mode=="free" then "free" else "main"
  old.life.rules=if mode=="main" then "standard" else "gentle";old.needs.gentle=mode~="main"
  local record=assert(Checkpoint.capture(old,120));record.save_life="legacy-offer-"..mode
  WorldMap.use("preserve");local world=newWorld();world.garden={}
  world.life.mode=old.life.mode;world.life.rules=old.life.rules;world.needs.gentle=old.needs.gentle
  local function current(slot,value,received)
   if received and SaveRest.isRetired(value) then return SaveRest.bounded(value,10,3)==nil and #SaveRest.SPECS[slot].validate(value)==0 end
   return #SaveRest.check(slot,value,world)==0
  end
  check(not current(mode,record,true),"legacy fixture was already accepted against current habitat")
  local validate=if LEGACY_BEFORE_POLICY then current else LegacyOfferValidation.new(current)
  local restored,selected=0,0
  local function client()
   return __mods.SaveContinuation.new({rules=Rules,copy=Json.copy,validate=validate,recoveryVersion=Rules.RECOVERY_PROTOCOL,
    onRestore=function()restored+=1 end,onProtectedSelected=function()selected+=1;return true end})
  end
  local function deliver(c,protected,value)
   return c:receive({kind="loaded",v=Rules.OFFER_PROTOCOL,recovery=Rules.RECOVERY_PROTOCOL,epoch="legacy",sequence=1,status="saved",
    offers={[mode]={id="recorded-garden",protected=protected,record=value or record}}})
  end
  local c=client();local before=Json.canonical(record);assert(deliver(c,true))
  local info=c:offerInfo(mode)
  check(info~=nil and info.protected and info.playable,"protected recorded-world offer was rejected by actual continuation")
  check(selected==0 and restored==0 and c.requests[mode]==nil,"validation granted or restored a life")
  check(c:choose(mode,"continue",info.id) and selected==1 and restored==0,"legacy Continue bypassed protected application entry")
  check(c.requests[mode].state=="readonly" and c.requests[mode].credential==nil and c.requests[mode].selected==nil,"legacy observation manufactured ordinary restore authority")
  check(not validate(mode,record,false,true),"legacy outgoing checkpoint escaped current-world validation")
  local plain=client();assert(deliver(plain,false));check(plain:offerInfo(mode)==nil,"unprotected legacy offer escaped current-world validation")
  local corrupt=Json.copy(record);corrupt.world_map.revision+=1
  check(not validate(mode,corrupt,true,true),"unknown recorded world revision was accepted")
  local other=if mode=="free" then "main" else "free"
  check(not validate(other,record,true,true),"legacy mode mismatch was accepted")
  local currentRecord=assert(Checkpoint.capture(world,121))
  check(validate(mode,currentRecord,false,false) and validate(mode,currentRecord,true,false),"current-world checkpoint or offer regressed")
  local retired={save_retired=true,save_life="retired-token"}
  check(validate(mode,retired,true,true) and not validate(mode,retired,false,true),"retired marker direction changed")
  check(Json.canonical(record)==before,"offer validation mutated the recorded world")
 end)
end
