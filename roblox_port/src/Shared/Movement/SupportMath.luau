--!strict
-- Port of scripts/movement/support_math.gd (spec 6.1, 6.2). Pure geometry for supported locomotion; unit vectors in world space.

local SupportMath = {}

local RIGHT = Vector3.new(1, 0, 0)
local BACK = Vector3.new(0, 0, 1)

local function angleTo(a: Vector3, b: Vector3): number
	return math.atan2(a:Cross(b).Magnitude, a:Dot(b))
end
SupportMath.angleTo = angleTo

-- The part of v that lies in the plane with unit normal n.
function SupportMath.tangent(v: Vector3, n: Vector3): Vector3
	return v - n * v:Dot(n)
end

-- Unit direction of v on the plane with normal n, or zero when v is (nearly) along n.
function SupportMath.tangentDir(v: Vector3, n: Vector3, eps: number?): Vector3
	local t = SupportMath.tangent(v, n)
	local length = t.Magnitude
	return if length > (eps or 1e-5) then t / length else Vector3.zero
end

-- Hysteresis for the support normal: a candidate within ignoreDeg of the current one is ignored.
function SupportMath.filterNormal(current: Vector3, candidate: Vector3, ignoreDeg: number): Vector3
	if candidate:Dot(candidate) < 1e-10 or candidate.Magnitude ~= candidate.Magnitude then
		return current
	end
	local c = candidate.Unit
	if current:Dot(current) < 1e-10 then
		return c
	end
	if angleTo(current.Unit, c) <= math.rad(ignoreDeg) then
		return current
	end
	return c
end

function SupportMath.anyPerpendicular(v: Vector3): Vector3
	local other = if math.abs(v.Unit.X) < 0.9 then RIGHT else BACK
	return v:Cross(other).Unit
end

-- Turns unit vector `from` toward `to` by at most maxAngle radians (shortest arc).
function SupportMath.rotateToward(from: Vector3, to: Vector3, maxAngle: number): Vector3
	local angle = angleTo(from, to)
	if angle <= maxAngle or angle < 1e-6 then
		return to
	end
	local axis = from:Cross(to)
	if axis:Dot(axis) < 1e-12 then
		axis = SupportMath.anyPerpendicular(from)
	end
	return (CFrame.fromAxisAngle(axis.Unit, maxAngle) * from).Unit
end

-- Signed angle from a to b about axis n.
function SupportMath.signedAngle(a: Vector3, b: Vector3, n: Vector3): number
	return math.atan2(n:Dot(a:Cross(b)), a:Dot(b))
end

-- Body frame for an up vector and a heading: Y is up, -Z (LookVector) is the heading made perpendicular to up.
function SupportMath.bodyCFrame(position: Vector3, up: Vector3, heading: Vector3): CFrame
	local u = up.Unit
	local f = SupportMath.tangentDir(heading, u)
	if f == Vector3.zero then
		f = SupportMath.anyPerpendicular(u)
	end
	local z = -f
	local x = u:Cross(z).Unit
	return CFrame.fromMatrix(position, x, u, z)
end

return SupportMath
