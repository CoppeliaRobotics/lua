sim = require 'sim'

_S.conveyor = {}

function sysCall_actuation()
    _S.conveyor.actuation()
end

function sysCall_afterSimulation()
    _S.conveyor.afterSimulation()
end

function _S.conveyor.init(config)
    _S.conveyor.config = config
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
    _S.conveyor.prevPos = 0
    _S.conveyor.targetVel = _S.conveyor.config.targetVel
    _S.conveyor.targetPos = nil
    sim.writeCustomTableData(
        _S.conveyor.model, '__state__', {pos = _S.conveyor.pos, vel = _S.conveyor.vel}
    )

    _S.conveyor.forwarder = sim.getObject('../forwarder')

    local fingerPrint = sim.readCustomBufferData(_S.conveyor.model, '__fingerPrint__')
    if sim.packTable(_S.conveyor.config) ~= fingerPrint then
        sim.writeCustomBufferData(
            _S.conveyor.model, '__fingerPrint__', sim.packTable(_S.conveyor.config)
        )
        local visible1 = sim.getObject('../visible1')
        local visible2 = sim.getObject('../visible2')

        sim.setShapeColor(visible1, '', sim.colorcomponent_ambient_diffuse, _S.conveyor.config.color)
        sim.setShapeColor(
            visible2, '', sim.colorcomponent_ambient_diffuse, _S.conveyor.config.frameColor
        )
        sim.setShapeBB(
            visible1,
            {_S.conveyor.config.length, _S.conveyor.config.width, _S.conveyor.config.height}
        )
        sim.setShapeBB(
            visible2, {
                _S.conveyor.config.length + 0.005, _S.conveyor.config.width + 0.005,
                _S.conveyor.config.height,
            }
        )
        sim.setShapeBB(
            _S.conveyor.forwarder,
            {_S.conveyor.config.length, _S.conveyor.config.width, _S.conveyor.config.height}
        )
        sim.setObjectPosition(visible1, {0, 0, -_S.conveyor.config.height / 2}, _S.conveyor.model)
        sim.setObjectPosition(
            visible2, {0, 0, -_S.conveyor.config.height / 2 - 0.0025}, _S.conveyor.model
        )
        sim.setObjectPosition(
            _S.conveyor.forwarder, {0, 0, -_S.conveyor.config.height / 2}, _S.conveyor.model
        )
    end
end

function _S.conveyor.afterSimulation()
    _S.conveyor.vel = 0
    _S.conveyor.pos = 0
    _S.conveyor.prevPos = 0
    _S.conveyor.targetVel = _S.conveyor.config.targetVel
    _S.conveyor.targetPos = nil
    sim.writeCustomTableData(
        _S.conveyor.model, '__state__', {pos = _S.conveyor.pos, vel = _S.conveyor.vel}
    )
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
        _S.conveyor.setPos(_S.conveyor.pos)
        sim.writeCustomTableData(
            _S.conveyor.model, '__state__', {pos = _S.conveyor.pos, vel = _S.conveyor.vel}
        )
    end
end

function _S.conveyor.setPos(p)
    -- Here we "fake" the transportation pads with a single static rectangle that we dynamically reset
    -- at each simulation pass (while not forgetting to set its initial velocity vector) :

    local relativeLinearVelocity = {(p - _S.conveyor.prevPos) / sim.getSimulationTimeStep(), 0, 0}
    _S.conveyor.prevPos = p

    -- Reset the dynamic rectangle from the simulation (it will be removed and added again)
    sim.resetDynamicObject(_S.conveyor.forwarder)
    -- Compute the absolute velocity vector:
    local m = sim.getObjectMatrix(_S.conveyor.forwarder)
    m[4] = 0 -- Make sure the translation component is discarded
    m[8] = 0 -- Make sure the translation component is discarded
    m[12] = 0 -- Make sure the translation component is discarded
    local absoluteLinearVelocity = sim.multiplyVector(m, relativeLinearVelocity)
    -- Now set the initial velocity of the dynamic rectangle:
    sim.setObjectFloatParam(
        _S.conveyor.forwarder, sim.shapefloatparam_init_velocity_x, absoluteLinearVelocity[1]
    )
    sim.setObjectFloatParam(
        _S.conveyor.forwarder, sim.shapefloatparam_init_velocity_y, absoluteLinearVelocity[2]
    )
    sim.setObjectFloatParam(
        _S.conveyor.forwarder, sim.shapefloatparam_init_velocity_z, absoluteLinearVelocity[3]
    )
end

require 'configUi'

function sysCall_init()
    self = sim.getObject('..')
    local c = sim.readCustomTableData(self, '__config__')
    if next(c) == nil then
        c.length = 1
        c.width = 0.2
        c.height = 0.1
        c.color = {0.2, 0.2, 0.2}
        c.frameColor = {0.5, 0.5, 0.5}
        c.targetVel = 0.1
        c.accel = 0.01
        sim.writeCustomTableData(self, '__config__', c)
    end
    conveyor.init(c)
end

schema = {
    length = {
        type = 'float',
        name = 'Length',
        default = 1,
        minimum = 0.1,
        maximum = 100,
        ui = {control = 'spinbox', order = 1},
    },
    width = {
        type = 'float',
        name = 'Width',
        default = 0.2,
        minimum = 0.01,
        maximum = 10,
        ui = {control = 'spinbox', order = 2},
    },
    height = {
        type = 'float',
        name = 'Height',
        default = 0.1,
        minimum = 0.01,
        maximum = 0.5,
        ui = {control = 'spinbox', order = 3},
    },
    targetVel = {
        type = 'float',
        name = 'Target velocity',
        default = 0.1,
        minimum = -5,
        maximum = 5,
        ui = {control = 'spinbox', order = 4},
    },
    accel = {
        type = 'float',
        name = 'Acceleration',
        default = 0.01,
        minimum = 0.001,
        maximum = 100,
        ui = {control = 'spinbox', order = 5},
    },
    color = {
        type = 'color',
        name = 'Belt color',
        default = {0.2, 0.2, 0.2},
        ui = {order = 6}
    },
    frameColor = {
        type = 'color',
        name = 'Frame color',
        default = {0.5, 0.5, 0.5},
        ui = {order = 7}
    },
}

configUi = ConfigUI('Conveyor', schema, _S.conveyor.init)
configUi.getObjectCallback = function() return sim.getObject '..' end

return _S.conveyor
