local shapeutils = {}

local sim = require 'sim'
local simEigen = require 'simEigen'
local Vector = simEigen.Vector
local Matrix = simEigen.Matrix

function shapeutils.createCuboidAtPoints(a, b, c, d, thickness, tol)
    assert(thickness > 0, 'thickness must be positive')
    tol = tol or 1e-3
    a = Vector:tovector(a, 3)
    b = Vector:tovector(b, 3)
    c = Vector:tovector(c, 3)
    d = Vector:tovector(d, 3)
    -- a, b, c, d to be specified in counter-clockwise order
    local dx = b - a
    assert(math.abs(dx:norm() - (c - d):norm()) < tol, 'not a parallelogram: |a-b|!=|c-d|')
    local dy = d - a
    assert(math.abs(dy:norm() - (c - b):norm()) < tol, 'not a parallelogram: |a-d|!=|b-c|')
    assert(math.abs(dx:dot(dy)) < tol, 'not a rectangle')
    assert(math.abs((a + c - b - d):norm()) < tol, 'not a rectangle')
    local nx, ny = dx:normalized(), dy:normalized()
    local nz = nx:cross(ny)
    local dz = nz * thickness
    local shapeHandle = sim.createPrimitiveShape(sim.primitiveshape_cuboid, {dx:norm(), dy:norm(), thickness})
    local R = Matrix:horzcat(nx, ny, nz)
    local p = (a + c + dz) / 2
    local T = Matrix:horzcat(R, p)
    sim.setObjectMatrix(shapeHandle, T:data())
    return shapeHandle
end

function shapeutils.createShapeAtPoints(a, b, diameter, shapeType)
    assert(diameter > 0, 'diameter must be positive')
    a = Vector:tovector(a, 3)
    b = Vector:tovector(b, 3)
    local p = (a + b) / 2
    local dz = a - b
    local nz = dz:normalized()
    local shapeHandle = sim.createPrimitiveShape(shapeType, {diameter, diameter, dz:norm()})
    local v = math.abs(nz[3]) < 0.9 and Vector{0, 0, 1} or Vector{1, 0, 0}
    local nx = v:cross(nz):normalized()
    local ny = nz:cross(nx):normalized()
    local R = Matrix:horzcat(nx, ny, nz)
    local T = Matrix:horzcat(R, p)
    sim.setObjectMatrix(shapeHandle, T:data())
    return shapeHandle
end

function shapeutils.createCylinderAtPoints(a, b, diameter)
    return shapeutils.createShapeAtPoints(a, b, diameter, sim.primitiveshape_cylinder)
end

function shapeutils.createCapsuleAtPoints(a, b, diameter, opts)
    opts = opts or {}
    if opts.alt ~= true then
        local dz = a - b
        local nz = dz:normalized()
        local off = diameter * 0.5 * nz
        a = a + off
        b = b - off
    end
    return shapeutils.createShapeAtPoints(a, b, diameter, sim.primitiveshape_capsule)
end

function shapeutils.createJointShape(j)
    local t = sim.getIntProperty(j, 'joint.type')
    local length = sim.getFloatProperty(j, 'length')
    local diameter = sim.getFloatProperty(j, 'diameter')
    local shapeType, size
    if t == sim.joint_prismatic then
        shapeType, size = sim.primitiveshape_cuboid, {diameter, diameter, length}
    elseif t == sim.joint_revolute then
        shapeType, size = sim.primitiveshape_cylinder, {diameter, diameter, length}
    elseif t == sim.joint_spherical then
        shapeType, size = sim.primitiveshape_sphere, {diameter, diameter, diameter}
    else
        error 'unsupported joint type'
    end
    local shapeHandle = sim.createPrimitiveShape(shapeType, size)
    sim.setObjectPose(shapeHandle, sim.getObjectPose(j))
    return shapeHandle
end

return shapeutils
