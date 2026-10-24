-- Diagnostic I/O uses its own short account epoch on the SAME physical ledger.
-- It does not reopen a Session or grant gameplay authority.
local function diagnosticEpoch(id)
 local scope=assert(gate:open(TEST_USER,id))
 if not gate:legacyReady(scope) then assert(gate:importLegacy(scope,{})) end
 return scope
end
local function diagnosticCall(scope,kind,fn)
 local ticket=assert(gate:request(scope,kind))
 local deadline=now()+120
 while now()<deadline do
  local okay,result,problem=gate:dispatch(ticket,fn)
  if okay then return table.unpack(result,1,result.n) end
  local status=gate:status(ticket)
  assert(status=="queued" or status=="reserved",problem)
  task.wait(.025)
 end
 gate:cancel(ticket);error("diagnostic admission expired")
end
local function fresh(scope,key)
 local request=Instance.new("DataStoreGetOptions");request.UseCache=false
 local ok,value=pcall(diagnosticCall,scope,"read",function() return ds:GetAsync(key,request) end)
 request:Destroy();assert(ok,value);return value
end
local setup=diagnosticEpoch("online-setup:"..tag)
local metadata=fresh(setup,CONTROL_KEY)
local rejoining=metadata~=nil
local resumingPartial=metadata==nil
-- Resume the exact retained failure, without seeding or replacing any record.
-- These digests were observed before stopping run 1792799053157.
local partialExpected={
 A1_qa_3cb3b30963a84dc6_main="bdb27ebf8b8c9666",A1_qa_3cb3b30963a84dc6_free="8e785aeef2e36df3",
 A1_qa_3cb3b30963a84dc6_easy="f376c54f1b4884fc",A1_qa_3cb3b30963a84dc6_progress="6ac175b2c7c2cbc3",
 A1_qa_3cb3b30963a84dc6_index="f767ccb69491562e",M1_qa_3cb3b30963a84dc6_main="9bddbf3bacf83d55",
 R_qa_3cb3b30963a84dc6_main="d74ee8e1a41cf8f7",R_qa_3cb3b30963a84dc6_free="7440488fdc126092",
 R_qa_3cb3b30963a84dc6_easy="a83e0cc92d138bfc",
}
local function retainedFailureSource(scope)
 assert(TEST_USER=="qa_3cb3b30963a84dc6" and metadata==nil,"retained failure identity/control changed")
 for key in allowedKeys do
  if key~=CONTROL_KEY then
   local value=fresh(scope,key)
   if key=="P_"..TEST_USER then
    assert(value~=nil and value.lock==nil,"previous test lease not released")
   elseif partialExpected[key] then
    assert(digest(value)==partialExpected[key],"retained failure changed: "..key)
   else assert(value==nil,"unexpected retained record: "..key) end
  end
 end
 local parts={}
 for _,part in {"progress","main","free","easy","index"} do parts[part]=store.data["A1_"..TEST_USER.."_"..part] end
 assert(ArchiveStore.checkPublished(TEST_USER,parts),"retained archive invalid")
 for _,mode in Rules.MODES do originals[mode]=assert(Json.canonical(parts[mode].raw)) end
 print("[ONLINE_SERVICE_PARTIAL_SOURCE]",tag,TEST_USER,"exact_retained_failure_no_reset")
end

if rejoining then
 assert(type(metadata)=="table" and metadata.version==1 and metadata.user==TEST_USER and metadata.state=="await_rejoin","unexpected test control state; no overwrite")
 originals=metadata.originals
 for key,expected in metadata.stored do
  assert(allowedKeys[key] and key~=CONTROL_KEY,"unknown retained test key")
  assert(digest(fresh(setup,key))==expected,"online leave/rejoin changed stored value: "..key)
 end
 check(store.data["P_"..TEST_USER].lock==nil,"previous real departure retained lock")
 print("[ONLINE_SERVICE_REJOIN_SOURCE]",tag,TEST_USER,"exact_uncached_storage_match")
elseif resumingPartial then retainedFailureSource(setup)
else
 for key in allowedKeys do if key~=CONTROL_KEY then assert(fresh(setup,key)==nil,"fresh diagnostic namespace already has data; refusing overwrite") end end
end
local function seed(key,value)
 assert(not rejoining and not resumingPartial and key~=CONTROL_KEY,"rejoin cannot seed or reset a record")
 diagnosticCall(setup,"update",function()
  return ds:UpdateAsync(key,function(old) assert(old==nil,"seed key raced; no overwrite");return value end)
 end)
 assert(Json.canonical(fresh(setup,key))==Json.canonical(value),"initial synthetic record readback changed")
end
WS:SetAttribute("OnlineServiceRejoin",rejoining)
WS:SetAttribute("OnlineServiceResumePartial",resumingPartial)
local priorPayloadDigests={}
if rejoining then
 for _,mode in Rules.MODES do
  local raw=store.data["R_"..TEST_USER.."_"..mode]
  local opened=Envelope.open(SaveRest.SPECS[mode],codec:decode(raw))
  assert(opened.status=="ok" and not SaveRest.isRetired(opened.payload),"rejoin missing ordinary stored life")
  priorPayloadDigests[mode]=digest(opened.payload)
 end
end
