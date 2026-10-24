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
