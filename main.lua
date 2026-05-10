--indent size 4
dx9 = dx9 --in VS Code, this gets rid of a ton of problem underlines

if _G.CountTableEntries == nil then
	_G.CountTableEntries = function(t)
		local count = 0
		if t then
			for _ in pairs(t) do
				count = count + 1
			end
		end
		return count
	end
end

local function dot(a,b) return a.x*b.x + a.y*b.y + a.z*b.z end

local function sub(a,b) return {x=a.x-b.x, y=a.y-b.y, z=a.z-b.z} end
local function add(a,b) return {x=a.x+b.x, y=a.y+b.y, z=a.z+b.z} end
local function mul(a,s) return {x=a.x*s, y=a.y*s, z=a.z*s} end

local function length(v) return math.sqrt(dot(v,v)) end

local function normalize(v)
    local l = length(v)
    return {x=v.x/l, y=v.y/l, z=v.z/l}
end

local function makeSphere(center, radius)
    assert(type(center) == "table" and _G.CountTableEntries(center) == 3, "Sphere center must be a table with 3 fields (x, y, z)")
    assert(type(center.x) == "number" and type(center.y) == "number" and type(center.z) == "number", "Sphere center fields must be numbers (x, y, z)")
    assert(type(radius) == "number" and radius > 0, "Sphere radius must be a positive number")
    return {
        type = "sphere",
        center = center,
        radius = radius
    }
end

local function makeAABB(min, max)
    assert(type(min) == "table" and _G.CountTableEntries(min) == 3, "AABB min must be a table with 3 fields (x, y, z)")
    assert(type(min.x) == "number" and type(min.y) == "number" and type(min.z) == "number", "AABB min fields must be numbers (x, y, z)")
    assert(type(max) == "table" and _G.CountTableEntries(max) == 3, "AABB max must be a table with 3 fields (x, y, z)")
    assert(type(max.x) == "number" and type(max.y) == "number" and type(max.z) == "number", "AABB max fields must be numbers (x, y, z)")
    return {
        type = "aabb",
        min = min,
        max = max
    }
end

local function makeOBB(center, halfSize, axes)
    assert(type(center) == "table" and _G.CountTableEntries(center) == 3, "OBB center must be a table with 3 fields (x, y, z)")
    assert(type(center.x) == "number" and type(center.y) == "number" and type(center.z) == "number", "OBB center fields must be numbers (x, y, z)")
    assert(type(halfSize) == "table" and _G.CountTableEntries(halfSize) == 3, "OBB halfSize must be a table with 3 fields (x, y, z)")
    assert(type(halfSize.x) == "number" and type(halfSize.y) == "number" and type(halfSize.z) == "number", "OBB halfSize fields must be numbers (x, y, z)")
    assert(type(axes) == "table" and _G.CountTableEntries(axes) == 3, "OBB axes must be a table with 3 axes (x, y, z)")
    for k, v in pairs(axes) do
        assert(type(v) == "table" and _G.CountTableEntries(v) == 3, "Each OBB axis must be a table with 3 fields (x, y, z)")
        assert(type(v.x) == "number" and type(v.y) == "number" and type(v.z) == "number", "Each OBB axis field must be a number (x, y, z)")
    end
    return {
        type = "obb",
        center = center,
        halfSize = halfSize,
        axes = axes
    }
end

-- Returns t, hit position, and normal.

local function raySphere(origin, direction, sphere)
    local maxDistance = length(direction)
    local dir = normalize(direction)
    local L = sub(sphere.center, origin)
    local tca = dot(L, dir)
    if tca < 0 then return nil end

    local d2 = dot(L,L) - tca*tca
    local r2 = sphere.radius * sphere.radius
    if d2 > r2 then return nil end

    local thc = math.sqrt(r2 - d2)
    local t = tca - thc
    if t < 0 then t = tca + thc end
    if t < 0 or t > maxDistance then return nil end

    local hitPos = add(origin, mul(dir, t))
    local normal = normalize(sub(hitPos, sphere.center))

    return {
        t = t,
        position = hitPos,
        normal = normal,
        collider = sphere
    }
end

-- This is extremely fast, no transforms, no matrix math.

