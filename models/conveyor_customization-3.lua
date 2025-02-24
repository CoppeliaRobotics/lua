sim = require 'sim'
simQHull = require 'simQHull'
path = require('models.path_customization-2')

_S.conveyor = {}

function sysCall_actuation()
    _S.conveyor.actuation()
end

function sysCall_afterSimulation()
    _S.conveyor.afterSimulation()
end

function _S.conveyor.init2(config)
    _S.conveyor.config = sim.unpackTable(sim.packTable(config))
    _S.conveyor.model = sim.getObject('..')
    sim.writeCustomTableData(
        _S.conveyor.model, '__info__', {
            type = 'conveyor',
            blocks = {
                __config__ = {type = "table"},
                __ctrl__ = {type = "table"},
                __state__ = {type = "table"},
            },
        }
    )

    _S.conveyor.vel = 0
    _S.conveyor.pos = 0
    _S.conveyor.targetVel = _S.conveyor.config.targetVel
    _S.conveyor.targetPos = nil
    sim.writeCustomTableData(
        _S.conveyor.model, '__state__', {pos = _S.conveyor.pos, vel = _S.conveyor.vel}
    )

    _S.conveyor.getPathData()
    local padCnt = _S.conveyor.totalLength //
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
    local fingerPrint = sim.readCustomBufferData(_S.conveyor.model, '__fingerPrint__')
    if sim.packTable(_S.conveyor.config) ~= fingerPrint then
        _S.conveyor.rebuildConveyor(oldPads, oldJoints)
    else
        _S.conveyor.padHandles = oldPads -- reuse old pads, they are the same
        _S.conveyor.rolHandles = oldJoints
    end
    if _S.conveyor.config.type == 1 then _S.conveyor.setPathPos(_S.conveyor.pos) end
end

