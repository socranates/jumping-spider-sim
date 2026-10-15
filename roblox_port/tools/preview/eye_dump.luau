-- Prints the spider-eye picture's numbers (EyeOptics.profile and retinaStrips at k = 0 and 1, 1280x720, clock 0.9 s, looking 5.5 studs
-- away) as EYEJSON lines for tools/preview/eye_post.py. Not a test.
local Eyes = require("../src/Shared/Data/Eyes")
local EyeOptics = require("../src/Shared/UI/EyeOptics")
local W, H = 1280, 720
for _, k in { 0, 1 } do
	local p = EyeOptics.profile(k, 5.5, false)
	local strips = EyeOptics.retinaStrips(0.9, p, W, H)
	local s = {}
	for _, st in strips do table.insert(s, string.format('{"x":%.2f,"y":%.2f,"w":%.2f,"h":%.2f,"r":%.2f}', st.x, st.y, st.w, st.h, st.rotation)) end
	print(string.format('EYEJSON {"k":%d,"fov":%.3f,"sat":%.3f,"tint":[%.4f,%.4f,%.4f],"contrast":%.3f,"brightness":%.3f,"blur":%.3f,"stroke":%.3f,"fill":%.3f,"vignette":%.3f,"strips":[%s]}',
		k, p.fovDeg, p.saturation, p.tint.R, p.tint.G, p.tint.B, p.contrast, p.brightness, p.blur, p.strokeTransparency, p.fillTransparency, p.vignette, table.concat(s, ",")))
end