local function rayAABB(origin, direction, box)
    local maxDistance = length(direction)
    local dir = normalize(direction)
    local tMin = -1e9
    local tMax =  1e9
    local hitNormal = {x=0,y=0,z=0}

    local function checkAxis(originCoord, dirCoord, minCoord, maxCoord, nx, ny, nz)
        if math.abs(dirCoord) < 1e-8 then
            if originCoord < minCoord or originCoord > maxCoord then
                return false
            end
            return true
        end

        local t1 = (minCoord - originCoord) / dirCoord
        local t2 = (maxCoord - originCoord) / dirCoord

        local normal = {x=nx, y=ny, z=nz}

        if t1 > t2 then
            t1, t2 = t2, t1
            normal.x, normal.y, normal.z = -nx, -ny, -nz
        end

        if t1 > tMin then
            tMin = t1
            hitNormal = normal
        end

        if t2 < tMax then
            tMax = t2
        end

        return tMin <= tMax
    end

    if not checkAxis(origin.x, dir.x, box.min.x, box.max.x, -1,0,0) then return nil end
    if not checkAxis(origin.y, dir.y, box.min.y, box.max.y, 0,-1,0) then return nil end
    if not checkAxis(origin.z, dir.z, box.min.z, box.max.z, 0,0,-1) then return nil end

    if tMin < 0 or tMin > maxDistance then return nil end

    local hitPos = {
        x = origin.x + dir.x * tMin,
        y = origin.y + dir.y * tMin,
        z = origin.z + dir.z * tMin
    }

    return {
        t = tMin,
        position = hitPos,
        normal = hitNormal,
        collider = box
    }
end

-- This uses the slab method in OBB space.

local function rayOBB(origin, direction, box)
    local maxDistance = length(direction)
    local dir = normalize(direction)
    local p = sub(box.center, origin)

    local tMin, tMax = -1e9, 1e9
    local hitNormal = nil

    for axisName, axis in pairs(box.axes) do
        local e = dot(axis, p)
        local f = dot(axis, dir)

        if math.abs(f) > 1e-6 then
            local t1 = (e + box.halfSize[axisName]) / f
            local t2 = (e - box.halfSize[axisName]) / f

            if t1 > t2 then t1, t2 = t2, t1 end

            if t1 > tMin then
                tMin = t1
                hitNormal = axis
            end

            if t2 < tMax then
                tMax = t2
            end

            if tMin > tMax then return nil end
        else
            -- Ray parallel to slab
            if math.abs(e) > box.halfSize[axisName] then
                return nil
            end
        end
    end

    if tMin < 0 or tMin > maxDistance then return nil end

    local hitPos = add(origin, mul(dir, tMin))

    return {
        t = tMin,
        position = hitPos,
        normal = hitNormal,
        collider = box
    }
end

local function raycast(origin, direction, colliders)
    assert(type(origin) == "table" and _G.CountTableEntries(origin) == 3, "Ray origin must be a table with 3 fields (x, y, z)")
    assert(type(origin.x) == "number" and type(origin.y) == "number" and type(origin.z) == "number", "Ray origin fields must be numbers (x, y, z)")
    assert(type(direction) == "table" and _G.CountTableEntries(direction) == 3, "Ray direction must be a table with 3 fields (x, y, z)")
    assert(type(direction.x) == "number" and type(direction.y) == "number" and type(direction.z) == "number", "Ray direction fields must be numbers (x, y, z)")
    assert(type(colliders) == "table", "Colliders must be a table (array or dictionary of collider objects)")

    local closest = nil
    local minT = math.huge
    local closestKey = nil

    for key, col in pairs(colliders) do
        local hit = nil

        if col.type == "sphere" then
            hit = raySphere(origin, direction, col)
        elseif col.type == "obb" then
            hit = rayOBB(origin, direction, col)
        elseif col.type == "aabb" then
            hit = rayAABB(origin, direction, col)
        end

        if hit and hit.t < minT then
            minT = hit.t
            closest = hit
            closestKey = key
        end
    end

    if closest then
        closest.collider_index = closestKey
    end

    return closest
end

local module = {}

module.Sphere = makeSphere
module.AxisAlignedBoundingBox = makeAABB
module.OrientedBoundingBox = makeOBB
module.Raycast = raycast

return module
