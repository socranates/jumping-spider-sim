--!strict
-- Storage-only compression; the decoded envelope/checkpoint and all simulation fields stay unchanged.
-- A schema-2 header makes older servers treat this opaque value as newer, never as a writable default.
-- Engine functions are injected so boundary/refusal tests can run without pretending the CLI implements Zstandard.
local RestCompression={}
RestCompression.__index=RestCompression
RestCompression.ENCODING="zstd-base64-1"
RestCompression.MAX_STORED_CHARS=1500000
RestCompression.MAX_EXPANDED_BYTES=12000000

export type Adapter={
 compress: (string)->string,
 expandedSize: (string)->number?,
 decompress: (string)->string,
 parse: (string)->any,
 canonical: (any)->(string?,string?),
}
local function finite(v: any): boolean
 return type(v)=="number" and v==v and v~=math.huge and v~=-math.huge
end
function RestCompression.new(adapter: Adapter): any
 return setmetatable({adapter=adapter},RestCompression)
end
function RestCompression.encode(self: any,envelope: any): any
 assert(type(envelope)=="table" and type(envelope.kind)=="string" and string.sub(envelope.kind,1,5)=="rest_","not a rest envelope")
 local text,why=self.adapter.canonical(envelope)
 assert(text,why)
 assert(#text<=RestCompression.MAX_EXPANDED_BYTES,"rest envelope exceeds expanded limit")
 local data=self.adapter.compress(text)
 assert(type(data)=="string" and #data<=RestCompression.MAX_STORED_CHARS,"compressed rest exceeds storage limit")
 local wrapped={format=envelope.format,kind=envelope.kind,schema=2,updatedAt=envelope.updatedAt,
  encoding=RestCompression.ENCODING,bytes=#text,data=data}
 local stored=assert(self.adapter.canonical(wrapped))
 assert(#stored<=RestCompression.MAX_STORED_CHARS,"compressed rest header exceeds storage limit")
 return wrapped
end
function RestCompression.decode(self: any,value: any): any
 if type(value)~="table" or value.encoding~=RestCompression.ENCODING then return value end
 -- A later outer schema is opaque, including its encoding metadata.
 if finite(value.schema) and value.schema>2 then return value end
 assert(value.schema==2,"invalid compressed rest schema")
 assert(type(value.kind)=="string" and string.sub(value.kind,1,5)=="rest_","invalid compressed rest kind")
 assert(type(value.data)=="string" and #value.data<=RestCompression.MAX_STORED_CHARS,"invalid compressed rest size")
 assert(finite(value.bytes) and value.bytes>=1 and value.bytes==math.floor(value.bytes)
  and value.bytes<=RestCompression.MAX_EXPANDED_BYTES,"invalid expanded rest size")
 -- Never trust the advertised count alone. Zstd's actual frame size must agree before allocating the decoded buffer.
 local size=self.adapter.expandedSize(value.data)
 assert(size==value.bytes,"compressed rest frame size does not match its header")
 local text=self.adapter.decompress(value.data)
 assert(type(text)=="string" and #text==size,"decompressed rest size does not match")
 local envelope=self.adapter.parse(text)
 assert(type(envelope)=="table" and envelope.format==value.format and envelope.kind==value.kind
  and envelope.updatedAt==value.updatedAt,"compressed rest header does not match its contents")
 return envelope
end
function RestCompression.engine(): any
 local encoding=game:GetService("EncodingService")
 local http=game:GetService("HttpService")
 return RestCompression.new({
  -- Transport need not be sorted: the unchanged inner envelope retains its canonical checksum.
  -- Native JSON is much faster here and is checked for exact numeric round-trips in the native fixture.
  canonical=function(v: any): (string?,string?) return http:JSONEncode(v),nil end,
  compress=function(text: string): string
   local compressed=encoding:CompressBuffer(buffer.fromstring(text),Enum.CompressionAlgorithm.Zstd,3)
   return buffer.tostring(encoding:Base64Encode(compressed))
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
