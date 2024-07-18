sim = require 'sim'

_S.animator = {}

function sysCall_actuation()
    _S.animator.actuation()
end

function sysCall_beforeSimulation()
    local c = sim.readCustomTableData(_S.animator.self, '__config__')
    if next(c) == nil then
        c.loop = false
        c.loop = false
        c.backAndForth = false
        c.dirAndSpeed = 1
        c.initPos = 0
        c.immobile = false
        c.color = {1, 1, 1}
        sim.writeCustomTableData(_S.animator.self, '__config__', c)
    end
    _S.animator.config = c
    _S.animator.handles = sim.getReferencedHandles(_S.animator.self)
    _S.animator.animationData = sim.unpackTable(
                                    sim.readCustomBufferData(
                                        _S.animator.self, 'animationData'
                                    )
                                )
    _S.animator.totalTime = _S.animator.animationData.times[#_S.animator.animationData.times]
    _S.animator.prevTime = 0
    _S.animator.pos = _S.animator.config.initPos * _S.animator.totalTime
    local initM = sim.getObjectMatrix(_S.animator.self, sim.handle_parent)
    local p = _S.animator.animationData.initPoses[1]
    local m = sim.poseToMatrix(p)
    sim.invertMatrix(m)
    _S.animator.corrM = sim.multiplyMatrices(initM, m)
    for i = 2, #_S.animator.handles, 1 do
        if not sim.isHandle(_S.animator.handles[i]) then
            _S.animator.handles[i] = -1 -- maybe the user remove one shape that was not needed in the animation?
        end
    end
end

function _S.animator.updateColor(col)
    local h = sim.getObjectsInTree(_S.animator.self, sim.sceneobject_shape)
    for i = 1, #h, 1 do
        sim.setShapeColor(h[i], nil, sim.colorcomponent_ambient_diffuse, col)
        sim.setShapeColor(h[i], nil, sim.colorcomponent_specular, {0.1, 0.1, 0.1})
        sim.setShapeColor(h[i], nil, sim.colorcomponent_emission, {0, 0, 0})
        sim.setShapeTexture(h[i], -1, -1, 0, {1, 1})
    end
end

function _S.animator.actuation()
    local t = sim.getSimulationTime()
    local dt = t - _S.animator.prevTime
    local stop = false
    _S.animator.prevTime = t
    local newPos = _S.animator.pos + _S.animator.config.dirAndSpeed * dt
    if _S.animator.config.dirAndSpeed >= 0 then
        if newPos > _S.animator.totalTime then
            if _S.animator.config.loop or _S.animator.config.backAndForth then
                if _S.animator.config.backAndForth then
                    _S.animator.config.dirAndSpeed = _S.animator.config.dirAndSpeed * -1
                    newPos = 2 * _S.animator.totalTime - newPos
                else
                    newPos = newPos - _S.animator.totalTime
                end
            else
                stop = true
                newPos = _S.animator.totalTime
            end
        end
    else
        if newPos < 0 then
            if _S.animator.config.loop then
                _S.animator.config.dirAndSpeed = _S.animator.config.dirAndSpeed * -1
                newPos = newPos * -1
            else
                stop = true
                newPos = 0
            end
        end
    end
    _S.animator.pos = newPos
    if not stop then _S.animator.applyPos() end
end

function _S.animator.applyPos()
    for i = 1, #_S.animator.handles, 1 do
        if _S.animator.handles[i] ~= -1 then
            local p = sim.getPathInterpolatedConfig(
                          _S.animator.animationData.poses[i], _S.animator.animationData.times,
                          _S.animator.pos, {type = 'linear'}, {0, 0, 0, 2, 2, 2, 2}
                      )
            if i == 1 then
                if not _S.animator.config.immobile then
                    local m = sim.multiplyMatrices(_S.animator.corrM, sim.poseToMatrix(p))
                    sim.setObjectMatrix(_S.animator.handles[i], m, sim.handle_parent)
                end
            else
                sim.setObjectPose(_S.animator.handles[i], p, sim.handle_parent)
            end
        end
    end
end

require 'configUi'

function gen(config)
    if config.color[1] ~= 1 or config.color[2] ~= 1 or config.color[3] ~= 1 then
        sim.writeCustomTableData(_S.animator.self, '__config__', config)
        _S.animator.updateColor(config.color)
    end
end

function sysCall_init()
    _S.animator.self = sim.getObject('.')
    local c = sim.readCustomTableData(_S.animator.self, '__config__')
    if next(c) == nil then
        c.loop = false
        c.backAndForth = false
        c.dirAndSpeed = 1
        c.initPos = 0
        c.immobile = false
        c.color = {1, 1, 1}
        sim.writeCustomTableData(_S.animator.self, '__config__', c)
    end
    gen(c)
end

configUiSchema = {
    dirAndSpeed = {
        type = 'float',
        name = 'Direction and rel. speed',
        default = 1,
        minimum = -10,
        maximum = 10,
        ui = {control = 'spinbox', order = 1, col = 1},
    },
    initPos = {
        type = 'float',
        name = 'Initial, rel. position',
        default = 0,
        minimum = 0,
        maximum = 1,
        ui = {control = 'spinbox', order = 6, col = 2},
    },
    color = {
        type = 'color',
        name = 'Color',
        default = {1, 1, 1},
        ui = {order = 7, col = 2}
    },
    loop = {
        type = 'bool',
        name = 'Loop',
        default = true,
        ui = {order = 2, col = 1}
    },
    backAndForth = {
        type = 'bool',
        name = 'Back and forth',
        default = true,
        ui = {order = 3, col = 1},
    },
    immobile = {
        type = 'bool',
        name = 'Stay in place',
        default = true,
        ui = {order = 4, col = 1}
    },
}
configUi = ConfigUI('Animator', configUiSchema, gen)
