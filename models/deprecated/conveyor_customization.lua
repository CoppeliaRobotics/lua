-- Keep lazy loading
-- back-compatibility version for CoppeliaSim V4.2.0
path = require('models.deprecated.path_customization')
simQHull = require 'simQHull'

_S.conveyor = {}

function sysCall_actuation()
    _S.conveyor.actuation()
end

function sysCall_afterSimulation()
    _S.conveyor.afterSimulation()
end

function _S.conveyor.init(config)
    if config.padSize then
        -- backward compatibility
        local c = {}
        c.length = config.length
        if config.useRollers then
            c.width = config.rollerLength
        else
            c.width = config.padSize[2]
        end
        c.radius = config.radius
        c.color = config.padCol
        c.frameColor = config.col
        c.type = config.useRollers and 2 or 1
        c.respondable = config.respondablePads
        c.beltElementWidth = config.padSize[1]
        c.beltElementThickness = config.padSize[3]
        c.beltElementSpacing = config.interPadSpace
        c.rollerCnt = config.rollerCnt
        c.initPos = config.initPos
        c.initVel = config.initVel
        config = c
    else
        config.initPos = 0
        config.initVel = 0
    end

    _S.conveyor.config = config
    _S.conveyor.model = sim.getObject('.')

    _S.conveyor.velocity = _S.conveyor.config.initVel
    _S.conveyor.offset = _S.conveyor.config.initPos
    sim.writeCustomBufferData(
        _S.conveyor.model, 'CONVMOV', sim.packTable({currentPos = _S.conveyor.offset})
    )

    local ctrlPts = path.init()
    local r = _S.conveyor.config.radius
    if _S.conveyor.config.type == 2 then r = r * 0.5 end
    for i = 1, 9, 1 do
        local a = math.pi / 2 - (i - 1) * math.pi / 8
        sim.setObjectPosition(
            ctrlPts[i], {r * math.cos(a) + _S.conveyor.config.length / 2, 0, r * math.sin(a)},
            _S.conveyor.model
        )
        sim.setObjectPosition(
            ctrlPts[9 + i], {-r * math.cos(a) - _S.conveyor.config.length / 2, 0, r * math.sin(-a)},
            _S.conveyor.model
        )
    end
    local padCnt
    local ctrlPts, pathData = path.setup()
    local m = Matrix(math.floor(#pathData / 7), 7, pathData)
    _S.conveyor.pathPositions = m:slice(1, 1, m:rows(), 3):data()
    _S.conveyor.pathQuaternions = m:slice(1, 4, m:rows(), 7):data()
    _S.conveyor.pathLengths, _S.conveyor.totalLength = sim.getPathLengths(
                                                           _S.conveyor.pathPositions, 3
                                                       )
    if _S.conveyor.config.type == 1 then
        -- shift positions towards the outside, by the half thickness of the pads:
        for i = 1, m:rows(), 1 do
            local rot = Matrix3x3:fromquaternion(m:slice(i, 4, i, 7):data())
            local zaxis = rot:slice(1, 3, 3, 3)
            local p = m:slice(i, 1, i, 3):t()
            p = p + zaxis * _S.conveyor.config.beltElementThickness / 2
            _S.conveyor.pathPositions[3 * (i - 1) + 1] = p[1]
            _S.conveyor.pathPositions[3 * (i - 1) + 2] = p[2]
            _S.conveyor.pathPositions[3 * (i - 1) + 3] = p[3]
        end
    end

    padCnt = _S.conveyor.totalLength //
                 (_S.conveyor.config.beltElementWidth + _S.conveyor.config.beltElementSpacing)
    _S.conveyor.padOffset = (_S.conveyor.totalLength / padCnt)

    local shapes = sim.getObjectsInTree(_S.conveyor.model, sim.sceneobject_shape, 1 + 2)
    local oldPads = {}
    for i = 1, #shapes, 1 do
        local dat = sim.readCustomStringData(shapes[i], 'PATHPAD')
        if dat and #dat > 0 then oldPads[#oldPads + 1] = shapes[i] end
    end

    local joints = sim.getObjectsInTree(_S.conveyor.model, sim.sceneobject_joint, 1 + 2)
    local oldJoints = {}
    for i = 1, #joints, 1 do
        local dat = sim.readCustomStringData(joints[i], 'PATHROL')
        if dat and #dat > 0 then oldJoints[#oldJoints + 1] = joints[i] end
    end

    _S.conveyor.padHandles = {}
    _S.conveyor.rolHandles = {}
    if padCnt == #oldPads and _S.conveyor.config.rollerCnt == #oldJoints and
        sim.packTable(_S.conveyor.config) ==
        sim.readCustomBufferData(_S.conveyor.model, 'CONVEYORSET') then
        _S.conveyor.padHandles = oldPads -- reuse old pads, they are the same
        _S.conveyor.rolHandles = oldJoints
    else
        sim.writeCustomBufferData(_S.conveyor.model, 'CONVEYORSET', sim.packTable(_S.conveyor.config))
        sim.removeObjects(oldPads)
        for i = 1, #oldJoints, 1 do
            sim.removeObjects({sim.getObjectChild(oldJoints[i], 0)})
            sim.removeObjects({oldJoints[i]})
        end
        if _S.conveyor.config.type == 2 then
            local dx = _S.conveyor.config.length / (_S.conveyor.config.rollerCnt - 1)
            for i = 1, _S.conveyor.config.rollerCnt, 1 do
                local opt = 16
                if _S.conveyor.config.respondable then opt = opt + 8 end
                local cyl = sim.createPureShape(
                                2, opt, {
                        _S.conveyor.config.radius * 2, _S.conveyor.config.radius * 2,
                        _S.conveyor.config.width * 0.95,
                    }, 0.01
                            )
                local jnt = sim.createJoint(sim.joint_revolute, sim.jointmode_kinematic, 0)
                _S.conveyor.rolHandles[i] = jnt
                sim.setObjectParent(cyl, jnt, true)
                sim.setObjectAlias(jnt, 'jrol')
                sim.setObjectAlias(cyl, 'rol')
                sim.setShapeColor(
                    cyl, nil, sim.colorcomponent_ambient_diffuse, _S.conveyor.config.color
                )
                sim.setObjectParent(jnt, _S.conveyor.model, true)
                sim.writeCustomStringData(jnt, 'PATHROL', 'a')
                sim.setObjectProperty(cyl, sim.objectproperty_selectmodelbaseinstead)
                sim.setObjectInt32Param(jnt, sim.objintparam_visibility_layer, 512)
                local m = Matrix3x3:rotx(-math.pi / 2)
                sim.setObjectPosition(
                    jnt, {-_S.conveyor.config.length / 2 + dx * (i - 1), 0, 0}, _S.conveyor.model
                )
                sim.setObjectQuaternion(jnt, Matrix3x3:toquaternion(m), _S.conveyor.model)
            end
        else
            for i = 1, padCnt, 1 do
                local opt = 16
                if _S.conveyor.config.respondable then opt = opt + 8 end
                _S.conveyor.padHandles[i] = sim.createPureShape(
                                                0, opt, {
                        _S.conveyor.config.beltElementWidth, _S.conveyor.config.width,
                        _S.conveyor.config.beltElementThickness,
                    }, 0.01
                                            )
                if _S.conveyor.config.respondable then
                    sim.setBoolProperty(_S.conveyor.padHandles[i], 'kinematic', true)
                end
                sim.setObjectAlias(_S.conveyor.padHandles[i], 'pad')
                sim.setShapeColor(
                    _S.conveyor.padHandles[i], nil, sim.colorcomponent_ambient_diffuse,
                    _S.conveyor.config.color
                )
                sim.setObjectParent(_S.conveyor.padHandles[i], _S.conveyor.model, true)
                sim.writeCustomStringData(_S.conveyor.padHandles[i], 'PATHPAD', 'a')
                sim.setObjectProperty(
                    _S.conveyor.padHandles[i], sim.objectproperty_selectmodelbaseinstead
                )
            end
        end
    end
    if _S.conveyor.config.type == 1 then _S.conveyor.setPathPos(_S.conveyor.offset) end
end

function _S.conveyor.afterSimulation()
    _S.conveyor.velocity = _S.conveyor.config.initVel
    _S.conveyor.offset = _S.conveyor.config.initPos
    sim.writeCustomBufferData(
        _S.conveyor.model, 'CONVMOV', sim.packTable({currentPos = _S.conveyor.offset})
    )

    path.afterSimulation()
end

function _S.conveyor.actuation()
    local dat = sim.readCustomBufferData(_S.conveyor.model, 'CONVMOV')
    local off
    if dat and #dat > 0 then
        dat = sim.unpackTable(dat)
        if dat.offset then off = dat.offset end
        if dat.vel then _S.conveyor.velocity = dat.vel end
    end
    if off or _S.conveyor.velocity ~= 0 then
        if off then
            _S.conveyor.offset = off
        else
            _S.conveyor.offset = _S.conveyor.offset + _S.conveyor.velocity *
                                     sim.getSimulationTimeStep()
        end
        if _S.conveyor.config.type == 2 then
            for i = 1, #_S.conveyor.rolHandles, 1 do
                sim.setJointPosition(
                    _S.conveyor.rolHandles[i], _S.conveyor.offset / _S.conveyor.config.radius
                )
            end
        else
            _S.conveyor.setPathPos(_S.conveyor.offset)
        end
    end
    if not dat then dat = {} end
    dat.currentPos = _S.conveyor.offset
    sim.writeCustomBufferData(_S.conveyor.model, 'CONVMOV', sim.packTable(dat))
end

function path.shaping(path, pathIsClosed, upVector)
    local section
    if _S.conveyor.config.type == 2 then
        section = {
            0, -_S.conveyor.config.width / 2, 0, _S.conveyor.config.width / 2,
            -3 * _S.conveyor.config.radius / 4, _S.conveyor.config.width / 2,
            -3 * _S.conveyor.config.radius / 4, -_S.conveyor.config.width / 2, 0,
            -_S.conveyor.config.width / 2,
        }
    else
        section = {
            0, -_S.conveyor.config.width / 2, 0, _S.conveyor.config.width / 2,
            -3 * _S.conveyor.config.radius / 4, _S.conveyor.config.width / 2,
            -3 * _S.conveyor.config.radius / 4, -_S.conveyor.config.width / 2, 0,
            -_S.conveyor.config.width / 2,
        }
    end
    local options = 0
    if pathIsClosed then options = options | 4 end
    local shape = sim.generateShapeFromPath(path, section, options, upVector)
    local vert, ind = sim.getShapeMesh(shape)
    vert, ind = simQHull.compute(vert, true)
    vert = sim.multiplyVector(sim.getObjectMatrix(shape), vert)
    sim.removeObjects({shape})
    shape = sim.createShape(0, 0, vert, ind)
    sim.setShapeColor(shape, nil, sim.colorcomponent_ambient_diffuse, _S.conveyor.config.frameColor)
    if _S.conveyor.config.respondable then
        sim.setObjectInt32Param(shape, sim.shapeintparam_respondable, 1)
    end
    return shape
end

function _S.conveyor.setPathPos(p)
    for i = 1, #_S.conveyor.padHandles, 1 do
        p = p % _S.conveyor.totalLength
        local h = _S.conveyor.padHandles[i]
        local pos = sim.getPathInterpolatedConfig(
                        _S.conveyor.pathPositions, _S.conveyor.pathLengths, p
                    )
        local quat = sim.getPathInterpolatedConfig(
                         _S.conveyor.pathQuaternions, _S.conveyor.pathLengths, p, nil, {2, 2, 2, 2}
                     )
        sim.setObjectPosition(h, pos, _S.conveyor.model)
        sim.setObjectQuaternion(h, quat, _S.conveyor.model)
        p = p + _S.conveyor.padOffset
    end
end

return _S.conveyor
