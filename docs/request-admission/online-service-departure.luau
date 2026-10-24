local actualRemovals=0
local leaving=false
local function departed(player,eventKind)
 if player~=selectedPlayer or leaving then return end
 leaving=true
 if eventKind=="PlayerRemoving" then actualRemovals+=1 end
 print("[ONLINE_SERVICE_PLAYER_REMOVING]",tag,TEST_USER,actualRemovals,eventKind)
 local old=owners[#owners]
 service:removePlayer(player)
 local deadline=now()+Rules.FLUSH_DEADLINE+2
 repeat task.wait(.025) until gate:inspect().scopes==0 and providerActive==0 or now()>=deadline
 check(old.session.closed and gate:inspect().scopes==0 and providerActive==0,"actual departure failed to close/drain owner")
 -- Emergency Stop must still close the owner, but cannot qualify real Kick or
 -- publish successful continuation metadata for a partial client test.
 if eventKind~="PlayerRemoving" or not WS:GetAttribute("OnlineServiceLeaveArmed") then
  print("[ONLINE_SERVICE_DEPARTURE_UNQUALIFIED]",tag,"owner_closed_no_success_metadata")
  WS:SetAttribute("NativeApplicationServerFailed",true)
  return
 end
 local proof=diagnosticEpoch("online-after-leave:"..tag)
 local stored={};local immutable={}
 for key in allowedKeys do
  if key~=CONTROL_KEY then
   local raw=fresh(proof,key)
   if raw~=nil then stored[key]=digest(raw) end
   if raw~=nil and (string.sub(key,1,3)=="A1_" or string.sub(key,1,3)=="M1_") then immutable[key]=digest(raw) end
  end
 end
 local p=store.data["P_"..TEST_USER]
 check(p~=nil and p.lock==nil,"uncached departure proof retained lock")
 for _,mode in Rules.MODES do
  local archive=store.data["A1_"..TEST_USER.."_"..mode]
  check(archive~=nil and Json.canonical(archive.raw)==originals[mode],"actual departure changed original archive")
  local rest=Envelope.open(SaveRest.SPECS[mode],codec:decode(store.data["R_"..TEST_USER.."_"..mode]))
  check(rest.status=="ok" and not SaveRest.isRetired(rest.payload),"actual departure did not retain ordinary checkpoint")
 end
 if rejoining then
  for key,value in metadata.immutable do check(immutable[key]==value,"rejoined save changed immutable archive/proposal") end
  for _,mode in {"free","easy"} do local key="R_"..TEST_USER.."_"..mode;check(stored[key]==metadata.stored[key],"rejoined Main save changed another current slot") end
 end
 local nextMetadata={version=1,user=TEST_USER,state=if rejoining then "done" else "await_rejoin",originals=originals,
  stored=stored,immutable=immutable,epoch=old.session.id,playerRemovals=actualRemovals,run=tag}
 diagnosticCall(proof,"update",function()
  return ds:UpdateAsync(CONTROL_KEY,function(current)
   assert(if rejoining then Json.canonical(current)==Json.canonical(metadata) else current==nil,"control state changed; refusing overwrite")
   return nextMetadata
  end)
 end)
 check(Json.canonical(fresh(proof,CONTROL_KEY))==Json.canonical(nextMetadata),"online departure control readback changed")
 gate:close(proof)
 check(gate:inspect().scopes==0 and gate:inspect().started==0 and providerActive==0,"online final verification scope survived")
 print("[ONLINE_SERVICE_DEPARTURE_PASS]",tag,Json.canonical({user=TEST_USER,state=nextMetadata.state,actual_removals=actualRemovals,
  lock_released=true,scopes=gate:inspect().scopes,provider_active=providerActive,stored_keys=(function() local n=0;for _ in stored do n+=1 end;return n end)()}))
 WS:SetAttribute("NativeApplicationFinished",true)
end
Players.PlayerRemoving:Connect(function(player)
 local ok,problem=xpcall(function() departed(player,"PlayerRemoving") end,debug.traceback)
 if not ok then WS:SetAttribute("NativeApplicationServerFailed",true);warn("[NEW_APP_NATIVE_SERVER_FAIL]",tag,problem) end
end)
game:BindToClose(function()
 if selectedPlayer and not leaving then departed(selectedPlayer,"BindToClose") end
 service:shutdown()
end)