function _S.conveyor.getPathData()
    -- Build the shape from the control points path, since the other path is interpolated and does only work well with enough interpol. points:
    -- Instead of:
    -- local pathData=sim.unpackDoubleTable(sim.readCustomBufferData(_S.conveyor.model,'PATH'))
    -- We do:
    local pathData =
        sim.unpackDoubleTable(sim.readCustomBufferData(_S.conveyor.model, 'PATHCTRLPTS'))
    for i = 1, 7, 1 do pathData[#pathData + 1] = pathData[i] end

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
end

function _S.conveyor.rebuildConveyor(oldPads, oldJoints)
    sim.writeCustomBufferData(_S.conveyor.model, '__fingerPrint__', sim.packTable(_S.conveyor.config))
    path.forceFullRebuild = true
    local ctrlPts = path.init()
    local r = _S.conveyor.config.radius
    local vo = r + _S.conveyor.config.beltElementThickness
    if _S.conveyor.config.type == 2 then
        vo = r
        r = r * 0.5
    end
    for i = 1, 9, 1 do
        local a = math.pi / 2 - (i - 1) * math.pi / 8
        sim.setObjectPosition(
            ctrlPts[i], {r * math.cos(a) + _S.conveyor.config.length / 2, 0, r * math.sin(a) - vo},
            _S.conveyor.model
        )
        sim.setObjectOrientation(ctrlPts[i], {0, -a + math.pi / 2, 0}, _S.conveyor.model)
        sim.setObjectPosition(
            ctrlPts[9 + i],
            {-r * math.cos(a) - _S.conveyor.config.length / 2, 0, r * math.sin(-a) - vo},
            _S.conveyor.model
        )
        sim.setObjectOrientation(ctrlPts[9 + i], {0, -math.pi / 2 - a, 0}, _S.conveyor.model)
    end
    path.setup()

    _S.conveyor.getPathData()

    sim.removeObjects(oldPads)
    for i = 1, #oldJoints, 1 do
        sim.removeObjects({sim.getObjectChild(oldJoints[i], 0)})
        sim.removeObjects({oldJoints[i]})
    end
    if _S.conveyor.config.type == 2 then
        local dx = _S.conveyor.config.length / (_S.conveyor.config.rollerCnt - 1)
        for i = 1, _S.conveyor.config.rollerCnt, 1 do
            local cyl = sim.createPrimitiveShape(
                            sim.primitiveshape_cylinder, {
                    _S.conveyor.config.radius * 2, _S.conveyor.config.radius * 2,
                    _S.conveyor.config.width * 0.95,
                }
                        )
            if _S.conveyor.config.respondable then
                sim.setObjectInt32Param(cyl, sim.shapeintparam_respondable, 1)
            end
            sim.setShapeMass(cyl, 0.01)

            local jnt = sim.createJoint(sim.joint_revolute, sim.jointmode_kinematic, 0)
            _S.conveyor.rolHandles[i] = jnt
            sim.setObjectParent(cyl, jnt, true)
            sim.setObjectAlias(jnt, 'jrol')
            sim.setObjectAlias(cyl, 'rol')
            sim.setShapeColor(cyl, nil, sim.colorcomponent_ambient_diffuse, _S.conveyor.config.color)
            sim.setObjectParent(jnt, _S.conveyor.model, true)
            sim.writeCustomStringData(jnt, 'PATHROL', 'a')
            sim.setObjectProperty(cyl, sim.objectproperty_selectmodelbaseinstead)
            sim.setObjectInt32Param(jnt, sim.objintparam_visibility_layer, 512)
            local m = Matrix3x3:rotx(-math.pi / 2)
            sim.setObjectPosition(
                jnt, {-_S.conveyor.config.length / 2 + dx * (i - 1), 0, -_S.conveyor.config.radius},
                _S.conveyor.model
            )
            sim.setObjectQuaternion(jnt, Matrix3x3:toquaternion(m), _S.conveyor.model)
        end
    else
        local padCnt = _S.conveyor.totalLength //
                           (_S.conveyor.config.beltElementWidth +
                               _S.conveyor.config.beltElementSpacing)
        _S.conveyor.padOffset = (_S.conveyor.totalLength / padCnt)
        for i = 1, padCnt, 1 do
            _S.conveyor.padHandles[i] = sim.createPrimitiveShape(
                                            sim.primitiveshape_cuboid, {
                    _S.conveyor.config.beltElementWidth, _S.conveyor.config.width,
                    _S.conveyor.config.beltElementThickness,
                }
                                        )
            if _S.conveyor.config.respondable then
                sim.setObjectInt32Param(_S.conveyor.padHandles[i], sim.shapeintparam_respondable, 1)
                sim.setBoolProperty(_S.conveyor.padHandles[i], 'kinematic', true)
            end
            sim.setShapeMass(_S.conveyor.padHandles[i], 0.01)

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

function _S.conveyor.afterSimulation()
    _S.conveyor.vel = 0
    _S.conveyor.pos = 0
    _S.conveyor.targetVel = _S.conveyor.config.targetVel
    _S.conveyor.targetPos = nil
    sim.writeCustomTableData(
        _S.conveyor.model, '__state__', {pos = _S.conveyor.pos, vel = _S.conveyor.vel}
    )
    path.afterSimulation()
end

function _S.conveyor.actuation()
    local prevPos = _S.conveyor.pos
    local dat = sim.readCustomTableData(_S.conveyor.model, '__ctrl__')
    if next(dat) ~= nil then
        sim.writeCustomTableData(_S.conveyor.model, '__ctrl__', {})
        if dat.pos then
            _S.conveyor.targetPos = dat.pos
            _S.conveyor.targetVel = nil
        end
        if dat.vel then
            _S.conveyor.targetVel = dat.vel
            _S.conveyor.targetPos = nil
        end
    end
    if _S.conveyor.targetVel then
        local rml = sim.ruckigVel(
                        1, 0.0001, -1, {_S.conveyor.pos, _S.conveyor.vel, 0},
                        {_S.conveyor.config.accel, 99999}, {1}, {_S.conveyor.targetVel}
                    )
        local r, newPosVelAccel = sim.ruckigStep(rml, sim.getSimulationTimeStep())
        if r == 0 then
            _S.conveyor.pos = newPosVelAccel[1]
            _S.conveyor.vel = newPosVelAccel[2]
        else
            _S.conveyor.vel = _S.conveyor.targetVel
            _S.conveyor.pos = _S.conveyor.pos + _S.conveyor.vel * sim.getSimulationTimeStep()
        end
        sim.ruckigRemove(rml)
    end
    if _S.conveyor.targetPos then
        local rml = sim.ruckigPos(
                        1, 0.0001, -1, {_S.conveyor.pos, _S.conveyor.vel, 0},
                        {99999, _S.conveyor.config.accel, 99999}, {1}, {_S.conveyor.targetPos, 0}
                    )
        local r, newPosVelAccel = sim.ruckigStep(rml, sim.getSimulationTimeStep())
        if r == 0 then
            _S.conveyor.pos = newPosVelAccel[1]
            _S.conveyor.vel = newPosVelAccel[2]
        else
            _S.conveyor.vel = 0
            _S.conveyor.pos = _S.conveyor.targetPos
        end
        sim.ruckigRemove(rml)
    end
    if prevPos ~= _S.conveyor.pos then
        if _S.conveyor.config.type == 2 then
            for i = 1, #_S.conveyor.rolHandles, 1 do
                sim.setJointPosition(
                    _S.conveyor.rolHandles[i], _S.conveyor.pos / _S.conveyor.config.radius
                )
            end
        else
            _S.conveyor.setPathPos(_S.conveyor.pos)
        end
        sim.writeCustomTableData(
            _S.conveyor.model, '__state__', {pos = _S.conveyor.pos, vel = _S.conveyor.vel}
        )
    end
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
    -- Build the shape from the control points path, since the other path is interpolated and does only work well with enough interpol. points:
    local path = sim.unpackDoubleTable(sim.readCustomBufferData(sim.getObject '..', 'PATHCTRLPTS'))
    local shape = sim.generateShapeFromPath(path, section, options, upVector)
    local vert, ind = sim.getShapeMesh(shape)
    vert, ind = simQHull.compute(vert, true)
    vert = sim.multiplyVector(sim.getObjectMatrix(shape, -1), vert)
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

sysCall_userConfig = nil -- path UI
require 'configUi'

function sysCall_init()
    _S.conveyor.init()
end

function _S.conveyor.init()
    self = sim.getObject('..')
    local c = sim.readCustomTableData(self, '__config__')
    if next(c) == nil then
        c.type = 1 -- belt
        c.length = 1
        c.width = 0.2
        c.radius = 0.1
        c.color = {0.2, 0.2, 0.2}
        c.frameColor = {0.5, 0.5, 0.5}
        c.respondable = true
        c.rollerCnt = 16
        c.beltElementWidth = 0.05
        c.beltElementThickness = 0.005
        c.beltElementSpacing = 0.002
        c.targetVel = 0.1
        c.accel = 0.01
        sim.writeCustomTableData(self, '__config__', c)
    end
    _S.conveyor.config = c
    path.init() -- might call path.shaping
    _S.conveyor.init2(c)
end

schema = {
    length = {
        type = 'float',
        name = 'Conveyor length',
        default = 1,
        minimum = 0.1,
        maximum = 100,
        ui = {control = 'spinbox', order = 1, col = 1, tab = 'general'},
    },
    width = {
        type = 'float',
        name = 'Conveyor width',
        default = 0.2,
        minimum = 0.01,
        maximum = 10,
        ui = {control = 'spinbox', order = 2, col = 1, tab = 'general'},
    },
    radius = {
        type = 'float',
        name = 'Conveyor radius (ends)',
        default = 0.1,
        minimum = 0.01,
        maximum = 0.5,
        ui = {control = 'spinbox', order = 3, col = 1, tab = 'general'},
    },
    targetVel = {
        type = 'float',
        name = 'Target velocity',
        default = 0.1,
        minimum = -5,
        maximum = 5,
        ui = {control = 'spinbox', order = 4, col = 1, tab = 'general'},
    },
    accel = {
        type = 'float',
        name = 'Acceleration',
        default = 0.01,
        minimum = 0.001,
        maximum = 100,
        ui = {control = 'spinbox', order = 5, col = 1, tab = 'general'},
    },
    color = {
        type = 'color',
        name = 'Belt/rollers color',
        default = {0.2, 0.2, 0.2},
        ui = {order = 6, col = 1, tab = 'general'},
    },
    frameColor = {
        type = 'color',
        name = 'Frame color',
        default = {0.5, 0.5, 0.5},
        ui = {order = 7, col = 1, tab = 'general'},
    },
    type = {
        name = 'Conveyor type',
        choices = {[1] = 'belt', [2] = 'roller'},
        default = 1,
        ui = {control = 'radio', order = 8, col = 1, tab = 'general'},
    },
    respondable = {
        type = 'bool',
        name = 'Conveyor is respondable',
        default = true,
        ui = {order = 9, col = 1, tab = 'general'},
    },
    beltElementWidth = {
        type = 'float',
        name = 'Belt element length',
        default = 0.05,
        minimum = 0.005,
        maximum = 0.5,
        ui = {control = 'spinbox', order = 10, col = 1, tab = "belt-type"},
    },
    beltElementThickness = {
        type = 'float',
        name = 'Belt element thickness',
        default = 0.005,
        minimum = 0.001,
        maximum = 0.2,
        ui = {control = 'spinbox', order = 11, col = 1, tab = "belt-type"},
    },
    beltElementSpacing = {
        type = 'float',
        name = 'Belt element spacing',
        default = 0.01,
        minimum = -0.1,
        maximum = 2,
        ui = {control = 'spinbox', order = 12, col = 1, tab = "belt-type"},
    },
    rollerCnt = {
        type = 'int',
        name = 'Roller count',
        default = 8,
        minimum = 2,
        maximum = 500,
        ui = {control = 'spinbox', order = 20, col = 1, tab = "roller-type"},
    },
}

configUi = ConfigUI('Conveyor', schema, _S.conveyor.init2)
configUi.getObjectCallback = function() return sim.getObject '..' end

return _S.conveyor
