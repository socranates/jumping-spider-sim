--!strict
-- Storage only: independently compressed current/backup cores retain their original canonical checksums.
-- The opaque schema-2 header makes an older server refuse this value as newer. No simulation fields change.
local RestCompression={}
RestCompression.__index=RestCompression
RestCompression.ENCODING="zstd-base64-2"
RestCompression.MAX_STORED_CHARS=1500000
RestCompression.MAX_CORE_BYTES=6000000
RestCompression.MAX_EXPANDED_BYTES=12000000
RestCompression.HEADER_RESERVE=2048
export type Adapter={
 compress:(string)->string, expandedSize:(string)->number?, decompress:(string)->string,
 parse:(string)->any, serialize:(any)->(string?,string?),
}
local function finite(v: any): boolean
 return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge
end
local function whole(v: any): boolean return finite(v) and v>=1 and v==math.floor(v) end
local function restKind(v: any): boolean
 return v=="rest_main" or v=="rest_easy" or v=="rest_free"
end
local FIELDS={format=true,kind=true,schema=true,innerSchema=true,updatedAt=true,encoding=true,bytes=true,data=true,backup=true}
local function future(v: any): boolean
 if type(v)~="table" or not finite(v.schema) or v.schema<2 then return false end
 if v.schema>2 or v.encoding~=RestCompression.ENCODING then return true end
 for k in v do if not FIELDS[k] then return true end end
 return false
end
function RestCompression.new(adapter: Adapter): any
 assert(2*RestCompression.MAX_CORE_BYTES<=RestCompression.MAX_EXPANDED_BYTES,"invalid combined expansion budget")
 return setmetatable({adapter=adapter},RestCompression)
end
local function coreEnvelope(v: any): any
 local out={}
 for k,x in v do if k~="backup" then out[k]=x end end
 return out
end
local function packCore(self: any,envelope: any): any
 assert(type(envelope)=="table" and restKind(envelope.kind),"not a rest envelope")
 assert(whole(envelope.schema) and finite(envelope.updatedAt),"invalid rest envelope header")
 local text,why=self.adapter.serialize(coreEnvelope(envelope))
 assert(text,why)
 assert(#text<=RestCompression.MAX_CORE_BYTES,"rest core exceeds expanded limit")
 local data=self.adapter.compress(text)
 assert(type(data)=="string" and #data<=RestCompression.MAX_STORED_CHARS,"compressed rest exceeds storage limit")
 return {format=envelope.format,kind=envelope.kind,schema=2,innerSchema=envelope.schema,
  updatedAt=envelope.updatedAt,encoding=RestCompression.ENCODING,bytes=#text,data=data}
end
function RestCompression.encode(self: any,envelope: any): any
 local wrapped=packCore(self,envelope)
 if envelope.backup~=nil then
  local backup=coreEnvelope(envelope.backup)
  backup.format,backup.kind=envelope.format,envelope.kind
  wrapped.backup=packCore(self,backup)
 end
 local dataBytes=#wrapped.data+(if wrapped.backup then #wrapped.backup.data else 0)
 assert(dataBytes+RestCompression.HEADER_RESERVE<=RestCompression.MAX_STORED_CHARS,"compressed rest and backup exceed storage limit")
 assert(#assert(self.adapter.serialize(wrapped))<=RestCompression.MAX_STORED_CHARS,"compressed rest header exceeds storage limit")
 return wrapped
end
local function unpackCore(self: any,v: any): any
 assert(type(v)=="table" and v.encoding==RestCompression.ENCODING and v.schema==2,"invalid compressed rest schema")
 assert(restKind(v.kind) and type(v.format)=="string" and #v.format<=64,"invalid compressed rest kind")
 assert(whole(v.innerSchema) and finite(v.updatedAt),"invalid inner rest header")
 assert(type(v.data)=="string" and #v.data<=RestCompression.MAX_STORED_CHARS,"invalid compressed rest size")
 assert(whole(v.bytes) and v.bytes<=RestCompression.MAX_CORE_BYTES,"invalid expanded rest size")
 local size=self.adapter.expandedSize(v.data)
 assert(size==v.bytes,"compressed rest frame size does not match its header")
 local text=self.adapter.decompress(v.data)
 assert(type(text)=="string" and #text==size,"decompressed rest size does not match")
 local envelope=self.adapter.parse(text)
 assert(type(envelope)=="table" and envelope.format==v.format and envelope.kind==v.kind
  and envelope.schema==v.innerSchema and envelope.updatedAt==v.updatedAt and envelope.backup==nil,
  "compressed rest header does not match its contents")
 return envelope
end
local function corruptCore(v: any): any
 return {format=v.format,kind=v.kind,schema=if whole(v.innerSchema) then v.innerSchema else 1,
  updatedAt=if finite(v.updatedAt) then v.updatedAt else 0,checksum=""}
end
-- Read paths can expose a good independent backup through a deliberately corrupt current envelope.
-- Write callbacks use the strict default: a corrupt current core must never reach a transform.
function RestCompression.decode(self: any,v: any,recoverBackup: boolean?): any
 if type(v)~="table" or v.encoding~=RestCompression.ENCODING then return v end
 if future(v) or future(v.backup) then return v end
 local backup=v.backup
 local validBackup=type(backup)=="table" and backup.backup==nil
  and backup.format==v.format and backup.kind==v.kind
 local currentBytes=if type(v.data)=="string" then #v.data else 0
 local backupBytes=if validBackup and type(backup.data)=="string" then #backup.data else 0
 local withinBudget=currentBytes+backupBytes+RestCompression.HEADER_RESERVE<=RestCompression.MAX_STORED_CHARS
 if not withinBudget and not recoverBackup then error("compressed rest and backup exceed storage limit",0) end
 local ok=false
 local envelope: any="compressed rest and backup exceed storage limit"
 if withinBudget then ok,envelope=pcall(unpackCore,self,v) end
 if not ok then
  if not recoverBackup then error(envelope,0) end
  envelope=corruptCore(v)
 end
 if backup~=nil then
  local good,decoded=false,nil
  if validBackup and backupBytes+RestCompression.HEADER_RESERVE<=RestCompression.MAX_STORED_CHARS then good,decoded=pcall(unpackCore,self,backup) end
  if not good then decoded=corruptCore(if type(backup)=="table" then backup else v) end
  local restoredBackup=coreEnvelope(decoded)
  restoredBackup.format,restoredBackup.kind=nil,nil
  envelope.backup=restoredBackup
 end
 return envelope
end
function RestCompression.engine(): any
 local encoding=game:GetService("EncodingService")
 local http=game:GetService("HttpService")
 return RestCompression.new({
  -- Native transport serialization is faster; canonical checksums remain inside both cores.
  serialize=function(v: any): (string?,string?) return http:JSONEncode(v),nil end,
  compress=function(text: string): string
   return buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(buffer.fromstring(text),Enum.CompressionAlgorithm.Zstd,3)))
  end,
  expandedSize=function(data: string): number?
   return encoding:GetDecompressedBufferSize(encoding:Base64Decode(buffer.fromstring(data)),Enum.CompressionAlgorithm.Zstd)
  end,
  decompress=function(data: string): string
   return buffer.tostring(encoding:DecompressBuffer(encoding:Base64Decode(buffer.fromstring(data)),Enum.CompressionAlgorithm.Zstd))
  end,
  parse=function(text: string): any return http:JSONDecode(text) end,
 })
end
return RestCompression
