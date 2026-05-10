# DXRaycast Lua Module

A fast and lightweight Lua module for 3D raycasting against common collider types: spheres, axis-aligned bounding boxes (AABB), and oriented bounding boxes (OBB). Designed for use in DX9Ware scripts and compatible Lua environments.

## Features
- Raycast against spheres, AABBs, and OBBs
- Simple API for defining colliders
- Returns detailed hit information (position, normal, collider)
- No external dependencies

## Usage

```lua
local DXRaycast = loadstring(dx9.Get("https://raw.githubusercontent.com/Brycki404/DXRaycast/refs/heads/main/main.lua"))()

-- Define a sphere collider
local sphere = DXRaycast.Sphere({x=0, y=0, z=0}, 5)

-- Define an AABB collider
local aabb = DXRaycast.AxisAlignedBoundingBox({x=-1, y=-1, z=-1}, {x=1, y=1, z=1})

-- Define an OBB collider
local axes = {
    x = {x=1, y=0, z=0},
    y = {x=0, y=1, z=0},
    z = {x=0, y=0, z=1}
}
local center = {x=0, y=0, z=0}
local halfSize = {x=1, y=2, z=1}
local obb = DXRaycast.OrientedBoundingBox(center, halfSize, axes)

-- direction vector: direction and max distance (magnitude)
local direction = {x=-10, y=0, z=0} -- Will be normalized internally, max distance = 10

-- Raycast
local origin = {x=10, y=0, z=0}
local direction = {x=-1, y=0, z=0} -- Must be normalized (already is)
local normalized_direction = 
local colliders = {sphere, aabb, obb}
local hit = DXRaycast.Raycast(origin, direction, colliders)

if hit then
    print("Hit at:", hit.position.x, hit.position.y, hit.position.z)
    print("Normal:", hit.normal.x, hit.normal.y, hit.normal.z)
    print("Collider type:", hit.collider.type)
    print("Collider index:", hit.collider_index)
else
    print("No hit detected.")
end
```

## API
- `DXRaycast.Sphere(center, radius, isTarget)`
- `DXRaycast.AxisAlignedBoundingBox(min, max, isTarget)`
- `DXRaycast.OrientedBoundingBox(center, halfSize, axes, isTarget)`
- `DXRaycast.Raycast(origin, direction, colliders)`

**Note:** The `direction` argument is a vector whose magnitude is the maximum raycast distance. The direction will be normalized internally.
